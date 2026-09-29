import type {GameState,GamePlayer,Pos,GameMessage} from '../types.js';
import {RULES} from './config.js';
export const active=(g:GameState)=>g.phase==='hunt'||g.phase==='final';
export const living=(p:GamePlayer)=>!p.caged&&!p.eliminated;
export const score=(p:GamePlayer,label:string,pts:number)=>{p.score[label]=(p.score[label]||0)+pts};
export const emit=(g:GameState,message:GameMessage)=>g.outbox.push(message);
export function ripple(g:GameState,p:Pos,kind:keyof typeof RULES.ripple,hunter=false,by?:string){g.ripples.push({x:p.x,y:p.y,r:RULES.ripple[kind],kind,until:g.now+1500,hunter,by})}
export function fx(g:GameState,p:Pos,kind:string,by?:string){emit(g,{t:'game.fx',kind,x:p.x,y:p.y,by})}
export function stun(g:GameState,p:GamePlayer,seconds:number){p.stunnedUntil=Math.max(p.stunnedUntil,g.now+seconds*1000);p.state='stunned';p.interact=null}
export function reveal(g:GameState,p:GamePlayer,seconds:number){p.revealedUntil=Math.max(p.revealedUntil,g.now+seconds*1000);if(p.state==='disguised'){p.state='normal';p.prop=null}}
