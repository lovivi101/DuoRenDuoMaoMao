import type {GameMap} from '../../types.js';
import {Grid,T,center,finish,portalPair} from './build.js';

// 夜间商场：上下两层并排画在同一张网格上（左 = 一层，右 = 二层，中间是空洞），
// 每层中央是贯穿的天井（挡路不挡视线），两部扶梯 + 一条消防楼梯是跨层咽喉。
// 试衣间用帘子（能走、挡视线），二层右上角是广播室（藏者可放一次假警报）。72×32。
export const W=72,H=32;
const F1=0,F2=37;
function floor(g:Grid,ox:number,furniture:GameMap['furniture']){
 // Shop rows along the top and bottom, walkway ring around the atrium in between.
 g.hline(ox+1,ox+33,9);g.hline(ox+1,ox+33,21);
 for(const x of [9,17,25]){g.vline(ox+x,1,8);g.vline(ox+x,22,30)}
 for(const [a,b] of [[1,8],[10,16],[18,24],[26,33]]){const mid=ox+Math.floor((a+b)/2);g.doors([mid,9],[mid+1,9],[mid,21],[mid+1,21])}
 g.fill(ox+12,11,10,9,T.atrium);
 // Kiosks on the walkway ring: sight-blocking cover so the open ring is not one long sightline.
 for(const [x,y] of [[4,16],[8,11],[28,11],[24,17]])g.fill(ox+x,y,2,2,T.shelf);
 // Display racks inside shops.
 for(const [x,y] of [[3,4],[12,4],[20,5],[4,26],[12,25],[20,26],[28,25]]){g.fill(ox+x,y,3,1,T.furniture);furniture.push({x:ox+x,y,w:3,h:1,kind:'clothes_rack'})}
}
export function createNightMall():GameMap{
 const g=new Grid(W,H);const furniture:GameMap['furniture']=[];
 g.fill(34,1,3,30,T.void);g.vline(34,1,30);g.vline(36,1,30);
 floor(g,F1,furniture);floor(g,F2,furniture);
 // Fitting rooms in the first-floor clothing store (top right): single-exit booths behind curtains.
 for(const x of [26,28,30,32])g.vline(x,1,3);
 for(const x of [27,29,31])g.set(x,3,T.curtain);
 g.crack(.3,(x,y)=>y===9||y===21||x===34||x===36);
 const props:[number,number,string][]=[];
 for(const ox of [F1,F2]){
  props.push([ox+2,2,'mannequin'],[ox+6,7,'mannequin'],[ox+14,2,'mannequin'],[ox+11,28,'mannequin'],[ox+22,24,'mannequin'],
   [ox+5,12,'shopping_cart'],[ox+28,18,'shopping_cart'],[ox+3,19,'vending_machine'],[ox+31,11,'vending_machine'],
   [ox+10,10,'potted_plant'],[ox+23,20,'potted_plant'],[ox+16,20,'promo_stand'],[ox+24,10,'promo_stand'],[ox+30,28,'cardboard_box'],[ox+2,29,'trash_can'])
 }
 const portals=[...portalPair('escalator_w','escalator',[7,15],[F2+7,15],1,3),...portalPair('escalator_e','escalator',[27,15],[F2+27,15],1,3),...portalPair('stairs','stairs',[2,10],[F2+32,30],1.5,2)];
 return finish({id:'night_mall',theme:'mall',grid:g,
  zones:[{name:'一层',x:1,y:1,w:33,h:30,floor:'mall'},{name:'二层',x:F2,y:1,w:34,h:30,floor:'carpet'}],
  hunterSpawn:center(9,15),cage:center(9,17),
  hiderSpawns:[center(4,5),center(21,3),center(6,25),center(29,27),center(F2+4,5),center(F2+13,6),center(F2+21,27),center(F2+31,23),center(F2+24,15),center(24,15),center(F2+5,19)],
  generators:[center(4,27),center(F2+13,3),center(F2+29,27)],
  itemSpots:[center(14,6),center(30,6),center(21,28),center(2,14),center(F2+2,6),center(F2+30,5),center(F2+6,27),center(F2+16,24),center(F2+31,15),center(31,16),center(18,20),center(F2+10,12)],
  props,furniture,portals,
  decor:[{x:6,y:13,kind:'papers'},{x:F2+23,y:13,kind:'papers'},{x:15,y:24,kind:'puddle'},{x:F2+3,y:23,kind:'mop_bucket'}],
  mechanics:{broadcastRoom:{x:F2+26,y:1,w:8,h:8}}});
}
