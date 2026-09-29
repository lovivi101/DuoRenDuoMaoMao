import http from 'node:http';
import {CONFIG} from './game/config.js';
import type {Store} from './store/store.js';
import {SqliteStore} from './store/store.js';
import {Hub} from './ws/hub.js';
import {Api} from './http/api.js';
export function createServer(options:{store?:Store;secret?:string;clock?:()=>number;minPlayers?:number;autoTick?:boolean}={}){
 const secret=options.secret??CONFIG.jwtSecret;if(secret.length<32)throw Error('JWT_SECRET must contain at least 32 characters. Copy .env.example to .env and set your secret.');
 const store=options.store??new SqliteStore(process.env.DB_PATH||'data/xideng.db'),clock=options.clock??Date.now;
 let api:Api;const server=http.createServer((req,res)=>{void api.handle(req,res)});
 const hub=new Hub(server,store,secret,clock,options.minPlayers);api=new Api(store,secret,hub.status,clock);
 if(options.autoTick!==false)hub.start();
 return {server,hub,store,api,
 listen:(port=CONFIG.port,host=process.env.HOST||'0.0.0.0')=>new Promise<number>((resolve,reject)=>{server.once('error',reject);server.listen(port,host,()=>{server.off('error',reject);resolve((server.address() as import('node:net').AddressInfo).port)})}),
 close:async()=>{await hub.close();await new Promise<void>(resolve=>{if(server.listening)server.close(()=>resolve());else resolve()});store.close()}
 };
}
