#!/usr/bin/env python3
"""Reproducible OSM town footprints, streets, hospitality and transit stops.

Source geometries retain OSM identifiers and the existing map's exact projection.
ODbL 1.0. Geometry is open map data; no operator's map artwork is copied.
"""
import argparse, gzip, hashlib, json, math, time, urllib.parse, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--region',required=True);p.add_argument('--offline',action='store_true');args=p.parse_args()
 geo=json.loads((ROOT/f'assets/geodata/{args.region}.json').read_text());box=','.join(map(str,geo['bbox']))
 query=f'''[out:json][timeout:90];(way["highway"]({box});way["building"]["building"!="no"]({box});nwr["tourism"~"^(hotel|guest_house|chalet|apartment|hostel)$"]({box});nwr["amenity"~"^(restaurant|cafe|pub|bar|fast_food|bus_station)$"]({box});node["highway"="bus_stop"]({box});node["public_transport"="platform"]({box});nwr["railway"="station"]({box});nwr["name"~"Skischule|Scuola.*[Ss]ci",i]({box}););out body geom;'''
 cache=ROOT/f'build/context-source/{args.region}.json';cache.parent.mkdir(parents=True,exist_ok=True)
 if not cache.exists():
  if args.offline:raise FileNotFoundError(cache)
  print('Downloading open town data:',args.region,flush=True)
  req=urllib.request.Request('https://overpass-api.de/api/interpreter?'+urllib.parse.urlencode({'data':query}),headers={'User-Agent':'SkiZones/0.19 offline town import; https://github.com/chekento/SkiZones'})
  with urllib.request.urlopen(req,timeout=110) as response:data=response.read()
  raw=json.loads(data)
  if raw.get('remark'):raise RuntimeError(raw['remark'])
  cache.write_bytes(data)
 raw=json.loads(cache.read_bytes());lat0,lon0=geo['origin'];sx=111320*math.cos(math.radians(lat0));sy=111320
 def project(lat,lon):return [round((lon-lon0)*sx+185,2),round(-(lat-lat0)*sy+230,2)]
 roads=[];buildings=[];pois=[];stops=[]
 for el in raw['elements']:
  t=el.get('tags',{});kind=el['type'];shape=[project(p['lat'],p['lon']) for p in el.get('geometry',[]) if p]
  if not shape and 'lat' in el:shape=[project(el['lat'],el['lon'])]
  if not shape:continue
  center=shape[:-1] if len(shape)>2 and shape[0]==shape[-1] else shape
  point=[round(sum(p[i] for p in center)/len(center),2) for i in [0,1]]
  base={'osm_id':el['id'],'osm_type':kind,'name':t.get('name',t.get('name:de',t.get('name:it',''))),'point':point}
  if kind=='way' and 'highway' in t and len(shape)>1:
   roads.append({'osm_id':el['id'],'name':base['name'],'kind':t['highway'],'points':shape,'nodes':el.get('nodes',[]),'access':t.get('access',''),'oneway':t.get('oneway','no'),'bridge':t.get('bridge','no'),'tunnel':t.get('tunnel','no')})
  if kind=='way' and t.get('building') not in [None,'no'] and len(shape)>3 and shape[0]==shape[-1]:
   try:height=float(t.get('height','').replace(' m',''))
   except ValueError:
    try:height=float(t.get('building:levels','2'))*3+2
    except ValueError:height=8
   buildings.append(dict(base,outline=shape,height=round(min(70,max(3,height)),1),kind=t['building'],roof=t.get('roof:shape','gabled'),levels=t.get('building:levels',''),amenity=t.get('amenity',''),tourism=t.get('tourism','')))
  school='skischule' in base['name'].lower() or 'scuola' in base['name'].lower() and 'sci' in base['name'].lower()
  if school or t.get('tourism') in ['hotel','guest_house','chalet','apartment','hostel'] or t.get('amenity') in ['restaurant','cafe','pub','bar','fast_food']:
   subtype='school' if school else t.get('amenity',t.get('tourism'))
   pois.append(dict(base,category='school' if school else 'hotel' if 'tourism' in t else 'food',subtype=subtype,outline=shape if len(shape)>2 and shape[0]==shape[-1] else [],address=' '.join(t.get(k,'') for k in ['addr:street','addr:housenumber']).strip(),website=t.get('website',''),cuisine=t.get('cuisine','')))
  if t.get('highway')=='bus_stop' or t.get('public_transport')=='platform' or t.get('amenity')=='bus_station' or t.get('railway')=='station':
   stops.append(dict(base,kind='rail' if t.get('railway')=='station' else 'bus',ref=t.get('ref','')))
 result={'schema':1,'id':args.region,'projection_origin':geo['origin'],'bounds':geo['bounds'],'source':'OpenStreetMap','license':'ODbL-1.0','copyright':'© OpenStreetMap contributors','osm_timestamp':raw.get('osm3s',{}).get('timestamp_osm_base'),'query':query,'source_sha256':hashlib.sha256(cache.read_bytes()).hexdigest(),'roads':roads,'buildings':buildings,'pois':pois,'stops':stops}
 dest=ROOT/f'assets/places/{args.region}.bin';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(gzip.compress(json.dumps(result,ensure_ascii=False,separators=(',',':')).encode(),compresslevel=9,mtime=0))
 meta={k:result[k] for k in ['schema','id','source','license','copyright','osm_timestamp','source_sha256','projection_origin']}
 meta.update(compression='gzip',sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),counts={k:len(result[k]) for k in ['roads','buildings','pois','stops']})
 dest.with_suffix('.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
 print(args.region, 'streets',len(roads),'footprints',len(buildings),'hospitality',len(pois),'stops',len(stops),'bytes',dest.stat().st_size,flush=True)
 if len(roads)<10 or len(buildings)<20 or len(pois)<3:raise RuntimeError('Incomplete town import')

if __name__=='__main__':main()
