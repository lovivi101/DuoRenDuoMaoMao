export const COLORS=['red','orange','yellow','green','cyan','blue','purple','pink'] as const;
export type Color=typeof COLORS[number];
export type Role='hider'|'hunter'|'mole';
export interface Pos {x:number;y:number}
export interface User {id:string;shortId:string;nickname:string;color:Color;level:number;exp:number;coins:number;gems:number;rankScore:number;needsProfile:boolean;bindings:{wechat:boolean;phone:string|null;account:string|null};passwordHash?:string;salt?:string;wechatOpenid?:string;deviceId?:string}
export interface Settings {map:'old_dorm'|'random';durationSec:300|480|600;hunterCount:'auto'|1|2;moleEnabled:boolean;voiceEnabled:boolean;aiFill:boolean;maxPlayers:number}
export interface Player {id:string;nickname:string;color:Color;ready:boolean;isBot:boolean;isHost:boolean;online:boolean}
export interface Input {seq:number;mx:number;my:number;run:boolean;at:number}
export interface Mark extends Pos {kind:string;until:number;audience:'hider'|'hunter'|'all';targetId?:string;by?:string}
export interface Ripple extends Pos {r:number;kind:string;until:number;hunter:boolean;by?:string;credited?:boolean}
export interface Footprint extends Pos {dir:number;until:number;hunter:boolean}
export interface Generator extends Pos {id:number;progress:number;fixed:boolean;participants:Set<string>;lastRipple:number}
export interface Drop extends Pos {id:string;item:string;stage:'warn'|'landed'|'taken';at:number}
export interface GamePlayer extends Player,Pos {
 role:Role;dir:number;state:'normal'|'disguised'|'ghost'|'caged'|'stunned';stamina:number;items:(string|null)[];prop:string|null;caged:boolean;caught:boolean;rescued:boolean;
 ghostSide:'guardian'|'wraith'|null;chooseUntil:number;ghostReadyAt:number;reportReadyAt:number;
 input:Input;running:boolean;flashlight:boolean;stunnedUntil:number;transitionUntil:number;lastRunRipple:number;lastJitter:number;lastSlap:number;disconnectedAt:number|null;expired:boolean;
 interact:{kind:'repair'|'rescue'|'accuse';target:string;value:number}|null;
 slowUntil:number;boostUntil:number;revealedUntil:number;lastItemAt:number;
 score:Record<string,number>;survival:number;captures:number;accused:boolean;eliminated:boolean;
 ai?:{path:Pos[];goal:Pos|null;nextThink:number;mode:string;until:number;suspectAt:number;patrolRun?:boolean};
}
export interface GameMap {id:string;w:number;h:number;tileSize:number;tiles:Uint8Array;zones:{name:string;x:number;y:number;w:number;h:number;floor:string}[];hunterSpawn:Pos;cage:Pos;hiderSpawns:Pos[];generators:(Pos&{id:number})[];itemSpots:Pos[];props:(Pos&{prop:string})[];lockedDoors:Pos[];furniture:{x:number;y:number;w:number;h:number;kind:string}[];decor:{x:number;y:number;kind:string}[]}
export interface GameMessage {t:string;[key:string]:unknown}
export interface GameState {
 id:string;roomCode:string;mapId:string;map:GameMap;phase:'assign'|'hide'|'hunt'|'final'|'result'|'waiting';
 now:number;phaseEndsAt:number;startedAt:number;huntStartedAt:number;durationSec:number;tick:number;players:GamePlayer[];generators:Generator[];ripples:Ripple[];footprints:Footprint[];marks:Mark[];drops:Drop[];
 eventCounts:Record<string,number>;nextEventAt:number;nextDropAt:number;event:{kind:string;stage:'warn'|'start';at:number;until:number}|null;
 walls:Map<number,{hits:number;last:number;by:string;until?:number;original?:number}>;
 hazards:{kind:'smoke'|'banana'|'bell_trap';x:number;y:number;until:number;by:string;hit:Set<string>}[];
 outbox:GameMessage[];winner?:'hider'|'hunter';voided:boolean;result?:Result;random:()=>number;
}
export interface Result {winner:'hider'|'hunter';players:{id:string;nickname:string;color:Color;role:Role;score:number;breakdown:{label:string;pts:number}[];caught:boolean}[];mvp:{hider:string|null;hunter:string|null};voided?:boolean}
export interface Room {code:string;hostId:string;settings:Settings;phase:'waiting'|'voting'|'playing'|'result';players:Player[];createdAt:number;game?:GameState;resultSent?:boolean;lastHunters:string[];votes:Map<string,string>;voteEndsAt:number}
