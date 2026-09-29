import {randomUUID} from 'node:crypto';
import type {GamePlayer,GameState,Player,Role} from '../types.js';
import {CONFIG,RULES} from './config.js';
import {createOldDorm,zoneAt} from './maps/old_dorm.js';
import {distance,hasLineOfSight,validMove,visible,visionRadius} from './vision.js';
import {catchPlayer,repairSeconds,slap} from './combat.js';
import {pickup,randomItem,tickItems,useItem} from './items.js';
import {tickEvents} from './events.js';
import {active,emit,fx,living,ripple,score} from './shared.js';
import {tickBots} from './ai/bot.js';

export function rolesFor(ids:string[],lastHunters:string[]=[],hunterCount:'auto'|1|2='auto',moleEnabled=true,random=Math.random):Role[]{
 const roles:Role[]=ids.map(()=> 'hider'),shuffled=ids.map((_,i)=>i);
 for(let i=shuffled.length-1;i>0;i--){const j=Math.floor(random()*(i+1));[shuffled[i],shuffled[j]]=[shuffled[j],shuffled[i]]}
 const hc=Math.min(ids.length-1,hunterCount==='auto'?(ids.length>=10?2:1):hunterCount),candidates=shuffled.filter(i=>!lastHunters.includes(ids[i]));
 if(candidates.length<hc)throw Error('HUNTER_ROTATION');
 for(const i of candidates.slice(0,hc))roles[i]='hunter';
 if(moleEnabled&&ids.length>=10){const i=shuffled.find(i=>roles[i]==='hider');if(i!==undefined)roles[i]='mole'}
 return roles;
}
export function createGame(roomCode:string,players:Pick<Player,'id'|'nickname'|'color'|'isBot'>[],durationSec=300,hunterCount:'auto'|1|2='auto',moleEnabled=true,options:{now?:number;random?:()=>number;lastHunters?:string[]}={}):GameState{
 durationSec=CONFIG.huntSec??durationSec;
 const now=options.now??Date.now(),random=options.random??Math.random,map=createOldDorm(),roles=rolesFor(players.map(p=>p.id),options.lastHunters??[],hunterCount,moleEnabled,random);let hi=0;
 const ps:GamePlayer[]=players.map((p,i)=>{
 const spawn=roles[i]==='hunter'?map.hunterSpawn:map.hiderSpawns[hi++%map.hiderSpawns.length];
 return {...p,ready:true,isHost:false,online:true,role:roles[i],...spawn,dir:0,state:'normal',stamina:RULES.staminaMax,items:[null,null],prop:null,caged:false,caught:false,rescued:false,ghostSide:null,chooseUntil:0,ghostReadyAt:0,reportReadyAt:0,input:{seq:-1,mx:0,my:0,run:false,at:now},running:false,flashlight:true,stunnedUntil:0,transitionUntil:0,lastRunRipple:-Infinity,lastJitter:now,lastSlap:-Infinity,disconnectedAt:null,expired:false,interact:null,slowUntil:0,boostUntil:0,revealedUntil:0,lastItemAt:0,score:{},survival:0,captures:0,accused:false,eliminated:false};
 });
 const huntAt=now+(CONFIG.assignSec+CONFIG.hideSec)*1000;
 const g:GameState={id:randomUUID(),roomCode,mapId:map.id,map,phase:'assign',now,phaseEndsAt:now+CONFIG.assignSec*1000,startedAt:now,huntStartedAt:huntAt,durationSec,tick:0,players:ps,generators:map.generators.map(p=>({...p,progress:0,fixed:false,participants:new Set(),lastRipple:0})),ripples:[],footprints:[],marks:[],drops:[],eventCounts:{},nextEventAt:huntAt+RULES.eventInterval*1000,nextDropAt:huntAt+RULES.dropInterval*1000,event:null,walls:new Map(),hazards:[],outbox:[],voided:false,random};
 g.drops=[0,2,3,4,6,9].map((idx,i)=>({...map.itemSpots[idx],id:'initial_'+i,item:randomItem(g,true),stage:'landed',at:now}));
 return g;
}
export function setInput(g:GameState,id:string,seq:number,mx:number,my:number,run:boolean){
 const p=g.players.find(p=>p.id===id);if(!p||![seq,mx,my].every(Number.isFinite)||!Number.isInteger(seq)||seq<=p.input.seq||Math.abs(mx)>1||Math.abs(my)>1)return;
 const len=Math.max(1,Math.hypot(mx,my));p.input={seq,mx:mx/len,my:my/len,run,at:g.now};
}
export function applyInput(g:GameState,id:string,mx:number,my:number,run:boolean){const p=g.players.find(p=>p.id===id);if(p)setInput(g,id,p.input.seq+1,mx,my,run)}
export function ghostSide(g:GameState,id:string,side:string){const p=g.players.find(p=>p.id===id);if(!p||!p.caged||p.ghostSide||g.now>p.chooseUntil||!['guardian','wraith'].includes(side))return;p.ghostSide=side as 'guardian'|'wraith';p.state='ghost'}
export function setOnline(g:GameState,id:string,online:boolean){const p=g.players.find(p=>p.id===id);if(!p)return;p.online=online;if(online)p.disconnectedAt=null;else if(p.disconnectedAt===null){p.disconnectedAt=g.now;p.input.mx=0;p.input.my=0;p.interact=null}}
function unmask(g:GameState,p:GamePlayer){if(p.state==='disguised'){p.state='normal';p.prop=null;p.transitionUntil=g.now+RULES.undisguiseSec*1000}}
function changePhase(g:GameState,phase:GameState['phase'],endsAt:number){g.phase=phase;g.phaseEndsAt=endsAt;emit(g,{t:'game.phase',phase,endsAt})}
export function action(g:GameState,id:string,kind:string,data:Record<string,unknown>={}){
 const p=g.players.find(p=>p.id===id);if(!p||!['hide','hunt','final'].includes(g.phase))return;
 if(p.state==='ghost'&&kind==='ghost_skill'&&g.now>=p.ghostReadyAt){
 if(p.ghostSide==='guardian'){const x=Number(data.x),y=Number(data.y);if(!Number.isFinite(x)||!Number.isFinite(y)||x<0||y<0||x>=g.map.w||y>=g.map.h||distance(p,{x,y})>12)return;ripple(g,{x,y},'fake',false,p.id)}
 else if(p.ghostSide==='wraith'){const t=g.players.find(q=>q.id===data.targetId&&q.role==='hider'&&living(q)&&visible(g,p,q));if(!t)return;g.marks.push({x:t.x,y:t.y,kind:'wraith',targetId:t.id,by:p.id,until:g.now+2000,audience:'hunter'})}else return;
 p.ghostReadyAt=g.now+RULES.ghostCooldown*1000;return;
 }
 if(kind==='report'&&p.role==='mole'&&g.now>=p.reportReadyAt){
 const t=g.players.find(q=>q.id===data.targetId&&q.role==='hider'&&living(q)&&visible(g,p,q));if(!t)return;
 g.marks.push({x:t.x,y:t.y,kind:'report',targetId:t.id,by:p.id,until:g.now+3000,audience:'hunter'});
 g.marks.push({x:t.x,y:t.y,kind:'report_assist',targetId:t.id,by:p.id,until:g.now+10000,audience:'hunter'});
 p.reportReadyAt=g.now+(p.caged?60:RULES.reportCooldown)*1000;fx(g,p,'report',p.id);return;
 }
 if(!living(p)||g.now<p.stunnedUntil||g.now<p.transitionUntil||p.role==='hunter'&&g.phase==='hide')return;
 if(kind==='slap')return slap(g,p);
 if(kind==='flashlight'&&p.role==='hunter'){p.flashlight=!p.flashlight;return}
 if(kind==='undisguise'){unmask(g,p);return}
 if(kind==='disguise'&&p.role!=='hunter'&&p.revealedUntil<=g.now){
 const prop=String(data.prop??''),zone=zoneAt(p,g.map);
 if(g.map.props.some(q=>q.prop===prop&&distance(p,q)<=RULES.disguiseRange&&zoneAt(q,g.map)===zone&&hasLineOfSight(p.x,p.y,q.x,q.y,g.map))){p.state='disguised';p.prop=prop;p.input.mx=p.input.my=0;p.interact=null;p.lastJitter=g.now}return;
 }
 if(kind==='use_item'){unmask(g,p);useItem(g,p,Number(data.slot),{x:Number(data.dx)||Math.cos(p.dir),y:Number(data.dy)||Math.sin(p.dir)});return}
 if(kind==='interact_stop'||kind==='accuse_stop'){p.interact=null;return}
 if(kind==='interact_start'){
 unmask(g,p);p.input.mx=p.input.my=0;if(pickup(g,p))return;
 const door=g.map.lockedDoors.find(q=>distance(p,{x:q.x+.5,y:q.y+.5})<1.8);
 if(door){g.map.lockedDoors=g.map.lockedDoors.filter(q=>q!==door);emit(g,{t:'game.wall',cells:[{...door,tile:3,locked:false}]});ripple(g,door,'door');return}
 if(p.role==='hunter')return;
 const victim=g.players.find(q=>q.caged&&!q.rescued&&!q.eliminated&&(data.targetId===undefined||q.id===data.targetId));
 if(victim&&distance(p,g.map.cage)<=RULES.interactRange){p.interact={kind:'rescue',target:victim.id,value:0};return}
 if(active(g)){const gen=g.generators.filter(q=>!q.fixed&&distance(p,q)<=RULES.interactRange&&hasLineOfSight(p.x,p.y,q.x,q.y,g.map)).sort((a,b)=>distance(p,a)-distance(p,b))[0];if(gen)p.interact={kind:'repair',target:String(gen.id),value:gen.progress}}return;
 }
 if(kind==='accuse_start'&&p.role==='hider'&&!p.accused&&active(g)){const t=g.players.find(q=>q.id===data.targetId&&q.id!==id&&q.role!=='hunter'&&living(q)&&distance(p,q)<=2&&visible(g,p,q));if(t)p.interact={kind:'accuse',target:t.id,value:0}}
}
export function mark(g:GameState,id:string,kind:string,x:number,y:number){
 const p=g.players.find(p=>p.id===id);if(!p||!['danger','help','item','suspect'].includes(kind)||![x,y].every(Number.isFinite)||x<0||y<0||x>=g.map.w||y>=g.map.h)return;
 if(g.marks.some(m=>m.by===id&&m.kind===kind))return;g.marks.push({x,y,kind,until:g.now+3000,by:id,audience:p.role==='hunter'?'hunter':'hider'});
}
function move(g:GameState,p:GamePlayer,dt:number){
 if(!p.online||p.expired||g.phase==='assign'||g.phase==='result'||g.phase==='waiting'||p.role==='hunter'&&g.phase==='hide'||p.state==='caged')return;
 if(g.now>=p.stunnedUntil&&p.state==='stunned')p.state='normal';if(g.now<p.stunnedUntil)return;
 let {mx,my,run}=p.input;if(g.now-p.input.at>500){mx=my=0;run=false}
 if(Math.hypot(mx,my)>0){unmask(g,p);p.interact=null;p.dir=Math.atan2(my,mx)}if(g.now<p.transitionUntil)return;
 const hunter=p.role==='hunter',ghost=p.state==='ghost',free=hunter||ghost||p.boostUntil>g.now||(g.event?.stage==='start'&&g.event.kind==='adrenaline');
 const running=run&&(free||p.stamina>0);p.running=running&&Math.hypot(mx,my)>0;
 let speed=hunter?(running?RULES.hunterRun:RULES.hunterWalk):(running?RULES.hiderRun:RULES.hiderWalk);
 if(g.phase==='final'&&hunter)speed*=1.2;if(p.boostUntil>g.now)speed*=hunter?RULES.hunterBoost:RULES.hiderBoost;if(p.slowUntil>g.now)speed*=1-RULES.netSlow;
 if(g.event?.stage==='start'&&g.event.kind==='adrenaline')speed*=1.5;
 if(!hunter&&!ghost)p.stamina=Math.max(0,Math.min(RULES.staminaMax,p.stamina+(p.running&&!free?-1:RULES.staminaRegen)*dt));
 const old={x:p.x,y:p.y},nx=p.x+mx*speed*dt,ny=p.y+my*speed*dt;
 if(ghost){p.x=Math.max(.4,Math.min(g.map.w-.4,nx));p.y=Math.max(.4,Math.min(g.map.h-.4,ny))}
 else{if(validMove(nx,p.y,g.map))p.x=nx;if(validMove(p.x,ny,g.map))p.y=ny}
 if(!ghost&&distance(p,old)>.001){
 if(p.running&&g.now-p.lastRunRipple>=RULES.runRippleSec*1000){ripple(g,p,'run',hunter,p.id);g.footprints.push({x:p.x,y:p.y,dir:p.dir,until:g.now+RULES.footprintSec*1000,hunter});p.lastRunRipple=g.now}
 const oldTile=Math.floor(old.y)*g.map.w+Math.floor(old.x),tile=Math.floor(p.y)*g.map.w+Math.floor(p.x);
 if(tile!==oldTile&&g.map.tiles[tile]===3)ripple(g,p,'door',hunter,p.id);
 }
}
function interact(g:GameState,dt:number){
 for(const gen of g.generators){
 if(gen.fixed)continue;
 const repairers=g.players.filter(p=>living(p)&&p.state==='normal'&&p.interact?.kind==='repair'&&p.interact.target===String(gen.id)&&distance(p,gen)<=RULES.interactRange&&hasLineOfSight(p.x,p.y,gen.x,gen.y,g.map));
 if(!repairers.length)continue;const h=repairers.filter(p=>p.role==='hider'),m=repairers.filter(p=>p.role==='mole');
 gen.progress=Math.max(0,Math.min(1,gen.progress+(h.length?dt/repairSeconds(h.length):0)-m.length*.01*dt));h.forEach(p=>gen.participants.add(p.id));
 for(const p of repairers)if(p.interact)p.interact.value=gen.progress;
 if(g.now-gen.lastRipple>=1000){ripple(g,gen,'repair');gen.lastRipple=g.now}
 if(gen.progress>=1){gen.fixed=true;g.phaseEndsAt-=g.durationSec*RULES.generatorReduction*1000;fx(g,gen,'generator_fixed');
 for(const id of gen.participants){const p=g.players.find(p=>p.id===id);if(p)score(p,'修理发电机',RULES.points.generator)}
 for(const p of repairers)p.interact=null;emit(g,{t:'game.phase',phase:g.phase,endsAt:g.phaseEndsAt});
 }
 }
 for(const p of g.players){
 const i=p.interact;if(!i||i.kind==='repair')continue;const t=g.players.find(q=>q.id===i.target);
 if(!t||!living(p)||p.state!=='normal'){p.interact=null;continue}
 if(i.kind==='rescue'){
 if(!t.caged||t.rescued||distance(p,g.map.cage)>RULES.interactRange){p.interact=null;continue}
 i.value+=dt/RULES.rescueSec;
 if(i.value>=1){t.caged=false;t.rescued=true;t.state='normal';t.ghostSide=null;t.prop=null;t.x=g.map.cage.x;t.y=g.map.cage.y+1;t.stunnedUntil=0;t.transitionUntil=0;t.revealedUntil=0;t.input.mx=t.input.my=0;score(p,'解救队友',RULES.points.rescue);p.interact=null;emit(g,{t:'game.rescued',rescuerId:p.id,victimId:t.id})}
 }else if(i.kind==='accuse'){
 if(distance(p,t)>2||!living(t)||!visible(g,p,t)){p.interact=null;continue}i.value+=dt/2;
 if(i.value>=1){p.accused=true;p.interact=null;if(t.role==='mole'){t.eliminated=true;t.caged=true;t.state='ghost';t.ghostSide='wraith';score(p,'指认卧底',RULES.points.accuse);fx(g,t,'mole_exposed',p.id)}
 else g.marks.push({x:p.x,y:p.y,kind:'report',until:g.now+5000,targetId:p.id,audience:'hunter'})}
 }
 }
}
export function rewardsFor(g:GameState,p:GamePlayer){
 if(g.voided)return {exp:0,coins:0,rankDelta:0};
 const total=Object.values(p.score).reduce((a,b)=>a+b,0),side=p.role==='hunter'||p.role==='mole'||p.caged&&p.ghostSide==='wraith'?'hunter':'hider',win=g.winner===side;
 return {exp:50+Math.floor(total/2),coins:20+Math.floor(total/5),rankDelta:win?20:-10};
}
export function finish(g:GameState,winner:'hider'|'hunter',voided=false){
 if(g.phase==='result'||g.phase==='waiting')return;g.winner=winner;g.voided=voided;
 if(!voided)for(const p of g.players){
 if(p.role==='hider'){score(p,'存活分钟',Math.floor(p.survival/60)*RULES.points.minute);if(living(p))score(p,'存活到结束',RULES.points.survive)}
 if(p.role==='mole'&&living(p))score(p,'卧底存活',RULES.points.moleSurvive);
 }
 const players=g.players.map(p=>({id:p.id,nickname:p.nickname,color:p.color,role:p.role,score:Object.values(p.score).reduce((a,b)=>a+b,0),breakdown:Object.entries(p.score).filter(([,pts])=>pts!==0).map(([label,pts])=>({label,pts})),caught:p.caught}));
 const side=(id:string)=>{const p=g.players.find(p=>p.id===id)!;return p.role==='hunter'||p.role==='mole'||p.caged&&p.ghostSide==='wraith'?'hunter':'hider'};
 const best=(team:string)=>players.filter(p=>side(p.id)===team).sort((a,b)=>b.score-a.score)[0]?.id??null;
 g.result={winner,players,mvp:{hider:best('hider'),hunter:best('hunter')},...(voided?{voided:true}:{})};
 changePhase(g,'result',g.now+CONFIG.resultSec*1000);emit(g,{t:'game.result',...g.result});
}
export function tickGame(g:GameState,now=g.now+1000/CONFIG.tickHz){
 const dt=Math.min(.05,Math.max(0,(now-g.now)/1000));g.now=now;g.tick++;
 if(g.phase==='result'){if(now>=g.phaseEndsAt)g.phase='waiting';return}if(g.phase==='waiting')return;
 if(g.phase==='assign'&&now>=g.phaseEndsAt)changePhase(g,'hide',g.startedAt+(CONFIG.assignSec+CONFIG.hideSec)*1000);
 if(g.phase==='hide'&&now>=g.phaseEndsAt)changePhase(g,'hunt',g.huntStartedAt+g.durationSec*1000);
 for(const p of g.players){
 if(p.disconnectedAt!==null&&!p.expired&&now-p.disconnectedAt>=CONFIG.reconnectSec*1000){p.expired=true;if(p.role!=='hunter')catchPlayer(g,p)}
 if(p.caged&&!p.ghostSide&&now>=p.chooseUntil){p.ghostSide='guardian';p.state='ghost'}
 }
 const hunters=g.players.filter(p=>p.role==='hunter');
 if(hunters.length&&hunters.every(p=>p.expired&&!p.online)){finish(g,'hider',true);return}
 tickBots(g);
 for(const p of g.players){
 move(g,p,dt);if(living(p)&&p.role==='hider'&&active(g))p.survival+=dt;
 if(p.state==='disguised'&&now-p.lastJitter>=RULES.jitterSec*1000){fx(g,p,'disguise_jitter',p.id);p.lastJitter=now}
 }
 if(active(g)){
 interact(g,dt);tickItems(g);tickEvents(g);
 if(g.phase==='hunt'&&g.phaseEndsAt-now<=RULES.finalSec*1000)changePhase(g,'final',g.phaseEndsAt);
 if(g.phase==='final'&&g.tick%(RULES.heartbeatSec*CONFIG.tickHz)===0)for(const p of g.players.filter(p=>p.role!=='hunter'&&living(p)))ripple(g,p,'heartbeat');
 for(const r of g.ripples.filter(r=>r.kind==='fake'&&!r.credited&&r.by))if(hunters.some(h=>distance(h,r)<1.5)){const by=g.players.find(p=>p.id===r.by);if(by)score(by,'假波纹诱导',RULES.points.guardian);r.credited=true}
 if(!g.players.some(p=>p.role==='hider'&&living(p)))finish(g,'hunter');else if(now>=g.phaseEndsAt)finish(g,'hider');
 }
 g.ripples=g.ripples.filter(r=>r.until>now);g.footprints=g.footprints.filter(f=>f.until>now);g.marks=g.marks.filter(m=>m.until>now);
}
export function snapshotFor(g:GameState,id:string){
 const p=g.players.find(p=>p.id===id);if(!p)return null;
 const marks=g.marks.filter(m=>m.kind!=='report_assist'&&(m.audience==='all'||m.audience==='hunter'&&(p.role==='hunter'||p.role==='mole'||p.ghostSide==='wraith')||m.audience==='hider'&&p.role!=='hunter'));
 const isMarked=(q:GamePlayer)=>marks.some(m=>m.targetId===q.id&&(m.kind==='report'||m.kind==='wraith'));
 const players=g.players.filter(q=>q.id!==id&&!(q.state==='ghost'&&p.role==='hunter')&&(visible(g,p,q)||isMarked(q)));
 return {t:'game.snap',tick:g.tick,now:g.now,timeLeftSec:Math.max(0,(g.phaseEndsAt-g.now)/1000),
 roster:g.players.filter(q=>q.role!=='hunter').map(q=>({color:q.color,caught:!living(q)})),nextEventAt:g.nextEventAt,
 alive:g.players.filter(q=>q.role==='hider'&&living(q)).length,totalHiders:g.players.filter(q=>q.role==='hider').length,caughtByMe:p.captures,
 you:{x:p.x,y:p.y,dir:p.dir,state:p.state,stamina:p.stamina,items:p.items,prop:p.prop,flashlight:p.flashlight,visionRadius:visionRadius(g,p),ghostSide:p.ghostSide,caged:p.caged,rescued:p.rescued,ghostChoiceEndsAt:p.chooseUntil,ackSeq:p.input.seq,cooldowns:{ghostSkill:Math.max(0,(p.ghostReadyAt-g.now)/1000),report:Math.max(0,(p.reportReadyAt-g.now)/1000)},progress:p.interact?{kind:p.interact.kind,value:p.interact.value}:null},
 players:players.map(q=>({id:q.id,x:q.x,y:q.y,dir:q.dir,state:q.state,prop:q.state==='disguised'?q.prop:null,running:q.running})),
 ripples:g.ripples.map(({x,y,r,kind,hunter})=>({x,y,r,kind,hunter})),
 footprints:g.footprints.filter(f=>visible(g,p,f)).map(({x,y,dir})=>({x,y,dir})),
 generators:g.generators.map(({id,x,y,progress,fixed})=>({id,x,y,progress,fixed})),
 marks:marks.map(m=>{const t=m.targetId?g.players.find(q=>q.id===m.targetId):null;return {x:t?.x??m.x,y:t?.y??m.y,kind:m.kind,until:m.until}})};
}
