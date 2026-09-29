import type {GameMap,GameState,GamePlayer,Pos} from '../../types.js';
import {blockedTile,oldDorm} from '../maps/old_dorm.js';
import {distance,hasLineOfSight,visible} from '../vision.js';
import {AI,RULES} from '../config.js';
import {action,applyInput,ghostSide} from '../engine.js';
import {living} from '../shared.js';
export function astar(start:Pos,goal:Pos,map:GameMap=oldDorm):Pos[]{
 const index=(p:Pos)=>Math.floor(p.y)*map.w+Math.floor(p.x),s=index(start),end=index(goal);
 if(blockedTile(goal.x,goal.y,map)||blockedTile(start.x,start.y,map))return [];
 const open=[s],parent=new Map<number,number>(),cost=new Map([[s,0]]),closed=new Set<number>();
 // Transit cells (elevator, escalator, hatch) are extra edges costing their wait time.
 const portals=new Map((map.portals??[]).map(q=>[q.y*map.w+q.x,q]));
 const h=(n:number)=>Math.abs(n%map.w-Math.floor(goal.x))+Math.abs(Math.floor(n/map.w)-Math.floor(goal.y));
 while(open.length){
 let best=0;for(let i=1;i<open.length;i++)if(cost.get(open[i])!+h(open[i])<cost.get(open[best])!+h(open[best]))best=i;
 const current=open.splice(best,1)[0];if(current===end){
 const path=[current];while(parent.has(path[0]))path.unshift(parent.get(path[0])!);
 return path.map(k=>({x:k%map.w+.5,y:Math.floor(k/map.w)+.5}));
 }
 closed.add(current);const x=current%map.w,y=Math.floor(current/map.w);
 const portal=portals.get(current);
 const steps:[number,number][]=[[x+1,y],[x-1,y],[x,y+1],[x,y-1]];if(portal)steps.push([portal.to.x,portal.to.y]);
 for(const [nx,ny] of steps){
 if(blockedTile(nx,ny,map))continue;
 const next=ny*map.w+nx;if(closed.has(next))continue;
 const nc=cost.get(current)!+(portal&&Math.abs(nx-x)+Math.abs(ny-y)>1?1+portal.delaySec*4:1);
 if(nc<(cost.get(next)??Infinity)){cost.set(next,nc);parent.set(next,current);if(!open.includes(next))open.push(next)}
 }
 }return [];
}
function route(g:GameState,p:GamePlayer,goal:Pos,mode:string){
 const ai=p.ai!;ai.goal={x:goal.x,y:goal.y};ai.mode=mode;ai.path=astar(p,goal,g.map);
 if(ai.path.length>1&&distance(p,ai.path[0])<.4)ai.path.shift();
}
// Short local escape routes cannot initially turn towards the threat. Score
// reachable corners/cover rather than distant spawns on the other side of a wall.
function flee(g:GameState,p:GamePlayer,threat:Pos){
 const choices: {path:Pos[];score:number}[]=[];
 for(let dy=-6;dy<=6;dy+=3)for(let dx=-6;dx<=6;dx+=3){
 const goal={x:Math.floor(p.x)+dx+.5,y:Math.floor(p.y)+dy+.5};
 if(distance(p,goal)<3||blockedTile(goal.x,goal.y,g.map))continue;
 const path=astar(p,goal,g.map);if(path.length<2||path.length>16)continue;
 const next=path[1];if(distance(next,threat)<distance(p,threat)-.25)continue;
 const cover=hasLineOfSight(threat.x,threat.y,goal.x,goal.y,g.map)?0:3;
 choices.push({path,score:distance(goal,threat)+cover-path.length*.15});
 }
 choices.sort((a,b)=>b.score-a.score);const best=choices[0];
 if(best){const ai=p.ai!;ai.path=best.path;ai.goal=best.path.at(-1)!;ai.mode='flee';ai.until=g.now+2500;action(g,p.id,'interact_stop')}
}
function choose(g:GameState,p:GamePlayer){
 const ai=p.ai!,hunter=p.role==='hunter';
 const seen=g.players.filter(q=>q.id!==p.id&&living(q)&&visible(g,p,q));
 const threat=seen.find(q=>q.role==='hunter')||g.ripples.filter(r=>r.hunter&&distance(p,r)<7).at(-1);
 if(hunter){
 const target=seen.filter(q=>q.role!=='hunter'&&q.state!=='disguised').sort((a,b)=>distance(p,a)-distance(p,b))[0];
 if(target){route(g,p,target,'chase');return}
 const jitter=seen.find(q=>q.state==='disguised'&&g.now-q.lastJitter<750);
 if(jitter&&g.random()<.65){route(g,p,jitter,'suspect');return}
 if(ai.mode==='suspect'&&ai.path.length)return;
 if(ai.mode==='chase'&&ai.path.length)return;
 if(!ai.patrolRun&&g.now<ai.until){ai.path=[];return}
 const noise=g.ripples.filter(r=>!r.hunter&&distance(p,r)<(ai.patrolRun?AI.hunterNoiseRange:AI.hunterNoiseRangeWalk)).sort((a,b)=>distance(p,a)-distance(p,b))[0];
 const trace=g.footprints.filter(f=>!f.hunter&&visible(g,p,f)).at(-1);
 if((noise||trace)&&distance(p,(noise||trace)!)>1.5){route(g,p,(noise||trace)!,'track');return}
 if(g.now>=ai.suspectAt){
 // Treat real props and disguised players identically; no omniscient disguise identification.
 const props=[...g.map.props,...seen.filter(q=>q.state==='disguised')].filter(q=>visible(g,p,q));
 const prop=props[Math.floor(g.random()*props.length)];
 // Imprecise visual judgement: occasional false positives and skipped props.
 ai.suspectAt=g.now+AI.suspectMinMs+g.random()*AI.suspectRandMs;
 if(prop&&g.random()<AI.suspectChance){route(g,p,prop,'suspect');return}
 }
 if(ai.path.length&&ai.mode==='patrol')return;
 const points=[...g.map.props,...g.map.generators,...g.map.hiderSpawns];route(g,p,points[Math.floor(g.random()*points.length)],'patrol');if(!ai.patrolRun)ai.until=g.now+5000+g.random()*5000;return;
 }
 const hunterSeen=seen.some(q=>q.role==='hunter');
 if(threat){
 // A disguised bot holds its nerve: moving is what gives it away. Only a
 // hunter right on top of it occasionally makes it bolt.
 if(p.state==='disguised'&&(distance(p,threat)>AI.disguisedPanicRange||g.random()>AI.disguisedPanicChance)){ai.mode='disguise';return}
 // Out of the hunter's sight with cover close by: vanish into a prop instead of running on.
 if(!hunterSeen&&p.state!=='disguised'){
 const cover=g.map.props.filter(q=>distance(p,q)<=AI.coverRange&&!hasLineOfSight(threat.x,threat.y,q.x,q.y,g.map)).sort((a,b)=>distance(p,a)-distance(p,b))[0];
 if(cover){route(g,p,cover,'disguise');ai.until=g.now+AI.disguiseMinMs+g.random()*AI.disguiseRandMs;return}
 }
 flee(g,p,threat);return;
 }
 if(ai.mode==='flee'&&g.now<ai.until)return;
 if(p.interact)return;
 const allFixed=g.generators.every(q=>q.fixed);
 if(p.state==='disguised'&&g.now<ai.until&&!(g.phase==='hunt'&&g.generators.some(q=>!q.fixed&&distance(p,q)<12)))return;
 if(ai.path.length&&['repair','pickup','disguise','rescue'].includes(ai.mode))return;
 const drop=g.drops.filter(d=>d.stage==='landed'&&p.items.includes(null)&&distance(p,d)<9).sort((a,b)=>distance(p,a)-distance(p,b))[0];
 if(drop){route(g,p,drop,'pickup');return}
 const victim=g.players.find(q=>q.caged&&!q.rescued&&!q.eliminated);
 if(victim&&!hunterSeen&&distance(p,g.map.cage)<AI.rescueRange&&g.random()<AI.rescueChance){route(g,p,g.map.cage,'rescue');return}
 const gens=g.generators.filter(q=>!q.fixed).sort((a,b)=>distance(p,a)-distance(p,b));
 if(g.phase!=='hide'&&gens.length&&g.random()<AI.repairChance){route(g,p,gens[0],'repair');return}
 const props=g.map.props.slice().sort((a,b)=>distance(p,a)-distance(p,b)).slice(0,4);
 // Once there is no generator left to fix, lie low far longer between moves.
 const hold=allFixed?AI.lateHoldMul:1;
 const prop=props[Math.floor(g.random()*props.length)];route(g,p,prop,'disguise');ai.until=g.now+(AI.disguiseMinMs+g.random()*AI.disguiseRandMs)*hold;
}
export function tickBots(g:GameState){
 if(!['hide','hunt','final'].includes(g.phase))return;
 for(const p of g.players.filter(p=>p.isBot)){
 if(!p.ai)p.ai={path:[],goal:null,nextThink:g.now,mode:'idle',until:0,suspectAt:0};
 const ai=p.ai!;
 if(ai.patrolRun===undefined)ai.patrolRun=g.random()<.8;
 if(p.caged){
 if(!p.ghostSide)ghostSide(g,p.id,g.random()<.8?'guardian':'wraith');
 if(p.state==='ghost'&&g.now>=p.ghostReadyAt){
 const t=g.players.find(q=>q.role==='hider'&&living(q)&&visible(g,p,q));
 if(p.ghostSide==='wraith'&&t)action(g,p.id,'ghost_skill',{targetId:t.id});
 else action(g,p.id,'ghost_skill',{x:p.x+2,y:p.y+1});
 }continue;
 }
 if(p.role==='hunter'&&g.phase==='hide')continue;
 if(g.now>=ai.nextThink){choose(g,p);ai.nextThink=g.now+700}
 if(p.role==='hunter'){
 const target=g.players.filter(q=>q.id!==p.id&&q.role!=='hunter'&&living(q)&&visible(g,p,q)&&q.state!=='disguised').sort((a,b)=>distance(p,a)-distance(p,b))[0];
 if(target&&distance(p,target)<=1.2)action(g,p.id,'slap');
 if(ai.mode==='suspect'&&ai.goal&&distance(p,ai.goal)<1.1){action(g,p.id,'slap');ai.path=[];ai.mode='idle'}
 }
 const slot=p.items.findIndex(Boolean);
 if(slot>=0&&(ai.mode==='chase'||ai.mode==='flee')&&g.now-p.lastItemAt>1500)action(g,p.id,'use_item',{slot,dx:(ai.goal?.x??p.x+1)-p.x,dy:(ai.goal?.y??p.y)-p.y});
 if(ai.goal&&distance(p,ai.goal)<1.1){
 if(['repair','rescue','pickup'].includes(ai.mode)){if(!p.interact)action(g,p.id,'interact_start');applyInput(g,p.id,0,0,false);ai.path=[];if(ai.mode==='pickup')ai.nextThink=0;continue}
 if(ai.mode==='disguise'){
 const prop=g.map.props.find(q=>distance(p,q)<=2);
 if(prop&&p.state!=='disguised')action(g,p.id,'disguise',{prop:prop.prop});
 applyInput(g,p.id,0,0,false);ai.path=[];continue;
 }
 }
 if(p.interact||p.state==='disguised'&&ai.mode==='disguise'){applyInput(g,p.id,0,0,false);continue}
 // Advance waypoints only close to their centers so corner collision never wedges a bot.
 while(ai.path.length&&distance(p,ai.path[0])<.12)ai.path.shift();
 const next=ai.path[0];
 // A far waypoint right after a transit cell: stand still on it until the ride happens.
 if(next&&distance(p,next)>1.6&&(g.map.portals??[]).some(q=>q.x===Math.floor(p.x)&&q.y===Math.floor(p.y))){applyInput(g,p.id,0,0,false);continue}
 if(next){const dx=next.x-p.x,dy=next.y-p.y,d=Math.hypot(dx,dy);
 const nearbyHunter=g.players.some(q=>q.role==='hunter'&&visible(g,p,q)&&distance(p,q)<5);
 const run=ai.mode==='flee'&&(nearbyHunter||p.stamina>2)||ai.mode==='chase'||p.role==='hunter'&&ai.patrolRun;
 let speed=p.role==='hunter'?(run?RULES.hunterRun:RULES.hunterWalk):(run?RULES.hiderRun:RULES.hiderWalk);
 if(g.phase==='final'&&p.role==='hunter')speed*=1.2;
 if(p.boostUntil>g.now)speed*=p.role==='hunter'?RULES.hunterBoost:RULES.hiderBoost;
 if(g.event?.stage==='start'&&g.event.kind==='adrenaline')speed*=1.5;
 const mag=Math.min(1,d/(speed*.05));applyInput(g,p.id,dx/d*mag,dy/d*mag,run);
 }else{applyInput(g,p.id,0,0,false);if(p.state!=='disguised')ai.nextThink=Math.min(ai.nextThink,g.now+100)}
 }
}
