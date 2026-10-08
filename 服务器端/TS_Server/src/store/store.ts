import {mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
import {createRequire} from 'node:module';
import type {DatabaseSync as Database} from 'node:sqlite';
import {randomInt,randomUUID} from 'node:crypto';
import type {MatchRecord,User} from '../types.js';
import {applyMatch} from '../economy.js';
// Resolve the Node 22 builtin directly; Vite 5's builtin list predates node:sqlite.
const {DatabaseSync}=createRequire(import.meta.url)('node:sqlite') as typeof import('node:sqlite');
export interface Store {
 getUser(id:string):User|undefined;findAccount(account:string):User|undefined;findPhone(phone:string):User|undefined;findWechat(openid:string):User|undefined;findDevice(deviceId:string):User|undefined;findShortId(id:string):User|undefined;
 saveUser(u:User):void;create(kind:'account'|'phone'|'wechat'|'guest',value:string,credentials?:{salt:string;hash:string}):User;
 friends(id:string):User[];addFriend(id:string,friendId:string):void;reward(matchId:string,id:string,rewards:{exp:number;coins:number;rankDelta:number},record?:MatchRecord):void;records(id:string,limit?:number):MatchRecord[];close():void;
}
export class SqliteStore implements Store {
 private db:Database;
 constructor(file='data/xideng.db'){
 if(file!==':memory:')mkdirSync(dirname(file),{recursive:true});this.db=new DatabaseSync(file);
 this.db.exec(`PRAGMA journal_mode=WAL;PRAGMA busy_timeout=5000;
 CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,data TEXT NOT NULL);
 CREATE UNIQUE INDEX IF NOT EXISTS user_short ON users(json_extract(data,'$.shortId'));
 CREATE UNIQUE INDEX IF NOT EXISTS user_account ON users(json_extract(data,'$.bindings.account'));
 CREATE UNIQUE INDEX IF NOT EXISTS user_phone ON users(json_extract(data,'$.bindings.phone'));
 CREATE UNIQUE INDEX IF NOT EXISTS user_wechat ON users(json_extract(data,'$.wechatOpenid'));
 CREATE UNIQUE INDEX IF NOT EXISTS user_device ON users(json_extract(data,'$.deviceId'));
 CREATE TABLE IF NOT EXISTS friends(a TEXT,b TEXT,PRIMARY KEY(a,b));
 CREATE TABLE IF NOT EXISTS rewards(match_id TEXT,user_id TEXT,PRIMARY KEY(match_id,user_id));
 CREATE TABLE IF NOT EXISTS matches(user_id TEXT,match_id TEXT,at INTEGER,data TEXT NOT NULL,PRIMARY KEY(user_id,match_id));
 CREATE INDEX IF NOT EXISTS matches_recent ON matches(user_id,at DESC);`);
 }
 private find(field:string,value:string){const row=this.db.prepare('SELECT data FROM users WHERE '+field+'=?').get(value) as {data:string}|undefined;return row?JSON.parse(row.data) as User:undefined}
 getUser(id:string){return this.find('id',id)}
 findAccount(v:string){return this.find("json_extract(data,'$.bindings.account')",v)}
 findPhone(v:string){return this.find("json_extract(data,'$.bindings.phone')",v)}
 findWechat(v:string){return this.find("json_extract(data,'$.wechatOpenid')",v)}
 findDevice(v:string){return this.find("json_extract(data,'$.deviceId')",v)}
 findShortId(v:string){return this.find("json_extract(data,'$.shortId')",v)}
 saveUser(u:User){this.db.prepare('INSERT INTO users VALUES(?,?) ON CONFLICT(id) DO UPDATE SET data=excluded.data').run(u.id,JSON.stringify(u))}
 create(kind:'account'|'phone'|'wechat'|'guest',value:string,c?:{salt:string;hash:string}){
 let shortId:string;do{shortId=String(randomInt(10000000,100000000))}while(this.findShortId(shortId));
 const u:User={id:'u_'+randomUUID(),shortId,nickname:'小夜猫',color:'blue',level:1,exp:0,coins:0,gems:0,rankScore:1000,needsProfile:true,bindings:{wechat:false,phone:null,account:null}};
 if(kind==='account'){u.bindings.account=value;u.salt=c?.salt;u.passwordHash=c?.hash}
 else if(kind==='phone')u.bindings.phone=value;else if(kind==='wechat'){u.bindings.wechat=true;u.wechatOpenid=value}else u.deviceId=value;
 this.saveUser(u);return u;
 }
 friends(id:string){return (this.db.prepare('SELECT u.data FROM friends f JOIN users u ON u.id=f.b WHERE f.a=?').all(id) as {data:string}[]).map(r=>JSON.parse(r.data) as User)}
 addFriend(id:string,f:string){this.db.prepare('INSERT OR IGNORE INTO friends VALUES (?,?),(?,?)').run(id,f,f,id)}
 reward(matchId:string,id:string,r:{exp:number;coins:number;rankDelta:number},record?:MatchRecord){
 const u=this.getUser(id);if(!u)return;this.db.exec('BEGIN IMMEDIATE');
 try{const row=this.db.prepare('INSERT OR IGNORE INTO rewards VALUES(?,?)').run(matchId,id);
 if(row.changes){u.exp+=r.exp;u.coins+=r.coins;u.rankScore=Math.max(0,u.rankScore+r.rankDelta);u.level=1+Math.floor(u.exp/500);
 if(record){applyMatch(u,record,record.at);this.db.prepare('INSERT OR IGNORE INTO matches VALUES(?,?,?,?)').run(id,matchId,record.at,JSON.stringify(record))}
 this.saveUser(u)}this.db.exec('COMMIT')}
 catch(e){this.db.exec('ROLLBACK');throw e}
 }
 records(id:string,limit=20){return (this.db.prepare('SELECT data FROM matches WHERE user_id=? ORDER BY at DESC LIMIT ?').all(id,limit) as {data:string}[]).map(r=>JSON.parse(r.data) as MatchRecord)}
 close(){this.db.close()}
}
