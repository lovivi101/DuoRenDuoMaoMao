import {randomInt,randomUUID} from 'node:crypto';
import type {Room,Settings,Player} from '../types.js';
import {CONFIG} from '../game/config.js';
import {createGame} from '../game/engine.js';
import {MAP_IDS} from '../game/maps/index.js';
export const defaultSettings:Settings={map:'old_dorm',durationSec:600,hunterCount:'auto',moleEnabled:false,voiceEnabled:false,aiFill:true,maxPlayers:12};
export function validateSettings(value:unknown,base=defaultSettings):Settings{
 if(value!==undefined&&(typeof value!=='object'||value===null||Array.isArray(value)))throw Error('BAD_SETTINGS');
 const s={...base,...(value as Partial<Settings>??{})};
 if(![...MAP_IDS,'random'].includes(s.map)||![300,480,600].includes(s.durationSec)||!['auto',1,2].includes(s.hunterCount)||!Number.isInteger(s.maxPlayers)||s.maxPlayers<8||s.maxPlayers>12||![s.moleEnabled,s.voiceEnabled,s.aiFill].every(x=>typeof x==='boolean'))throw Error('BAD_SETTINGS');
 return {map:s.map,durationSec:s.durationSec,hunterCount:s.hunterCount,moleEnabled:s.moleEnabled,voiceEnabled:s.voiceEnabled,aiFill:s.aiFill,maxPlayers:s.maxPlayers};
}
export class Lobby {
 rooms=new Map<string,Room>();membership=new Map<string,string>();queue:{player:Player;at:number}[]=[];
 constructor(public minPlayers=CONFIG.matchMinPlayers,public clock=Date.now){}
 roomOf(id:string){const c=this.membership.get(id);return c?this.rooms.get(c):undefined}
 code(){let code:string;do{code=String(randomInt(100000,1000000))}while(this.rooms.has(code));return code}
 create(host:Player,settings?:unknown){
 if(this.roomOf(host.id))throw Error('ALREADY_IN_ROOM');
 const s=validateSettings(settings);this.matchCancel(host.id);
 const r:Room={code:this.code(),hostId:host.id,settings:s,phase:'waiting',players:[{...host,isHost:true}],createdAt:this.clock(),lastHunters:[],votes:new Map(),voteEndsAt:0};
 this.rooms.set(r.code,r);this.membership.set(host.id,r.code);return r;
 }
 join(code:string,p:Player){
 const r=this.rooms.get(code);if(!r)throw Error('NOT_FOUND');if(this.roomOf(p.id)===r)return r;
 if(this.roomOf(p.id))throw Error('ALREADY_IN_ROOM');if(r.phase!=='waiting')throw Error('ROOM_BUSY');
 if(r.players.length>=r.settings.maxPlayers)throw Error('ROOM_FULL');
 this.matchCancel(p.id);r.players.push({...p,isHost:false,ready:false});this.membership.set(p.id,code);return r;
 }
 leave(code:string,id:string){
 const r=this.rooms.get(code);if(!r)return;
 r.players=r.players.filter(p=>p.id!==id);this.membership.delete(id);r.votes.delete(id);
 if(r.hostId===id){const next=r.players.find(p=>!p.isBot&&p.online)||r.players.find(p=>!p.isBot)||r.players[0];if(next)r.hostId=next.id}
 for(const p of r.players)p.isHost=p.id===r.hostId;
 if(!r.players.some(p=>!p.isBot)){for(const p of r.players)this.membership.delete(p.id);this.rooms.delete(code)}
 }
 addBot(r:Room){
 if(r.phase!=='waiting')throw Error('ROOM_BUSY');if(r.players.length>=r.settings.maxPlayers)throw Error('ROOM_FULL');
 const bot:Player={id:'bot_'+randomUUID(),nickname:'AI-'+(r.players.filter(p=>p.isBot).length+1),color:'green',ready:true,isBot:true,isHost:false,online:true};
 r.players.push(bot);this.membership.set(bot.id,r.code);return bot;
 }
 beginVote(r:Room,quick=false){
 if(r.phase!=='waiting')throw Error('ROOM_BUSY');
 if(!quick&&r.players.some(p=>!p.isBot&&p.id!==r.hostId&&(!p.ready||!p.online)))throw Error('NOT_READY');
 // A lowered development queue threshold only makes the room start easier to
 // trigger. The playable match still targets the normal eight seats whenever
 // AI fill is enabled, which keeps role distribution and the solo test flow
 // meaningful (one human plus seven server bots).
 const target=Math.max(8,this.minPlayers);
 while(r.players.length<target&&r.settings.aiFill)this.addBot(r);
 if(r.players.length<this.minPlayers)throw Error('NOT_ENOUGH');
 // Three candidates: the host's pick first (unless random), the rest drawn from the other maps.
 const others=MAP_IDS.filter(id=>id!==r.settings.map).sort(()=>Math.random()-.5);
 r.voteMaps=[...(r.settings.map==='random'?[]:[r.settings.map]),...others].slice(0,3);
 r.phase='voting';r.votes.clear();r.voteEndsAt=this.clock()+CONFIG.voteSec*1000;return r;
 }
 // Most votes wins; ties and empty votes fall back to candidate order (host's pick first).
 voteWinner(r:Room){const maps=r.voteMaps??['old_dorm'],count=(id:string)=>[...r.votes.values()].filter(v=>v===id).length;return maps.reduce((best,id)=>count(id)>count(best)?id:best,maps[0])}
 start(r:Room,mapId=this.voteWinner(r)){ // called once after voting
 if(!['waiting','voting'].includes(r.phase))throw Error('ROOM_BUSY');
 r.game=createGame(r.code,r.players,r.settings.durationSec,r.settings.hunterCount,r.settings.moleEnabled,{now:this.clock(),lastHunters:r.lastHunters,mapId});
 r.lastHunters=r.game.players.filter(p=>p.role==='hunter').map(p=>p.id);r.phase='playing';r.resultSent=false;return r;
 }
 reset(r:Room){r.phase='waiting';r.game=undefined;r.resultSent=false;r.votes.clear();for(const p of r.players)p.ready=p.isBot}
 matchStart(p:Player){
 if(this.roomOf(p.id))throw Error('ALREADY_IN_ROOM');
 if(!this.queue.some(q=>q.player.id===p.id))this.queue.push({player:p,at:this.clock()});return this.matchDrain();
 }
 matchDrain(){if(this.queue.length<this.minPlayers)return null;return this.matchRoom(this.queue.splice(0,Math.min(12,this.queue.length)).map(q=>q.player))}
 private matchRoom(ps:Player[]){const r=this.create(ps[0]);for(const p of ps.slice(1))this.join(r.code,p);for(const p of r.players)p.ready=true;this.beginVote(r,true);return r}
 matchCancel(id:string){this.queue=this.queue.filter(q=>q.player.id!==id)}
 matchStatus(id:string){const q=this.queue.find(q=>q.player.id===id),elapsedSec=q?Math.floor((this.clock()-q.at)/1000):0;return {elapsedSec,found:this.queue.length,needed:this.minPlayers,canAiFill:!!q&&elapsedSec>=60}}
 aiFill(id:string){
 if(!this.matchStatus(id).canAiFill)throw Error('AI_FILL_TOO_EARLY');
 // Consume the oldest queued players first; waiting requester is in this sub-threshold queue.
 return this.matchRoom(this.queue.splice(0,12).map(q=>q.player));
 }
}
