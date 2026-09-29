import {pathToFileURL} from 'node:url';
import {createGame,rewardsFor,tickGame} from './game/engine.js';
import {CONFIG} from './game/config.js';
import type {Color} from './types.js';
export function seeded(seed:number){return ()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return ((t^t>>>14)>>>0)/4294967296}}
export function simulate(seed=42,log:(s:string)=>void=()=>{},mapId='old_dorm'){
 const players=Array.from({length:8},(_,i)=>({id:'bot_'+i,nickname:'AI-'+(i+1),color:'green' as Color,isBot:true}));
 const g=createGame('SIM',players,600,'auto',false,{now:1000000,random:seeded(seed),mapId});log('phase assign');let lastPhase='assign';
 for(let i=0;i<CONFIG.tickHz*(g.durationSec+CONFIG.assignSec+CONFIG.hideSec+CONFIG.resultSec+2);i++){
 tickGame(g);
 for(const m of g.outbox.splice(0)){
 if(m.t==='game.phase'){if(m.phase!==lastPhase){log('phase '+m.phase);lastPhase=String(m.phase)}else log('timer updated '+m.phase+' endsAt='+m.endsAt)}
 if(m.t==='game.caught')log('caught '+m.victimId+' by '+m.hunterId);
 if(m.t==='game.rescued')log('rescued '+m.victimId);
 if(m.t==='game.fx'&&m.kind==='generator_fixed')log('generator fixed at '+m.x+','+m.y);
 if(m.t==='game.event')log('event '+m.kind+' '+m.stage);
 if(m.t==='game.result')log('winner '+m.winner);
 }
 if(g.phase==='waiting')break;
 }
 if(!g.result||g.phase!=='waiting')throw Error('Simulation did not complete the result and return cycle');
 log('generators '+g.generators.filter(x=>x.fixed).length+'/3; captured '+g.players.filter(p=>p.caught).length);
 for(const row of g.result.players)log(row.nickname+' '+row.role+' score='+row.score+' '+JSON.stringify(row.breakdown)+' rewards='+JSON.stringify(rewardsFor(g,g.players.find(p=>p.id===row.id)!)));
 return g;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)simulate(Number(process.env.SIM_SEED)||42,s=>console.log('[sim]',s));
