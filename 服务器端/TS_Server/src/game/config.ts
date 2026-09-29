import 'dotenv/config';
// Overrides are opt-in; production ignores development timing switches.
export function devSeconds(name:string,fallback:number|undefined,env:NodeJS.ProcessEnv=process.env){
 if(env.NODE_ENV==='production'||env[name]===undefined||env[name]?.trim()==='')return fallback;
 const value=Number(env[name]);
 if(!Number.isFinite(value)||value<=0||value>3600)throw Error(`${name} must be > 0 and <= 3600 seconds`);
 return value;
}
// Production must set its own JWT_SECRET; the development fallback and the
// .env.example placeholder are public, so they are rejected there (empty => server refuses to start).
const PUBLIC_SECRETS=['dev-only-secret-change-me-32-characters-minimum','change-me-in-production-xideng-server-secret-32'];
export function jwtSecret(env:NodeJS.ProcessEnv=process.env){
 const s=env.JWT_SECRET?.trim()||'';
 if(env.NODE_ENV==='production')return PUBLIC_SECRETS.includes(s)?'':s;
 return s||PUBLIC_SECRETS[0];
}
// Development can lower the queue threshold to one player so a client can
// exercise the complete room/game protocol alone; production remains 8.
export const CONFIG={port:Number(process.env.PORT||8787),jwtSecret:jwtSecret(),matchMinPlayers:process.env.NODE_ENV==='production'?8:Math.max(1,Math.min(12,Number(process.env.MATCH_MIN_PLAYERS)||8)),tickHz:20,assignSec:devSeconds('DEV_ASSIGN_SEC',5)!,hideSec:devSeconds('DEV_HIDE_SEC',20)!,resultSec:devSeconds('DEV_RESULT_SEC',15)!,voteSec:devSeconds('DEV_VOTE_SEC',10)!,huntSec:devSeconds('DEV_HUNT_SEC',undefined),reconnectSec:30,smsCooldownMs:60000,smsTtlMs:300000,smsMaxAttempts:5};
// Bot behaviour knobs. Tuned with `npm run sim:batch` at the default 600s hunt;
// these shape AI decisions only and never change the design-doc rules below.
export const AI={
 hunterNoiseRange:100,hunterNoiseRangeWalk:18,
 suspectChance:.7,suspectMinMs:4000,suspectRandMs:4000,
 rescueChance:.6,rescueRange:30,
 repairChance:.95,
 disguiseMinMs:12000,disguiseRandMs:18000,
 disguisedPanicRange:1.6,disguisedPanicChance:.3,
 coverRange:4,lateHoldMul:3,
};
// Development-only JSON override, e.g. AI_TUNE='{"rescueChance":.8}', for batch tuning.
if(process.env.NODE_ENV!=='production'&&process.env.AI_TUNE)Object.assign(AI,JSON.parse(process.env.AI_TUNE));
// generatorReduction is a fraction of the chosen hunt length: 10% of the 600s
// default is the design doc's 60s, while 300/480s rooms scale proportionally so
// fixing all three generators never collapses a short game.
export const RULES={
 radius:.35,hiderWalk:3,hiderRun:5.5,hunterWalk:4,hunterRun:5,staminaMax:4,staminaRegen:.5,hiderVision:5,hunterVision:6,hunterMinVision:4,flashlightRange:6,flashlightAngle:Math.PI/3,slapRange:1.2,slapCooldown:.5,missStun:1.5,
 disguiseRange:2,undisguiseSec:.5,jitterSec:10,runRippleSec:.5,footprintSec:3,repairTimes:[25,15,10],generatorReduction:.1,interactRange:1.8,rescueSec:3,ghostChooseSec:10,ghostCooldown:30,reportCooldown:40,finalSec:30,heartbeatSec:2,eventInterval:60,warnSec:5,dropInterval:60,wallHits:3,wallComboSec:4,maxTemporaryWalls:6,
 smokeRadius:3,smokeSec:6,netRange:6,netSlow:.6,netSec:3,bellSec:3,hunterBoost:1.6,hunterBoostSec:4,hiderBoost:1.5,hiderBoostSec:5,boardSec:25,strongLightRange:8,strongLightSec:2,
 ripple:{run:3,door:5,box:5,repair:8,crash:8,wall:8,heartbeat:3,fake:3},
 points:{survive:100,minute:15,generator:40,rescue:60,item:20,catch:50,finalCatch:80,guardian:20,wraith:30,report:40,moleSurvive:120,accuse:80},
} as const;
