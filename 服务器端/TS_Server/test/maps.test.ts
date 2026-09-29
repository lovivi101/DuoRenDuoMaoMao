import {describe,it,expect} from 'vitest';
import {MAPS,MAP_IDS,createMap} from '../src/game/maps/index.js';
import {blockedTile,tileAt,wireMap,zoneAt} from '../src/game/maps/old_dorm.js';
import type {GameMap,Pos} from '../src/types.js';

// Flood fill over walkable cells (locked doors count as passable: they open on interact),
// following transit portals as extra edges.
function reachable(m:GameMap,from:Pos){
 const seen=new Set<number>(),todo=[Math.floor(from.y)*m.w+Math.floor(from.x)];
 const walk=(x:number,y:number)=>!blockedTile(x,y,{...m,lockedDoors:[]});
 while(todo.length){
  const k=todo.pop()!;if(seen.has(k))continue;seen.add(k);const x=k%m.w,y=Math.floor(k/m.w);
  const next:[number,number][]=[[x+1,y],[x-1,y],[x,y+1],[x,y-1]];
  for(const p of m.portals??[])if(p.x===x&&p.y===y)next.push([p.to.x,p.to.y]);
  for(const [nx,ny] of next)if(walk(nx,ny)&&!seen.has(ny*m.w+nx))todo.push(ny*m.w+nx);
 }
 return seen;
}
describe.each(MAP_IDS)('map %s',id=>{
 const m=createMap(id);
 it('has the gameplay anchors on walkable floor',()=>{
  const points:[string,Pos][]=[['hunter',m.hunterSpawn],['cage',m.cage],...m.hiderSpawns.map(p=>['spawn',p] as [string,Pos]),...m.generators.map(p=>['generator',p] as [string,Pos]),
   ...m.itemSpots.map(p=>['item',p] as [string,Pos]),...m.props.map(p=>['prop '+p.prop,p] as [string,Pos]),...(m.portals??[]).map(p=>['portal',{x:p.x+.5,y:p.y+.5}] as [string,Pos])];
  for(const [what,p] of points)expect(blockedTile(p.x,p.y,m),`${what} @ ${p.x},${p.y}`).toBe(false);
  expect(m.generators).toHaveLength(3);expect(m.hiderSpawns.length).toBeGreaterThanOrEqual(11);expect(m.props.length).toBeGreaterThanOrEqual(15);
 });
 it('is fully connected from the hunter spawn (through portals)',()=>{
  const seen=reachable(m,m.hunterSpawn);
  const walkable:number[]=[];for(let y=0;y<m.h;y++)for(let x=0;x<m.w;x++)if(!blockedTile(x,y,{...m,lockedDoors:[]}))walkable.push(y*m.w+x);
  const missing=walkable.filter(k=>!seen.has(k)).map(k=>`${k%m.w},${Math.floor(k/m.w)}`);
  expect(missing,missing.slice(0,10).join(' ')).toHaveLength(0);
 });
 it('furniture art covers exactly the furniture tiles; decor and zones fit',()=>{
  for(const f of m.furniture)for(let y=f.y;y<f.y+f.h;y++)for(let x=f.x;x<f.x+f.w;x++)expect(tileAt(x,y,m),`${f.kind}@${x},${y}`).toBe(6);
  expect(m.furniture.reduce((n,f)=>n+f.w*f.h,0)).toBe(Array.from(m.tiles).filter(v=>v===6).length);
  const size:Record<string,[number,number]>={rug_dorm:[3,2],puddle:[2,1],bath_mat:[2,1]};
  for(const d of m.decor){const [w,h]=size[d.kind]??[1,1];for(let y=d.y;y<d.y+h;y++)for(let x=d.x;x<d.x+w;x++)expect(tileAt(x,y,m),`${d.kind}@${x},${y}`).toBe(0)}
  for(let y=1;y<m.h-1;y++)for(let x=1;x<m.w-1;x++)if(!blockedTile(x,y,m)&&tileAt(x,y,m)!==3)expect(zoneAt({x:x+.5,y:y+.5},m),`zone @ ${x},${y}`).toBeTruthy();
  expect(wireMap(m).theme).toBe(m.theme);expect(MAPS[id].name.length).toBeGreaterThan(0);
 });
});
