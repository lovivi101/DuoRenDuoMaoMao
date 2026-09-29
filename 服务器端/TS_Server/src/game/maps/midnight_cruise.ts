import type {GameMap} from '../../types.js';
import {Grid,T,center,finish,portalPair} from './build.js';

// 午夜游轮：上半是露天甲板（月光，所有人互相看得远），下半是船舱（狭窄漆黑、房间密集），
// 4 个舱口楼梯连通；每 90 秒船身倾斜 5 秒，未伪装的人都会往一侧滑（伪装者不动，容易露馅）。70×34。
export const W=70,H=34;
export function createMidnightCruise():GameMap{
 const g=new Grid(W,H);const furniture:GameMap['furniture']=[];
 // Hull gap between deck (y1..12) and cabins (y16..32).
 g.hline(1,68,13);g.fill(1,14,68,1,T.void);g.hline(1,68,15);
 // Deck: lifeboats on the rails, a funnel housing and deck chairs.
 for(const [x,y] of [[6,1],[22,1],[40,1],[56,1],[6,11],[22,11],[40,11],[56,11]]){g.fill(x,y,5,1,T.furniture);furniture.push({x,y,w:5,h:1,kind:'lifeboat'})}
 g.box(30,4,10,5);g.doors([34,8],[35,4]);
 // Cabin deck: central passage (y24..25), cabins above and below, engine rooms at both ends.
 g.hline(8,61,23);g.hline(8,61,26);g.vline(8,16,32);g.vline(61,16,32);
 for(let x=15;x<61;x+=7){g.vline(x,16,22);g.vline(x,27,32)}
 for(const x of [9,16,23,30,37,44,51,58])g.doors([x+2,23],[x+2,26]);
 g.doors([8,20],[8,29],[61,20],[61,29],[8,24],[61,25]);
 for(const [x,y] of [[2,17],[64,17]]){g.fill(x,y,2,4,T.shelf)}
 g.crack(.35,(x,y)=>y===13||y===15||x===8||x===61);
 const props:[number,number,string][]=[
  [4,4,'deck_chair'],[12,6,'deck_chair'],[17,4,'deck_chair'],[26,7,'deck_chair'],[45,5,'deck_chair'],[50,8,'deck_chair'],[63,5,'deck_chair'],
  [3,9,'life_ring'],[28,2,'life_ring'],[47,10,'life_ring'],[66,9,'life_ring'],[14,9,'rope_coil'],[53,3,'rope_coil'],[36,6,'barrel'],
  [4,24,'barrel'],[5,30,'barrel'],[65,25,'barrel'],[11,18,'suitcase'],[25,30,'suitcase'],[39,19,'suitcase'],[53,29,'suitcase'],
  [18,21,'suitcase'],[46,28,'cardboard_box'],[32,17,'chair'],[60,31,'trash_can'],[67,31,'rope_coil'],
 ];
 const portals=[...portalPair('hatch_1','hatch',[4,12],[4,16],1,3),...portalPair('hatch_2','hatch',[20,12],[20,24],1,3),
  ...portalPair('hatch_3','hatch',[48,12],[48,25],1,3),...portalPair('hatch_4','hatch',[65,12],[65,16],1,3)];
 return finish({id:'midnight_cruise',theme:'cruise',grid:g,
  zones:[{name:'甲板',x:1,y:1,w:68,h:12,floor:'deck'},{name:'船舱',x:1,y:16,w:68,h:17,floor:'cabin'}],
  hunterSpawn:center(34,10),cage:center(36,10),
  hiderSpawns:[center(11,19),center(18,29),center(25,19),center(32,29),center(39,20),center(46,30),center(53,19),center(58,29),center(3,26),center(66,22),center(34,6)],
  generators:[center(3,31),center(66,31),center(33,6)],
  itemSpots:[center(10,3),center(60,5),center(33,7),center(12,21),center(26,28),center(41,21),center(54,28),center(3,22),center(66,27),center(20,25),center(50,24),center(36,2)],
  props,furniture,portals,
  decor:[{x:15,y:3,kind:'puddle'},{x:44,y:9,kind:'puddle'},{x:27,y:24,kind:'papers'},{x:10,y:31,kind:'laundry_basket'}],
  mechanics:{deck:{x:1,y:1,w:68,h:12},tilt:{intervalSec:90,warnSec:3,durationSec:5,speed:1.2}}});
}
