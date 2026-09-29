import {describe,it,expect} from 'vitest';
import {hashPassword,verifyPassword,signToken,verifyToken,safeUser} from '../src/auth.js';
import {Api} from '../src/http/api.js';
import {SqliteStore} from '../src/store/store.js';
const secret='test-only-secret-32-characters-long';
describe('auth and persistence',()=>{
 it('uses asynchronous scrypt with random salt and validates JWT expiry, tampering, segment count',async()=>{
 const a=await hashPassword('secret123'),b=await hashPassword('secret123');expect(a.salt).not.toBe(b.salt);
 expect(await verifyPassword('secret123',a.salt,a.hash)).toBe(true);expect(await verifyPassword('wrong',a.salt,a.hash)).toBe(false);
 const token=signToken('u_test',secret,60,100000);expect(verifyToken(token,secret,110000)).toBe('u_test');
 expect(verifyToken(token,secret,160000)).toBeNull();expect(verifyToken(token+'.x',secret,110000)).toBeNull();expect(verifyToken(token,secret+'x',110000)).toBeNull();
 });
 it('register/password/profile/guest and SMS cooldown, expiry, five failures, one-time consumption',async()=>{
 const store=new SqliteStore(':memory:');let now=100000;const api=new Api(store,secret,()=> 'offline',()=>now);
 try{
 const first=await api.route('POST','/api/auth/register',{account:'test_user',password:'secret123'});
 expect(first.isNew).toBe(true);const user=first.user as {id:string};
 expect((await api.route('POST','/api/auth/password',{account:'test_user',password:'secret123'})).isNew).toBe(false);
 await expect(api.route('POST','/api/auth/password',{account:'test_user',password:'wrong'})).rejects.toMatchObject({code:'PASSWORD_WRONG'});
 await expect(api.route('POST','/api/auth/register',{account:'test_user',password:'secret123'})).rejects.toMatchObject({code:'ACCOUNT_EXISTS'});
 const send=()=>api.route('POST','/api/auth/sms/send',{phone:'13800000000'});
 let sms=await send();await expect(send()).rejects.toMatchObject({code:'SMS_TOO_FREQUENT'});
 for(let i=0;i<5;i++)await expect(api.route('POST','/api/auth/sms/login',{phone:'13800000000',code:'bad'})).rejects.toMatchObject({code:'SMS_CODE_WRONG'});
 await expect(api.route('POST','/api/auth/sms/login',{phone:'13800000000',code:sms.devCode})).rejects.toMatchObject({code:'SMS_CODE_WRONG'});
 now+=60000;sms=await send();now+=300000;
 await expect(api.route('POST','/api/auth/sms/login',{phone:'13800000000',code:sms.devCode})).rejects.toMatchObject({code:'SMS_CODE_WRONG'});
 sms=await send();const login=await api.route('POST','/api/auth/sms/login',{phone:'13800000000',code:sms.devCode});
 expect(login.isNew).toBe(true);expect((login.user as {bindings:{phone:string}}).bindings.phone).toBe('138****0000');
 await expect(api.route('POST','/api/auth/sms/login',{phone:'13800000000',code:sms.devCode})).rejects.toThrow();
 const guest=await api.route('POST','/api/auth/guest',{deviceId:'device_123'});
 expect((await api.route('POST','/api/auth/guest',{deviceId:'device_123'})).isNew).toBe(false);
 expect((await api.route('POST','/api/auth/wechat',{code:'mock_test'})).isNew).toBe(true);
 await expect(api.route('POST','/api/auth/wechat',{code:'bad'})).rejects.toThrow();
 const full=store.getUser(user.id)!;expect(safeUser(full)).not.toHaveProperty('passwordHash');
 const updated=await api.route('POST','/api/profile',{nickname:'小灯猫',color:'pink'},full);expect((updated.user as {needsProfile:boolean}).needsProfile).toBe(false);
 store.reward('match',full.id,{exp:10,coins:5,rankDelta:1});store.reward('match',full.id,{exp:10,coins:5,rankDelta:1});
 expect(store.getUser(full.id)?.exp).toBe(10);
 }finally{store.close()}
 });
 it('bind phone requires OTP; friends are explicitly added',async()=>{
 const store=new SqliteStore(':memory:'),api=new Api(store,secret,()=> 'online');try{
 const a=store.create('guest','dev_a'),b=store.create('guest','dev_b');
 expect(store.friends(a.id)).toEqual([]);
 await expect(api.route('POST','/api/bind/phone',{phone:'13800000001',code:'fake'},a)).rejects.toThrow();
 const sent=await api.route('POST','/api/auth/sms/send',{phone:'13800000001'});
 await api.route('POST','/api/bind/phone',{phone:'13800000001',code:sent.devCode},a);
 expect(store.findPhone('13800000001')?.id).toBe(a.id);
 await api.route('POST','/api/friends/add',{shortId:b.shortId},a);expect(store.friends(a.id).map(x=>x.id)).toEqual([b.id]);
 }finally{store.close()}
 });
});
