import {describe,it,expect} from 'vitest';
import {Lobby,validateSettings} from '../src/lobby/lobby.js';
const p=(id:string)=>({id,nickname:id,color:'blue' as const,ready:false,isBot:false,isHost:false,online:true});
describe('lobby',()=>{
 it('six digit codes, membership, host handoff, ready and settings validation',()=>{
 const l=new Lobby(),r=l.create(p('a'));expect(r.code).toMatch(/^\d{6}$/);expect(()=>l.join('000000',p('b'))).toThrow('NOT_FOUND');
 l.join(r.code,p('b'));expect(()=>l.create(p('b'))).toThrow('ALREADY_IN_ROOM');expect(()=>l.beginVote(r)).toThrow('NOT_READY');
 l.leave(r.code,'a');expect(r.hostId).toBe('b');l.beginVote(r);expect(r.players).toHaveLength(8);expect(r.phase).toBe('voting');
 l.start(r);expect(r.game?.players).toHaveLength(8);expect(()=>validateSettings({maxPlayers:20})).toThrow();
 });
 it('FIFO match starts at eight, cancel works, AI fill forbidden until 60 sec and consumes queue',()=>{
 let now=100;const l=new Lobby(8,()=>now);
 for(let i=0;i<7;i++)expect(l.matchStart(p('p'+i))).toBeNull();
 const r=l.matchStart(p('p7'))!;expect(r.players.map(p=>p.id)).toEqual(Array.from({length:8},(_,i)=>'p'+i));expect(l.queue).toHaveLength(0);
 l.matchStart(p('q1'));l.matchStart(p('q2'));l.matchCancel('q2');expect(()=>l.aiFill('q1')).toThrow('AI_FILL_TOO_EARLY');
 now+=60000;expect(l.matchStatus('q1').canAiFill).toBe(true);const filled=l.aiFill('q1');expect(filled.players.filter(p=>p.isBot)).toHaveLength(7);expect(l.queue).toHaveLength(0);
 });
});
