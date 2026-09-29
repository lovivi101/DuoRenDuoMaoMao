import {describe,it,expect} from 'vitest';
import {CONFIG,devSeconds} from '../src/game/config.js';
import {createOldDorm,blockedTile,wireMap,zoneAt} from '../src/game/maps/old_dorm.js';
import {hasLineOfSight} from '../src/game/vision.js';
import {createGame,tickGame} from '../src/game/engine.js';
import {simulate} from '../src/sim.js';
import {Lobby} from '../src/lobby/lobby.js';

describe('T2c map contract',()=>{
 it('preserves legend 0..5, supplies all eight props and uneven regional density',()=>{
 const m=createOldDorm(),legend=wireMap(m).legend;
 expect(Object.values(legend).slice(0,6)).toEqual(['floor','wall_solid','wall_cracked','door','rubble','void']);
 expect(m.props.length).toBeGreaterThanOrEqual(40);
 expect([...new Set(m.props.map(p=>p.prop))].sort()).toEqual(['cardboard_box','chair','desk_lamp','food_tray','oil_drum','pillow','potted_plant','trash_can']);
 expect(new Set(m.props.map(p=>`${p.x},${p.y}`)).size).toBe(m.props.length);
 const counts=m.zones.map(z=>m.props.filter(p=>zoneAt(p,m)===z).length);
 expect(counts).toEqual([0,35,11,12,6]);
 });
 it('furniture blocks movement only; shelves block movement and DDA sight',()=>{
 const m=createOldDorm();m.tiles.fill(0);m.lockedDoors=[];
 m.tiles[10*m.w+10]=6;
 expect(blockedTile(10.5,10.5,m)).toBe(true);
 expect(hasLineOfSight(9.5,10.5,11.5,10.5,m)).toBe(true);
 m.tiles[10*m.w+10]=7;
 expect(blockedTile(10.5,10.5,m)).toBe(true);
 expect(hasLineOfSight(9.5,10.5,11.5,10.5,m)).toBe(false);
 });
 it('has traversable loops in all four wings, including two warehouse rings',()=>{
 const m=createOldDorm();
 const ring=(x1:number,y1:number,x2:number,y2:number)=>{
 for(let x=x1;x<=x2;x++)for(const y of [y1,y2])expect(blockedTile(x,y,m),`${x},${y}`).toBe(false);
 for(let y=y1;y<=y2;y++)for(const x of [x1,x2])expect(blockedTile(x,y,m),`${x},${y}`).toBe(false);
 };
 ring(1,2,3,5);ring(5,2,7,5); // bunks
 ring(42,16,45,23);ring(52,16,55,23); // long tables
 ring(4,29,10,31);ring(4,34,10,36); // shelves
 ring(8,15,11,18);ring(16,21,19,24); // bath stalls
 });
 it('safe room has exactly one locked exit and an unbreakable shell',()=>{
 const m=createOldDorm();let doors=0;
 for(let y=15;y<=20;y++)for(let x=2;x<=6;x++)if(x===2||x===6||y===15||y===20){
 const t=m.tiles[y*m.w+x];if(t===3){doors++;expect(m.lockedDoors).toContainEqual({x,y})}else expect(t).toBe(1);
 }
 expect(doors).toBe(1);
 });
});

describe('development timings and phase notifications',()=>{
 it('timings are opt-in, validated, and ignored in production',()=>{
 for(const name of ['DEV_HUNT_SEC','DEV_HIDE_SEC','DEV_ASSIGN_SEC','DEV_RESULT_SEC','DEV_VOTE_SEC']){
 expect(devSeconds(name,20,{})).toBe(20);
 expect(devSeconds(name,20,{[name]:'5'})).toBe(5);
 expect(devSeconds(name,20,{[name]:'5',NODE_ENV:'production'})).toBe(20);
 for(const value of ['0','-1','NaN','Infinity','3601'])expect(()=>devSeconds(name,20,{[name]:value})).toThrow();
 }
 expect(devSeconds('DEV_HUNT_SEC',undefined,{})).toBeUndefined();
 });
 it('configured overrides drive the engine phases and lobby vote deadline',()=>{
 const old={...CONFIG};
 try{
 Object.assign(CONFIG,{assignSec:.1,hideSec:.2,huntSec:1,resultSec:.15,voteSec:2});
 const players=Array.from({length:8},(_,i)=>({id:'p'+i,nickname:'P'+i,color:'blue' as const,isBot:false}));
 const g=createGame('timings',players,600,1,false,{now:1000});
 expect(g.durationSec).toBe(1);expect(g.phaseEndsAt).toBe(1100);
 tickGame(g,1100);expect(g.phase).toBe('hide');expect(g.phaseEndsAt).toBe(1300);
 tickGame(g,1300);expect(g.phase).toBe('final');expect(g.phaseEndsAt).toBe(2300);
 tickGame(g,2300);expect(g.phase).toBe('result');expect(g.phaseEndsAt).toBe(2450);
 tickGame(g,2450);expect(g.phase).toBe('waiting');
 const lobby=new Lobby(1,()=>1000),host={...players[0],ready:true,isHost:true,online:true};
 const room=lobby.create(host,{aiFill:true});lobby.beginVote(room);expect(room.voteEndsAt).toBe(3000);
 }finally{Object.assign(CONFIG,old)}
 });
 it('logs phase transitions once; same-phase notifications only accompany generator deadline changes',()=>{
 for(const seed of [1,42]){
 const logs:string[]=[];const g=simulate(seed,s=>logs.push(s));
 for(const phase of ['assign','hide','hunt','result'])expect(logs.filter(s=>s===`phase ${phase}`)).toHaveLength(1);
 // Whether a seed reaches the final 30s depends on AI outcomes; it must just never repeat.
 expect(logs.filter(s=>s==='phase final').length).toBeLessThanOrEqual(1);
 const updates=logs.filter(s=>s.startsWith('timer updated'));
 expect(updates.length).toBe(g.generators.filter(p=>p.fixed).length);
 expect(new Set(updates).size).toBe(updates.length);
 }
 });
});
