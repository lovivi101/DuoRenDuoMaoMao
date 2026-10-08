import type {Look,MatchRecord,User} from './types.js';

// Cosmetics only (design §10.6): hats, footprint styles and disguise effects never change
// size, speed or how visible a player is in the dark.
export type Slot=keyof Look;
export interface Item {id:string;slot:Slot;name:string;price:number;currency:'coins'|'gems';rare?:boolean}
export const CATALOG:Item[]=[
 {id:'nightcap',slot:'hat',name:'蓝色睡帽',price:0,currency:'coins'},
 {id:'cat',slot:'hat',name:'猫耳帽',price:800,currency:'coins'},
 {id:'bear',slot:'hat',name:'小熊帽',price:800,currency:'coins'},
 {id:'dino',slot:'hat',name:'恐龙帽',price:1200,currency:'coins'},
 {id:'bunny',slot:'hat',name:'兔耳帽',price:1200,currency:'coins'},
 {id:'fox',slot:'hat',name:'狐狸帽',price:1500,currency:'coins'},
 {id:'pumpkin',slot:'hat',name:'南瓜帽',price:60,currency:'gems'},
 {id:'crown',slot:'hat',name:'小皇冠',price:200,currency:'gems',rare:true},
 {id:'plain',slot:'footprint',name:'普通脚印',price:0,currency:'coins'},
 {id:'paw',slot:'footprint',name:'猫爪脚印',price:600,currency:'coins'},
 {id:'star',slot:'footprint',name:'星星脚印',price:900,currency:'coins'},
 {id:'heart',slot:'footprint',name:'爱心脚印',price:900,currency:'coins'},
 {id:'snow',slot:'footprint',name:'雪花脚印',price:40,currency:'gems'},
 {id:'poof',slot:'effect',name:'烟雾变身',price:0,currency:'coins'},
 {id:'sparkle',slot:'effect',name:'星光变身',price:1000,currency:'coins'},
 {id:'leaf',slot:'effect',name:'落叶变身',price:1000,currency:'coins'},
 {id:'heart',slot:'effect',name:'爱心变身',price:50,currency:'gems'},
];
export const DEFAULT_LOOK:Look={hat:'nightcap',footprint:'plain',effect:'poof'};
const key=(slot:Slot,id:string)=>slot+':'+id;
export const owned=(u:User)=>new Set([...(u.owned??[]),...CATALOG.filter(i=>i.price===0).map(i=>key(i.slot,i.id))]);
export const lookOf=(u:User):Look=>({...DEFAULT_LOOK,...u.equipped});

export class EconomyError extends Error {constructor(public code:string){super(code)}}
export function buy(u:User,slot:Slot,id:string){
 const item=CATALOG.find(i=>i.slot===slot&&i.id===id);if(!item)throw new EconomyError('NOT_FOUND');
 if(owned(u).has(key(slot,id)))throw new EconomyError('ALREADY_OWNED');
 if(u[item.currency]<item.price)throw new EconomyError(item.currency==='coins'?'NOT_ENOUGH_COINS':'NOT_ENOUGH_GEMS');
 u[item.currency]-=item.price;u.owned=[...(u.owned??[]),key(slot,id)];
}
export function equip(u:User,slot:Slot,id:string){
 if(!CATALOG.some(i=>i.slot===slot&&i.id===id))throw new EconomyError('NOT_FOUND');
 if(!owned(u).has(key(slot,id)))throw new EconomyError('NOT_OWNED');
 u.equipped={...lookOf(u),[slot]:id};
}

// Daily tasks reset at local midnight (Asia/Shanghai); progress comes from finished matches.
export interface Task {id:string;name:string;goal:number;reward:{coins?:number;gems?:number;exp?:number};count:(r:MatchRecord)=>number}
export const TASKS:Task[]=[
 {id:'play',name:'完成 3 局对局',goal:3,reward:{coins:100},count:()=>1},
 {id:'win',name:'赢下 1 局',goal:1,reward:{coins:80,exp:30},count:r=>r.win?1:0},
 {id:'repair',name:'修好 2 台发电机',goal:2,reward:{coins:60},count:r=>r.repairs},
 {id:'rescue',name:'救出 1 名队友',goal:1,reward:{coins:60},count:r=>r.rescues},
 {id:'catch',name:'作为猎手抓到 3 人',goal:3,reward:{coins:80},count:r=>r.role==='hunter'?r.captures:0},
 {id:'survive',name:'作为藏者存活到结束',goal:1,reward:{gems:5},count:r=>r.survived?1:0},
];
export const today=(now:number)=>new Date(now+8*3600000).toISOString().slice(0,10);
function daily(u:User,now:number){const day=today(now);if(u.tasks?.day!==day)u.tasks={day,progress:{},claimed:[]};return u.tasks!}
export function tasksView(u:User,now:number){
 const t=daily(u,now);
 return TASKS.map(task=>({id:task.id,name:task.name,goal:task.goal,reward:task.reward,progress:Math.min(task.goal,t.progress[task.id]??0),claimed:t.claimed.includes(task.id)}));
}
export function claim(u:User,id:string,now:number){
 const t=daily(u,now),task=TASKS.find(x=>x.id===id);if(!task)throw new EconomyError('NOT_FOUND');
 if(t.claimed.includes(id))throw new EconomyError('ALREADY_CLAIMED');
 if((t.progress[id]??0)<task.goal)throw new EconomyError('TASK_NOT_DONE');
 t.claimed.push(id);u.coins+=task.reward.coins??0;u.gems+=task.reward.gems??0;u.exp+=task.reward.exp??0;u.level=1+Math.floor(u.exp/500);
}
// Called once per finished match (inside the reward transaction): tasks and lifetime stats.
export function applyMatch(u:User,r:MatchRecord,now:number){
 const t=daily(u,now);for(const task of TASKS)t.progress[task.id]=(t.progress[task.id]??0)+task.count(r);
 const s=u.stats??={games:0,wins:0,captures:0,rescues:0,repairs:0,mvp:0};
 s.games++;s.wins+=+r.win;s.captures+=r.captures;s.rescues+=r.rescues;s.repairs+=r.repairs;s.mvp+=+r.mvp;
}
export const economyMessages:Record<string,string>={ALREADY_OWNED:'已经拥有',NOT_ENOUGH_COINS:'金币不足',NOT_ENOUGH_GEMS:'钻石不足',NOT_OWNED:'尚未拥有',ALREADY_CLAIMED:'奖励已领取',TASK_NOT_DONE:'任务尚未完成'};
