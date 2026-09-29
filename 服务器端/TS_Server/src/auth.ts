import {randomBytes,scrypt,timingSafeEqual,createHmac} from 'node:crypto';
import {promisify} from 'node:util';
import type {User} from './types.js';
const derive=promisify(scrypt);
export async function hashPassword(password:string,salt=randomBytes(16).toString('hex')){return {salt,hash:((await derive(password,salt,32)) as Buffer).toString('hex')}}
export async function verifyPassword(password:string,salt:string,hash:string){try{const actual=await hashPassword(password,salt);return timingSafeEqual(Buffer.from(actual.hash,'hex'),Buffer.from(hash,'hex'))}catch{return false}}
export function signToken(userId:string,secret:string,ttlSec=86400,now=Date.now()){
 const h=Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url');
 const p=Buffer.from(JSON.stringify({sub:userId,iat:Math.floor(now/1000),exp:Math.floor(now/1000)+ttlSec})).toString('base64url');
 return h+'.'+p+'.'+createHmac('sha256',secret).update(h+'.'+p).digest('base64url');
}
export function verifyToken(token:string,secret:string,now=Date.now()):string|null{try{
 const parts=token.split('.');if(parts.length!==3)return null;const [h,p,s]=parts;
 const head=JSON.parse(Buffer.from(h,'base64url').toString());if(head.alg!=='HS256'||head.typ!=='JWT')return null;
 const expected=createHmac('sha256',secret).update(h+'.'+p).digest('base64url');
 if(!timingSafeEqual(Buffer.from(s),Buffer.from(expected)))return null;
 const x=JSON.parse(Buffer.from(p,'base64url').toString());
 return typeof x.sub==='string'&&Number.isFinite(x.exp)&&x.exp>now/1000?x.sub:null;
}catch{return null}}
export function safeUser(u:User){return {id:u.id,shortId:u.shortId,nickname:u.nickname,color:u.color,level:u.level,exp:u.exp,coins:u.coins,gems:u.gems,rankScore:u.rankScore,needsProfile:u.needsProfile,bindings:{...u.bindings,phone:u.bindings.phone?u.bindings.phone.slice(0,3)+'****'+u.bindings.phone.slice(-4):null}}}
