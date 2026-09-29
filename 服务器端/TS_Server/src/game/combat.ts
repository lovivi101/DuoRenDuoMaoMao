import type {GameState,GamePlayer} from '../types.js';
import {RULES} from './config.js';
import {distance,hasLineOfSight} from './vision.js';
import {active,emit,fx,living,ripple,score,stun} from './shared.js';
export const repairSeconds=(n:number)=>RULES.repairTimes[Math.min(3,Math.max(1,n))-1];
export function catchPlayer(g:GameState,v:GamePlayer,h?:GamePlayer){
 if(!living(v)||v.role==='hunter')return;
 const at={x:v.x,y:v.y};v.caught=true;v.caged=true;v.state='caged';v.prop=null;v.interact=null;v.ghostSide=null;
 v.chooseUntil=g.now+RULES.ghostChooseSec*1000;v.x=g.map.cage.x;v.y=g.map.cage.y;
 v.input={seq:v.input.seq,mx:0,my:0,run:false,at:g.now};
 if(h&&v.role==='hider'){h.captures++;score(h,g.phase==='final'?'最终抓捕':'抓捕',g.phase==='final'?RULES.points.finalCatch:RULES.points.catch)}
 for(const mark of g.marks.filter(m=>m.targetId===v.id&&m.by&&m.until>g.now)){
 const by=g.players.find(p=>p.id===mark.by);if(!by)continue;
 if(mark.kind==='wraith')score(by,'怨灵助攻',RULES.points.wraith);
 if(mark.kind==='report_assist'&&by.role==='mole')score(by,'卧底报点',RULES.points.report);
 }
 emit(g,{t:'game.caught',hunterId:h?.id??'',victimId:v.id,x:at.x,y:at.y});
}
export function slap(g:GameState,h:GamePlayer){
 if(!active(g)||h.role!=='hunter'||g.now<h.stunnedUntil||g.now-h.lastSlap<RULES.slapCooldown*1000)return;
 h.lastSlap=g.now;
 const candidates:{d:number;type:'player'|'prop'|'wall';p?:GamePlayer;k?:number}[]=[];
 for(const p of g.players)if(p.id!==h.id&&p.role!=='hunter'&&living(p)&&distance(h,p)<=RULES.slapRange&&hasLineOfSight(h.x,h.y,p.x,p.y,g.map))candidates.push({d:distance(h,p),type:'player',p});
 for(const p of g.map.props)if(distance(h,p)<=RULES.slapRange&&hasLineOfSight(h.x,h.y,p.x,p.y,g.map))candidates.push({d:distance(h,p),type:'prop'});
 for(let y=Math.floor(h.y-1.6);y<=Math.floor(h.y+1.6);y++)for(let x=Math.floor(h.x-1.6);x<=Math.floor(h.x+1.6);x++){
 const k=y*g.map.w+x;if(x<0||y<0||x>=g.map.w||y>=g.map.h||g.map.tiles[k]!==2)continue;
 const dx=x+.5-h.x,dy=y+.5-h.y;
 if(Math.hypot(dx,dy)<=1.8&&dx*Math.cos(h.dir)+dy*Math.sin(h.dir)>.2){
 const nx=Math.max(x,Math.min(h.x,x+1)),ny=Math.max(y,Math.min(h.y,y+1));
 if(hasLineOfSight(h.x,h.y,nx+(h.x-nx)*.01,ny+(h.y-ny)*.01,g.map))candidates.push({d:Math.hypot(nx-h.x,ny-h.y),type:'wall',k});
 }
 }
 const hit=candidates.sort((a,b)=>a.d-b.d||(a.type==='player'?-1:1))[0];
 if(hit?.type==='player'){catchPlayer(g,hit.p!,h);return {hit:true,target:hit.p}}
 if(hit?.type==='wall'){
 const k=hit.k!,prev=g.walls.get(k),combo=prev?.by===h.id&&g.now-prev.last<=RULES.wallComboSec*1000;
 const w={hits:(combo?prev!.hits:0)+1,last:g.now,by:h.id,until:prev?.until,original:prev?.original};g.walls.set(k,w);
 fx(g,{x:k%g.map.w+.5,y:Math.floor(k/g.map.w)+.5},'wall_hit',h.id);
 if(w.hits>=RULES.wallHits){g.map.tiles[k]=w.until?w.original??0:4;g.walls.delete(k);const cell={x:k%g.map.w,y:Math.floor(k/g.map.w),tile:g.map.tiles[k]};emit(g,{t:'game.wall',cells:[cell]});ripple(g,cell,'wall',true,h.id)}
 return {hit:true};
 }
 stun(g,h,RULES.missStun);ripple(g,h,'crash',true,h.id);fx(g,h,'slap_miss',h.id);return {hit:false};
}
