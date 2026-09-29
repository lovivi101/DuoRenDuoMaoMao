import type {GameMap} from '../../types.js';
import {Grid,T,center,finish} from './build.js';

// 雪山山庄：中间木屋（壁炉大厅 + 厨房 + 两间卧室），四周大片雪地，散落柴房、工具房、马厩和松树。
// 雪地走路也留脚印且留 15 秒；每 2 分钟暴风雪 15 秒（室外几乎看不见、抹平脚印）；
// 室外连续待 40 秒后逐渐变慢；壁炉附近的人会被照亮。5 张图里最大。76×50。
export const W=76,H=50;
export const LODGE={x:26,y:17,w:24,h:16},WOODSHED={x:4,y:3,w:12,h:8},TOOLSHED={x:60,y:3,w:12,h:8},STABLE={x:28,y:40,w:20,h:8};
export function createSnowLodge():GameMap{
 const g=new Grid(W,H);const furniture:GameMap['furniture']=[];
 for(const r of [LODGE,WOODSHED,TOOLSHED,STABLE])g.box(r.x,r.y,r.w,r.h);
 // Lodge interior: great hall (west), kitchen (north-east), two bedrooms (south-east).
 g.vline(37,18,31);g.hline(38,48,24);g.vline(43,25,31);
 g.doors([26,24],[26,25],[49,21],[33,32],[41,17],[37,20],[37,28],[40,24],[45,24],[43,28]);
 g.fill(31,18,2,1,T.furniture);furniture.push({x:31,y:18,w:2,h:1,kind:'fireplace'});
 g.fill(39,19,3,1,T.furniture);furniture.push({x:39,y:19,w:3,h:1,kind:'kitchen_counter'});
 // Outbuildings.
 g.doors([15,6],[10,10],[60,7],[65,10],[37,40],[38,40],[28,44],[47,44]);
 for(const x of [33,38,43])g.vline(x,41,43);
 g.fill(5,4,1,5,T.shelf);g.fill(70,4,1,5,T.shelf);
 // Pines on the snowfield: block movement, not sight.
 const pines=[[20,5],[23,9],[30,4],[45,6],[52,10],[8,16],[14,20],[19,28],[9,33],[16,38],[6,44],[22,46],[55,18],[60,24],[67,16],[70,30],[56,36],[63,42],[70,45],[52,46],[36,12],[24,36],[50,36],[12,26]];
 for(const [x,y] of pines){g.set(x,y,T.furniture);furniture.push({x,y,w:1,h:1,kind:'pine_tree'})}
 g.crack(.3,(x,y)=>x===0||y===0||x===W-1||y===H-1);
 const props:[number,number,string][]=[
  [18,14,'snowman'],[48,12,'snowman'],[10,30,'snowman'],[64,34,'snowman'],[22,42,'snowman'],[58,46,'snowman'],
  [7,8,'firewood'],[12,4,'firewood'],[35,19,'firewood'],[46,44,'firewood'],[28,18,'deer_head'],[44,18,'deer_head'],
  [27,26,'ski_rack'],[66,4,'ski_rack'],[62,8,'ski_rack'],[39,30,'blanket'],[47,26,'blanket'],[33,29,'blanket'],
  [30,31,'chair'],[46,20,'potted_plant'],[31,45,'cardboard_box'],[45,21,'trash_can'],
 ];
 return finish({id:'snow_lodge',theme:'lodge',grid:g,
  zones:[{name:'木屋',...LODGE,floor:'lodge'},{name:'柴房',...WOODSHED,floor:'barn'},{name:'工具房',...TOOLSHED,floor:'barn'},{name:'马厩',...STABLE,floor:'barn'},{name:'雪地',x:1,y:1,w:W-2,h:H-2,floor:'snow'}],
  hunterSpawn:center(32,26),cage:center(29,21),
  hiderSpawns:[center(40,28),center(46,29),center(42,21),center(12,6),center(63,6),center(31,43),center(45,42),center(10,25),center(65,28),center(20,44),center(55,14)],
  generators:[center(8,6),center(66,6),center(40,45)],
  itemSpots:[center(14,8),center(67,8),center(35,44),center(46,21),center(39,27),center(3,24),center(72,24),center(38,3),center(38,36),center(18,33),center(58,30),center(30,30)],
  props,furniture,
  decor:[{x:29,y:23,kind:'rug_dorm'},{x:39,y:29,kind:'slippers'},{x:45,y:30,kind:'books'},{x:34,y:30,kind:'laundry_basket'}],
  mechanics:{indoor:[LODGE,WOODSHED,TOOLSHED,STABLE],blizzard:{intervalSec:120,durationSec:15,warnSec:5},coldAfterSec:40,fireplace:center(31,19)}});
}
