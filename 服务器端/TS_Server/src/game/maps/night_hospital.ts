import type {GameMap} from '../../types.js';
import {Grid,T,center,finish,portalPair} from './build.js';

// 深夜医院：两翼对称的长走廊 + 大量小病房，中间护士站连通两翼；走廊两端的电梯
// 3 秒直达另一翼。长直走廊让手电照得远（设计偏猎手）。72×34。
export const W=72,H=34;
const WEST=[[1,7],[9,15],[17,22],[24,30]],EAST=[[41,47],[49,55],[57,62],[64,70]];
export function createNightHospital():GameMap{
 const g=new Grid(W,H);
 // Wing walls and the central nurse-station column.
 for(const x of [31,40])g.vline(x,1,H-2);
 g.hline(1,70,3);g.hline(1,70,14);g.hline(1,70,19);g.hline(1,70,30);
 // Wards: dividers in each wing; every ward opens to the long corridor and to a back corridor.
 for(const [a,b] of [...WEST,...EAST]){
  if(a>1&&a!==41){g.vline(a-1,4,13);g.vline(a-1,20,29)}
  const mid=Math.floor((a+b)/2);g.doors([mid,3],[mid+1,14],[mid,19],[mid+1,30]);
 }
 // Corridor passes through the station; station and X-ray room open onto it.
 for(const x of [31,40])g.doors([x,16],[x,17],[x,1],[x,2],[x,31],[x,32]);
 g.doors([35,14],[36,14],[35,19]);
 g.set(36,3,T.door);
 // Hospital beds along each ward's left wall (two per ward, upper and lower bands).
 const furniture:GameMap['furniture']=[];
 for(const [a] of [...WEST,...EAST])for(const y of [5,9,21,25]){g.fill(a+1,y,1,2,T.furniture);furniture.push({x:a+1,y,w:1,h:2,kind:'hospital_bed'})}
 // Medicine shelves in the nurse station.
 g.fill(32,5,1,6,T.shelf);g.fill(39,5,1,6,T.shelf);
 g.crack(.35,(x,y)=>x===31||x===40||y===14||y===19||(x>31&&x<40&&y>19&&y<31));
 const props:[number,number,string][]=[];
 for(const [a,b] of [...WEST,...EAST]){props.push([b-1,6,'iv_stand'],[b-1,23,'wheelchair'],[a+3,11,'folding_screen'],[a+3,27,'gurney'])}
 props.push([34,6,'medicine_cabinet'],[37,6,'medicine_cabinet'],[35,11,'chair'],[33,21,'folding_screen'],[38,28,'trash_can'],
  [5,16,'potted_plant'],[66,17,'potted_plant'],[20,15,'wheelchair'],[52,18,'gurney'],[28,1,'cardboard_box'],[44,32,'cardboard_box']);
 const portals=portalPair('elevator','elevator',[2,17],[69,17],3,2);
 return finish({id:'night_hospital',theme:'hospital',grid:g,
  zones:[{name:'长走廊',x:1,y:15,w:70,h:4,floor:'corridor'},{name:'护士站',x:32,y:1,w:8,h:14,floor:'clinic'},{name:'X光室',x:32,y:20,w:8,h:13,floor:'clinic'},
   {name:'西翼病房',x:1,y:1,w:30,h:32,floor:'ward'},{name:'东翼病房',x:41,y:1,w:30,h:32,floor:'ward'}],
  hunterSpawn:center(36,17),cage:center(35,15),
  hiderSpawns:[center(4,8),center(12,24),center(20,8),center(27,25),center(44,8),center(52,24),center(60,8),center(67,25),center(12,1),center(59,32),center(26,16)],
  generators:[center(12,8),center(59,24),center(26,25)],
  itemSpots:[center(4,24),center(19,10),center(28,8),center(44,26),center(52,10),center(67,8),center(36,26),center(10,32),center(62,1),center(15,17),center(56,16),center(34,9)],
  props,furniture,portals,
  decor:[{x:34,y:8,kind:'papers'},{x:10,y:16,kind:'puddle'},{x:48,y:17,kind:'papers'},{x:22,y:32,kind:'mop_bucket'}],
  mechanics:{monitors:[...WEST,...EAST].flatMap(([a])=>[center(a+2,6),center(a+2,22)]),xray:{x:32,y:20,w:8,h:10}}});
}
