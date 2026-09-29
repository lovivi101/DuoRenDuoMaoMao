import type {GameMap} from '../../types.js';
import {createOldDorm,tileAt} from './old_dorm.js';
import {createNightHospital} from './night_hospital.js';
import {createNightMall} from './night_mall.js';
import {createMidnightCruise} from './midnight_cruise.js';
import {createSnowLodge} from './snow_lodge.js';

// Every playable map. Order is the order shown in room creation and votes.
export const MAPS:Record<string,{name:string;create:()=>GameMap}>={
 old_dorm:{name:'旧宿舍楼',create:createOldDorm},
 night_hospital:{name:'深夜医院',create:createNightHospital},
 night_mall:{name:'夜间商场',create:createNightMall},
 midnight_cruise:{name:'午夜游轮',create:createMidnightCruise},
 snow_lodge:{name:'雪山山庄',create:createSnowLodge},
};
export const MAP_IDS=Object.keys(MAPS);
export function createMap(id:string):GameMap{return (MAPS[id]??MAPS.old_dorm).create()}

// Debug view: `node dist/game/maps/index.js --ascii <mapId>`.
export function ascii(map:GameMap){
 const chars=['.','#','%','+',';',' ','f','s','c','a'];
 const rows=Array.from({length:map.h},(_,y)=>Array.from({length:map.w},(_,x)=>chars[tileAt(x,y,map)]??'?'));
 const mark=(p:{x:number;y:number},c:string)=>{rows[Math.floor(p.y)][Math.floor(p.x)]=c};
 map.props.forEach(p=>mark(p,'p'));map.itemSpots.forEach(p=>mark(p,'i'));map.hiderSpawns.forEach(p=>mark(p,'h'));
 map.generators.forEach(p=>mark(p,'G'));(map.portals??[]).forEach(p=>mark(p,'E'));mark(map.cage,'C');mark(map.hunterSpawn,'H');
 return rows.map(r=>r.join('')).join('\n')+'\n# 墙 | % 裂墙 | + 门 | f 家具 | s 货架 | c 帘子 | a 天井 | 空格 虚空 | G 发电机 | i 道具点 | p 伪装物 | h 藏者出生 | E 传送点 | C 笼子 | H 猎手出生\n'+
  map.zones.map(z=>`${z.name}: ${z.x},${z.y} ${z.w}x${z.h} ${z.floor}`).join('\n');
}
const at=process.argv.indexOf('--ascii');
if(at>=0)console.log(ascii(createMap(process.argv[at+1]??'old_dorm')));
