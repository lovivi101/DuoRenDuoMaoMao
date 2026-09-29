import type {IncomingMessage,ServerResponse} from 'node:http';
import {randomInt} from 'node:crypto';
import type {Store} from '../store/store.js';
import type {User} from '../types.js';
import {COLORS} from '../types.js';
import {hashPassword,safeUser,signToken,verifyPassword,verifyToken} from '../auth.js';
import {CONFIG} from '../game/config.js';
export class ApiError extends Error {constructor(public code:string,public status=400){super(code)}}
const need=(v:unknown,code='BAD_REQUEST')=>{if(!v)throw new ApiError(code)};
const str=(v:unknown)=>typeof v==='string'?v:'';
const phoneValid=(v:unknown)=>typeof v==='string'&&/^1[3-9]\d{9}$/.test(v);
export class Api {
 private sms=new Map<string,{code:string;sentAt:number;attempts:number;used:boolean}>();
 private ipBudget=new Map<string,{at:number;count:number}>();
 constructor(public store:Store,public secret:string,public status:(id:string)=>'online'|'in_game'|'offline',private clock=Date.now,private fetcher:typeof fetch=fetch){}
 auth(req:IncomingMessage){const token=str(req.headers.authorization).match(/^Bearer (.+)$/)?.[1],uid=token?verifyToken(token,this.secret,this.clock()):null;return uid?this.store.getUser(uid):undefined}
 async wechat(code:unknown){
 need(typeof code==='string'&&code.length>0&&code.length<512,'UNAUTHORIZED');
 if(process.env.WX_APPID&&process.env.WX_SECRET){
 const url=new URL('https://api.weixin.qq.com/sns/oauth2/access_token');
 url.search=new URLSearchParams({appid:process.env.WX_APPID,secret:process.env.WX_SECRET,code:str(code),grant_type:'authorization_code'}).toString();
 const response=await this.fetcher(url,{signal:AbortSignal.timeout(8000)});const data=await response.json() as {openid?:string;errcode?:number};
 need(response.ok&&typeof data.openid==='string'&&!data.errcode,'UNAUTHORIZED');return data.openid!;
 }
 need(str(code).startsWith('mock_'),'UNAUTHORIZED');return str(code);
 }
 consumeSms(phone:unknown,code:unknown){
 need(phoneValid(phone),'PHONE_INVALID');const r=this.sms.get(str(phone));
 need(r&&!r.used&&this.clock()-r.sentAt<CONFIG.smsTtlMs&&r.attempts<CONFIG.smsMaxAttempts,'SMS_CODE_WRONG');
 if(r!.code!==str(code)){r!.attempts++;throw new ApiError('SMS_CODE_WRONG')}r!.used=true;
 }
 private logged(user:User,isNew:boolean){return {ok:true,token:signToken(user.id,this.secret,86400,this.clock()),user:safeUser(user),isNew}}
 async route(method:string,path:string,b:Record<string,unknown>,user?:User):Promise<Record<string,unknown>>{
 const store=this.store;
 if(method==='GET'&&path==='/api/notice')return {ok:true,notices:[{title:'熄灯试玩',body:'旧宿舍楼开放，支持 AI 补位。'}],version:'0.1.0'};
 if(method==='GET'&&path==='/api/profile/random-name')return {ok:true,nickname:['小夜猫','灯下影','翻窗猫','宿舍长'][randomInt(4)]+randomInt(10,99)};
 if(method==='POST'&&path==='/api/auth/register'){
 const account=str(b.account),password=str(b.password);
 need(/^[A-Za-z0-9_]{4,20}$/.test(account),'ACCOUNT_INVALID');need(password.length>=6&&password.length<=32,'ACCOUNT_INVALID');need(!store.findAccount(account),'ACCOUNT_EXISTS');
 const credentials=await hashPassword(password);
 need(!store.findAccount(account),'ACCOUNT_EXISTS');return this.logged(store.create('account',account,credentials),true);
 }
 if(method==='POST'&&path==='/api/auth/password'){
 const u=store.findAccount(str(b.account));need(str(b.password).length<=32,'PASSWORD_WRONG');
 need(u?.salt&&u.passwordHash&&await verifyPassword(str(b.password),u.salt,u.passwordHash),'PASSWORD_WRONG');
 return this.logged(u!,false);
 }
 if(method==='POST'&&path==='/api/auth/sms/send'){
 need(phoneValid(b.phone),'PHONE_INVALID');const phone=str(b.phone),now=this.clock(),prev=this.sms.get(phone);
 need(!prev||now-prev.sentAt>=CONFIG.smsCooldownMs,'SMS_TOO_FREQUENT');
 const code=String(randomInt(100000,1000000)),entry={code,sentAt:now,attempts:0,used:false};this.sms.set(phone,entry);
 if(process.env.SMS_PROVIDER_URL){
 try{const result=await this.fetcher(process.env.SMS_PROVIDER_URL,{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+(process.env.SMS_PROVIDER_TOKEN||'')},body:JSON.stringify({phone,code,ttlSec:300}),signal:AbortSignal.timeout(8000)});need(result.ok,'SMS_SEND_FAILED')}catch(e){this.sms.delete(phone);throw e}
 }else console.log('[mock sms]',phone,code);
 for(const [key,v] of this.sms)if(now-v.sentAt>CONFIG.smsTtlMs)this.sms.delete(key);
 return {ok:true,cooldown:60,...(!process.env.SMS_PROVIDER_URL&&process.env.NODE_ENV!=='production'?{devCode:code}:{})};
 }
 if(method==='POST'&&path==='/api/auth/sms/login'){
 this.consumeSms(b.phone,b.code);let u=store.findPhone(str(b.phone));const isNew=!u;u??=store.create('phone',str(b.phone));return this.logged(u,isNew);
 }
 if(method==='POST'&&path==='/api/auth/wechat'){
 const openid=await this.wechat(b.code);let u=store.findWechat(openid);const isNew=!u;u??=store.create('wechat',openid);return this.logged(u,isNew);
 }
 if(method==='POST'&&path==='/api/auth/guest'){
 need(typeof b.deviceId==='string'&&b.deviceId.length>=4&&b.deviceId.length<=128,'BAD_REQUEST');
 let u=store.findDevice(str(b.deviceId));const isNew=!u;u??=store.create('guest',str(b.deviceId));return this.logged(u,isNew);
 }
 if(!user)throw new ApiError('UNAUTHORIZED',401);
 if(method==='GET'&&path==='/api/me')return {ok:true,user:safeUser(user)};
 if(method==='POST'&&path==='/api/profile'){
 const name=str(b.nickname).trim();need([...name].length>=2&&[...name].length<=12&&!/[\x00-\x1f]/.test(name),'NICKNAME_INVALID');need(COLORS.includes(b.color as typeof COLORS[number]),'COLOR_INVALID');
 user.nickname=name;user.color=b.color as User['color'];user.needsProfile=false;store.saveUser(user);return {ok:true,user:safeUser(user)};
 }
 if(method==='GET'&&path==='/api/friends')return {ok:true,friends:store.friends(user.id).map(u=>({user:safeUser(u),status:this.status(u.id)}))};
 if(method==='POST'&&path==='/api/friends/add'){
 const f=store.findShortId(str(b.shortId));need(f&&f.id!==user.id,'NOT_FOUND');store.addFriend(user.id,f!.id);return {ok:true,friend:{user:safeUser(f!),status:this.status(f!.id)}};
 }
 if(method==='POST'&&path==='/api/bind/phone'){
 this.consumeSms(b.phone,b.code);const existing=store.findPhone(str(b.phone));need(!existing||existing.id===user.id,'ACCOUNT_EXISTS');
 user.bindings.phone=str(b.phone);store.saveUser(user);return {ok:true,user:safeUser(user)};
 }
 if(method==='POST'&&path==='/api/bind/wechat'){
 const openid=await this.wechat(b.code),existing=store.findWechat(openid);need(!existing||existing.id===user.id,'ACCOUNT_EXISTS');
 user.bindings.wechat=true;user.wechatOpenid=openid;store.saveUser(user);return {ok:true,user:safeUser(user)};
 }
 throw new ApiError('NOT_FOUND',404);
 }
 async handle(req:IncomingMessage,res:ServerResponse){
 const send=(data:unknown,status=200)=>{res.writeHead(status,{'content-type':'application/json; charset=utf-8'});res.end(JSON.stringify(data))};
 try{
 const path=new URL(req.url||'/', 'http://localhost').pathname;
 if(path==='/health'){send({ok:true,serverNow:this.clock()});return}
 if(!path.startsWith('/api/'))throw new ApiError('NOT_FOUND',404);
 const ip=req.socket.remoteAddress||'local',now=this.clock();let budget=this.ipBudget.get(ip);
 if(!budget||now-budget.at>60000){budget={at:now,count:0};this.ipBudget.set(ip,budget)}
 if(++budget.count>240)throw new ApiError('RATE_LIMIT',429);
 for(const [key,b] of this.ipBudget)if(now-b.at>60000)this.ipBudget.delete(key);
 let bytes=0;const chunks:Buffer[]=[];
 for await(const chunk of req){bytes+=chunk.length;if(bytes>16384)throw new ApiError('PAYLOAD_TOO_LARGE',413);chunks.push(chunk)}
 let body:Record<string,unknown>={};
 if(bytes){try{body=JSON.parse(Buffer.concat(chunks).toString())}catch{throw new ApiError('BAD_JSON')}}
 need(body&&typeof body==='object'&&!Array.isArray(body));
 send(await this.route(req.method||'GET',path,body,this.auth(req)));
 }catch(e){const x=e instanceof ApiError?e:new ApiError('INTERNAL_ERROR',500);if(x.status===500)console.error(e instanceof Error?e.message:'server error');send({ok:false,code:x.code,msg:messages[x.code]||x.code},x.status)}
 }
}
const messages:Record<string,string>={PHONE_INVALID:'手机号无效',SMS_TOO_FREQUENT:'验证码发送过于频繁',SMS_CODE_WRONG:'验证码错误或已失效',ACCOUNT_EXISTS:'账号或绑定已存在',ACCOUNT_INVALID:'账号或密码格式无效',PASSWORD_WRONG:'账号或密码错误',NICKNAME_INVALID:'昵称需为 2–12 字',UNAUTHORIZED:'请重新登录',NOT_FOUND:'未找到',BAD_REQUEST:'请求参数无效'};
