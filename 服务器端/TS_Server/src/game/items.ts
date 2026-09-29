import type {GameState,GamePlayer,Pos} from '../types.js';
import {RULES} from './config.js';
import {distance,hasLineOfSight,inLight} from './vision.js';
import {blockedTile} from './maps/old_dorm.js';
import {emit,fx,living,reveal,ripple,score,stun} from './shared.js';
export const HUNTER_ITEMS=['strong_flashlight','net','bell_trap','sprint_shoes'];
export const HIDER_ITEMS=['smoke','banana','speed_shoes','wood_board'];
export const quality=(item:string)=>item==='sprint_shoes'?'rare':'common';
// MVP has no legendary items and no rare hider item: preserve rarity via a charged speed_shoes variant.
export function convertItem(item:string,hunter:boolean,random:()=>number){
 if(hunter&&HUNTER_ITEMS.includes(item)||!hunter&&HIDER_ITEMS.includes(item))return item;
 if(quality(item)==='rare')return hunter?'sprint_shoes':'speed_shoes';
 const pool=hunter?HUNTER_ITEMS.slice(0,3):HIDER_ITEMS;
 return pool[Math.floor(random()*pool.length)];
}
export function randomItem(g:GameState,initial=false){const list=initial?HUNTER_ITEMS.slice(0,3).concat(HIDER_ITEMS):HUNTER_ITEMS.concat(HIDER_ITEMS);return list[Math.floor(g.random()*list.length)]}
export function pickup(g:GameState,p:GamePlayer){
 const d=g.drops.find(d=>d.stage==='landed'&&distance(p,d)<=RULES.interactRange&&hasLineOfSight(p.x,p.y,d.x,d.y,g.map));
 const slot=p.items.indexOf(null);if(!d||slot<0)return false;
 p.items[slot]=convertItem(d.item,p.role==='hunter',g.random);d.stage='taken';ripple(g,d,'box');
 emit(g,{t:'game.drop',drops:[{id:d.id,x:d.x,y:d.y,stage:'taken'}]});return true;
}
export function useItem(g:GameState,p:GamePlayer,slot:number,aim:Pos){
 if(!Number.isInteger(slot)||slot<0||slot>1||!p.items[slot]||g.now-p.lastItemAt<300)return;
 const item=p.items[slot]!;const hunter=p.role==='hunter';if(!(hunter?HUNTER_ITEMS:HIDER_ITEMS).includes(item))return;
 const len=Math.hypot(aim.x,aim.y);const dx=len?aim.x/len:Math.cos(p.dir),dy=len?aim.y/len:Math.sin(p.dir),dir=Math.atan2(dy,dx);
 if(item==='wood_board'){
 if([...g.walls.values()].filter(w=>w.until).length>=RULES.maxTemporaryWalls*2)return;
 const cx=Math.floor(p.x+dx*1.4),cy=Math.floor(p.y+dy*1.4);
 const cells=[{x:cx,y:cy},{x:cx+(Math.abs(dx)<Math.abs(dy)?1:0),y:cy+(Math.abs(dx)>=Math.abs(dy)?1:0)}];
 const valid=cells.filter(c=>!blockedTile(c.x,c.y,g.map)&&!g.players.some(q=>living(q)&&distance(q,{x:c.x+.5,y:c.y+.5})<1)&&!g.generators.some(q=>distance(q,{x:c.x+.5,y:c.y+.5})<1));
 if(!valid.length)return;
 for(const c of valid){const k=c.y*g.map.w+c.x;g.walls.set(k,{hits:0,last:g.now,by:p.id,until:g.now+RULES.boardSec*1000,original:g.map.tiles[k]});g.map.tiles[k]=2}
 emit(g,{t:'game.wall',cells:valid.map(c=>({...c,tile:2}))});ripple(g,p,'wall');
 }else if(item==='strong_flashlight'){
 for(const t of g.players.filter(t=>t.role!=='hunter'&&living(t)))if(inLight(p.x,p.y,t.x,t.y,dir,RULES.strongLightRange,.35,g.map))reveal(g,t,RULES.strongLightSec);
 fx(g,p,'strong_flashlight',p.id);
 }else if(item==='net'){
 const targets=g.players.filter(t=>t.role!=='hunter'&&living(t)&&inLight(p.x,p.y,t.x,t.y,dir,RULES.netRange,.3,g.map)).sort((a,b)=>distance(p,a)-distance(p,b));
 if(targets[0]){targets[0].slowUntil=g.now+RULES.netSec*1000;fx(g,targets[0],'net',p.id)}
 }else if(item==='sprint_shoes'||item==='speed_shoes'){p.boostUntil=g.now+(hunter?RULES.hunterBoostSec:RULES.hiderBoostSec)*1000;fx(g,p,item,p.id)}
 else if(item==='smoke'||item==='banana'||item==='bell_trap'){
 g.hazards.push({kind:item,x:p.x,y:p.y,until:g.now+(item==='smoke'?RULES.smokeSec:60)*1000,by:p.id,hit:new Set()});fx(g,p,item,p.id);
 }
 p.items[slot]=null;p.lastItemAt=g.now;
}
export function tickItems(g:GameState){
 for(const [k,w] of g.walls)if(w.until&&g.now>=w.until){g.map.tiles[k]=w.original??0;g.walls.delete(k);emit(g,{t:'game.wall',cells:[{x:k%g.map.w,y:Math.floor(k/g.map.w),tile:g.map.tiles[k]}]})}
 for(const h of g.hazards){if(h.until<=g.now)continue;for(const p of g.players){
 if(!living(p)||h.hit.has(p.id))continue;
 if(h.kind==='smoke'&&p.role==='hunter'&&distance(p,h)<RULES.smokeRadius){h.hit.add(p.id);const by=g.players.find(q=>q.id===h.by);if(by)score(by,'道具干扰',RULES.points.item)}
 if(h.kind==='banana'&&p.role==='hunter'&&distance(p,h)<.6){h.hit.add(p.id);stun(g,p,RULES.missStun);h.until=g.now;fx(g,p,'banana_slip',h.by);const by=g.players.find(q=>q.id===h.by);if(by)score(by,'道具干扰',RULES.points.item)}
 if(h.kind==='bell_trap'&&p.role!=='hunter'&&distance(p,h)<.6){h.until=g.now;g.marks.push({x:p.x,y:p.y,targetId:p.id,kind:'report',audience:'all',until:g.now+RULES.bellSec*1000});ripple(g,p,'crash');fx(g,p,'bell_trap',h.by)}
 }}g.hazards=g.hazards.filter(h=>h.until>g.now);
}
