extends RefCounted
## Deterministic original poster motifs. Device-local calendar, no save edits,
## no network and no dependency on optional imported artwork.
const Calendar=preload("res://src/core/annual_festival.gd")
const DESIGNS={
    "christmas":[
        ["FROHE","WEIHNACHTEN"],
        ["WINTER","WUNDER"],
        ["ALPEN","ADVENT"],
        ["FEST","AM BERG"]
    ],
    "new_year":[
        ["FROHES","NEUES JAHR"],
        ["SILVESTER","AM BERG"],
        ["COUNTDOWN","AM GIPFEL"],
        ["NEUES JAHR","NEUE PISTEN"]
    ]
}

static func info(date: Dictionary, index: int=0) -> Dictionary:
    var campaign: String=Calendar.poster_campaign(date)
    if campaign=="":return {}
    var year: int=Calendar.festive_year(date)
    var variant: int=posmod(year*11+int(date.month)*7+int(date.day)+index,DESIGNS[campaign].size())
    var title: Array=DESIGNS[campaign][variant]
    var visible_year: int=int(date.year)+(1 if campaign=="new_year" and int(date.month)==12 else 0)
    return {"campaign":campaign,"variant":variant,"title":title[0],"subtitle":title[1],"year":visible_year,
        "dates":"1. NOVEMBER – 26. DEZEMBER" if campaign=="christmas" else "27. DEZEMBER – 1. JANUAR"}

## Lightweight actual graphics for 3D boards; text is a separate accessible
## Label3D. One generated image per design/scene, no network or saved texture.
static func texture(campaign: String, variant: int, grayscale: bool=false) -> Texture2D:
    var image:=Image.create(256,384,false,Image.FORMAT_RGBA8)
    var top:=Color("142b43") if campaign=="christmas" else Color("0b1236")
    var bottom:=Color("26687a") if campaign=="christmas" else Color("43316f")
    var light:=Color("e5f8ee") if campaign=="christmas" else Color("ffe6ae")
    var alpine:=Color("c1e0dc") if campaign=="christmas" else Color("625999")
    if grayscale:
        top=Color("222222");bottom=Color("666666")
        light=Color("eeeeee");alpine=Color("b6b6b6")
    for y in range(384):
        image.fill_rect(Rect2i(0,y,256,1),top.lerp(bottom,float(y)/383.0))
    for x in range(256):
        var ridge: int=clampi(roundi(284.0-44.0*sin(float(x)*0.028+float(variant))-25.0*sin(float(x)*0.063+1.7)),194,330)
        image.fill_rect(Rect2i(x,ridge,1,384-ridge),alpine if x%13<7 else light.darkened(0.18))
    for k in range(65):
        var x: int=8+posmod(k*79+variant*41,238)
        var y: int=12+posmod(k*53+variant*67,245)
        var radius: int=1+(k%3)
        image.fill_rect(Rect2i(x,y,radius,radius),light)
    if campaign=="new_year":
        for burst in range(3):
            var cx: int=55+burst*74
            var cy: int=69+(burst%2)*56
            for ray in range(20):
                var theta: float=float(ray)*TAU/20.0
                for d in range(11,42,2):
                    var px: int=cx+roundi(cos(theta)*float(d))
                    var py: int=cy+roundi(sin(theta)*float(d))
                    if px>=0 and px<256 and py>=0 and py<384:image.set_pixel(px,py,light)
    else:
        for star in range(4):
            var cx: int=48+star*51
            var cy: int=77+(star%2)*52
            image.fill_rect(Rect2i(cx-2,cy-11,4,22),light)
            image.fill_rect(Rect2i(cx-11,cy-2,22,4),light)
    return ImageTexture.create_from_image(image)
