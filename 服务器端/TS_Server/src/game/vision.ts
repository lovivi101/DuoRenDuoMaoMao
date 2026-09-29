import type {GameMap,GamePlayer,GameState,Pos} from '../types.js';
import {sightBlockedTile,isBlocked,oldDorm} from './maps/old_dorm.js';
import {RULES} from './config.js';
export const distance=(a:Pos,b:Pos)=>Math.hypot(a.x-b.x,a.y-b.y);
// Supercover grid DDA, including both cells when crossing an exact grid corner.
export function hasLineOfSight(ax:number,ay:number,bx:number,by:number,map=oldDorm){
 let x=Math.floor(ax),y=Math.floor(ay);const ex=Math.floor(bx),ey=Math.floor(by);
 const dx=bx-ax,dy=by-ay,sx=Math.sign(dx),sy=Math.sign(dy),tx=dx===0?Infinity:Math.abs(1/dx),ty=dy===0?Infinity:Math.abs(1/dy);
 let mx=dx===0?Infinity:((sx>0?x+1-ax:ax-x)*tx),my=dy===0?Infinity:((sy>0?y+1-ay:ay-y)*ty);
 for(let i=0;i<map.w+map.h+8;i++){
 if(sightBlockedTile(x,y,map))return false;if(x===ex&&y===ey)return true;
 if(Math.abs(mx-my)<1e-10){if(sightBlockedTile(x+sx,y,map)||sightBlockedTile(x,y+sy,map))return false;x+=sx;y+=sy;mx+=tx;my+=ty}
 else if(mx<my){x+=sx;mx+=tx}else{y+=sy;my+=ty}
 }return false;
}
export function inLight(ax:number,ay:number,bx:number,by:number,dir:number,radius=6,angle=Math.PI/3,map=oldDorm){
 const d=Math.hypot(bx-ax,by-ay),a=Math.atan2(by-ay,bx-ax)-dir;
 return d<=radius&&Math.abs(Math.atan2(Math.sin(a),Math.cos(a)))<=angle/2&&hasLineOfSight(ax,ay,bx,by,map);
}
export function visionRadius(g:GameState,p:GamePlayer){
 if(g.phase==='assign'||(g.phase==='hide'&&p.role==='hunter'))return 0;
 if(p.role==='hunter'&&g.hazards.some(h=>h.kind==='smoke'&&h.until>g.now&&distance(h,p)<=RULES.smokeRadius))return 0;
 if(g.event?.stage==='start'&&g.event.kind==='blackout')return 1;
 return p.role==='hunter'?Math.max(RULES.hunterMinVision,RULES.hunterVision*(1-.05*p.captures)):RULES.hiderVision;
}
export function visible(g:GameState,observer:GamePlayer,target:Pos&{state?:string;role?:string}){
 if(observer===target)return true;
 if(target.state==='ghost'&&observer.role==='hunter')return false;
 if(g.phase==='assign'||g.phase==='hide'&&observer.role==='hunter')return false;
 const r=visionRadius(g,observer);if(r===0)return false;
 // Emergency lighting is an explicit global-reveal event in the design.
 if(g.event?.stage==='start'&&g.event.kind==='emergency_light')return true;
 if(!hasLineOfSight(observer.x,observer.y,target.x,target.y,g.map))return false;
 return distance(observer,target)<=r||(observer.role==='hunter'&&observer.flashlight&&inLight(observer.x,observer.y,target.x,target.y,observer.dir,RULES.flashlightRange,RULES.flashlightAngle,g.map));
}
export function validMove(x:number,y:number,map:GameMap=oldDorm){return !isBlocked(x,y,RULES.radius,map)}
