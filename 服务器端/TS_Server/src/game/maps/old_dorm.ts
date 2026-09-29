import type {GameMap,Pos} from '../../types.js';
import {RULES} from '../config.js';
export const W=64,H=40;
export function createOldDorm():GameMap {
 const tiles=new Uint8Array(W*H);const set=(x:number,y:number,t=1)=>{tiles[y*W+x]=t};
 for(let x=0;x<W;x++){set(x,0);set(x,H-1)}for(let y=0;y<H;y++){set(0,y);set(W-1,y)}
 // Cross shaped arterial walls: each zone has multiple doorways.
 for(const y of [13,26])for(let x=1;x<63;x++)set(x,y);
 for(const x of [25,38])for(let y=14;y<26;y++)set(x,y);
 for(const y of [13,26])for(const x of [7,8,19,20,29,30,33,34,44,45,56,57])set(x,y,3);
 for(const x of [25,38])for(const y of [16,17,22,23])set(x,y,3);
 // Northern small dorm rooms open onto the two continuous corridors.
 for(const x of [9,18,27,36,45,54])for(let y=1;y<9;y++)set(x,y);
 for(let x=1;x<63;x++)if(![5,6,14,15,23,24,32,33,41,42,50,51,59,60].includes(x))set(x,8);
 // Each dorm has two bunk-bed islands; the aisle around them remains walkable.
 for(const x of [2,11,20,29,38,47,56])for(const dx of [0,4])for(const y of [3,4])set(x+dx,y,6);
 // Southern parallel shelves with end passages and a crossing aisle form loops.
 for(const y of [30,35])for(let x=5;x<60;x++)if(x%13<10&&x%13>2)set(x,y,7);
 for(const x of [16,32,48])for(const y of [28,29,32,33,36,37])set(x,y,7);
 // Cafeteria table islands / bath partitions form local loops.
 for(const x of [43,53])for(let y=17;y<=22;y++)for(const dx of [0,1])set(x+dx,y,6);
 for(const x of [9,17])for(const y of [16,17,22,23]){set(x,y);set(x+1,y)}
 // Locked one-exit safety room within the western bath (exception to two exits).
 for(let x=2;x<=6;x++){set(x,15);set(x,20)}for(let y=15;y<=20;y++){set(2,y);set(6,y)}
 const lockedDoors=[{x:6,y:18}];set(6,18,3);
 // Exactly approximately 40% of indoor walls are cracked; exterior remains solid.
 const interior:number[]=[];
 for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++)if(tiles[y*W+x]===1)interior.push(y*W+x);
 // Distribute cracks, retaining main corridor supports and safe room shell.
 const candidates=interior.filter(k=>{const x=k%W,y=Math.floor(k/W);return !(x>=2&&x<=6&&y>=15&&y<=20)});
 const target=Math.round(interior.length*.4);
 for(let i=0;i<target;i++)tiles[candidates[Math.floor(i*candidates.length/target)]]=2;
 const center=(x:number,y:number)=>({x:x+.5,y:y+.5});
 const props:GameMap['props']=[];
 const prop=(x:number,y:number,name:string)=>props.push({...center(x,y),prop:name});
 for(const x of [2,11,20,29,38,47,56]){
 prop(x+1,3,'pillow');prop(x+5,3,'pillow');prop(x+2,5,'desk_lamp');
 prop(x+1,6,'cardboard_box');prop(x+5,6,'chair');
 }
 for(const x of [42,52])for(const y of [16,23]){prop(x,y,'food_tray');prop(x+3,y,'chair')}
 prop(60,16,'trash_can');prop(60,24,'trash_can');prop(49,20,'food_tray');
 for(const x of [7,20,37,54]){prop(x,29,'cardboard_box');prop(x+1,34,'cardboard_box');prop(x,37,'oil_drum')}
 for(const x of [8,14,21]){prop(x,19,'potted_plant');prop(x,24,'trash_can')}

 const map:GameMap={id:'old_dorm',w:W,h:H,tileSize:32,tiles,
 zones:[{name:'中央大厅',x:26,y:14,w:12,h:12,floor:'tile'},
 {name:'北区宿舍走廊',x:1,y:1,w:62,h:12,floor:'wood'},
 {name:'东区食堂',x:39,y:14,w:24,h:12,floor:'tile'},
 {name:'南区仓库',x:1,y:27,w:62,h:12,floor:'concrete'},
 {name:'西区澡堂',x:1,y:14,w:24,h:12,floor:'tile'}],
 hunterSpawn:{x:32,y:20},cage:{x:32,y:17},
 hiderSpawns:[center(5,5),center(23,5),center(41,5),center(59,5),center(48,20),center(58,24),center(7,28),center(42,37),center(12,19),center(21,24),center(29,10)],
 generators:[{id:0,...center(14,4)},{id:1,...center(57,19)},{id:2,...center(24,33)}],
 itemSpots:[center(5,5),center(23,10),center(59,5),center(42,20),center(58,24),center(50,15),center(7,28),center(42,37),center(58,32),center(12,19),center(21,24),center(15,15)],
 props,lockedDoors};
 return map;
}
export const oldDorm=createOldDorm();
export function tileAt(x:number,y:number,map:GameMap=oldDorm){const xx=Math.floor(x),yy=Math.floor(y);return xx<0||yy<0||xx>=map.w||yy>=map.h?1:map.tiles[yy*map.w+xx]}
export function sightBlockedTile(x:number,y:number,map:GameMap=oldDorm){const t=tileAt(x,y,map);return t===1||t===2||t===5||t===7||map.lockedDoors.some(p=>p.x===Math.floor(x)&&p.y===Math.floor(y))}
export function blockedTile(x:number,y:number,map:GameMap=oldDorm){return tileAt(x,y,map)===6||sightBlockedTile(x,y,map)}
export function isBlocked(x:number,y:number,r=RULES.radius,map:GameMap=oldDorm){
 for(let yy=Math.floor(y-r);yy<=Math.floor(y+r);yy++)for(let xx=Math.floor(x-r);xx<=Math.floor(x+r);xx++){
 if(blockedTile(xx,yy,map)){const nx=Math.max(xx,Math.min(x,xx+1)),ny=Math.max(yy,Math.min(y,yy+1));if((nx-x)**2+(ny-y)**2<r*r-1e-8)return true}
 }return false;
}
export function wireMap(map:GameMap){return {...map,tiles:Buffer.from(map.tiles).toString('base64'),legend:{0:'floor',1:'wall_solid',2:'wall_cracked',3:'door',4:'rubble',5:'void',6:'furniture',7:'shelf'}}}
export function zoneAt(p:Pos,map:GameMap){return map.zones.find(z=>p.x>=z.x&&p.y>=z.y&&p.x<z.x+z.w&&p.y<z.y+z.h)}
export function ascii(map=oldDorm){const chars=['.','#','%','+',';', ' ','f','s'];const rows=Array.from({length:map.h},(_,y)=>Array.from({length:map.w},(_,x)=>chars[tileAt(x,y,map)]));for(const p of map.props)rows[Math.floor(p.y)][Math.floor(p.x)]='p';for(const p of map.itemSpots)rows[Math.floor(p.y)][Math.floor(p.x)]='i';for(const p of map.generators)rows[Math.floor(p.y)][Math.floor(p.x)]='G';rows[17][32]='C';rows[20][32]='H';console.log(rows.map(r=>r.join('')).join('\n'));console.log('# solid | % cracked | + door | f furniture | s shelf | G generator | i item | p prop | C cage | H hunter');console.log(map.zones.map(z=>z.name+': '+z.x+','+z.y+' '+z.w+'x'+z.h).join('\n'))}
if(process.argv.includes('--ascii'))ascii();
