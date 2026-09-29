import {simulate} from './sim.js';
import {CONFIG} from './game/config.js';

function arg(name:string,fallback:number){
 const i=process.argv.indexOf(name),value=i<0?fallback:Number(process.argv[i+1]);
 if(!Number.isSafeInteger(value)||value<1)throw Error(`${name} requires a positive integer`);
 return value;
}
const n=arg('--n',30),start=arg('--seed',1);
let wins=0,caught=0,fixedGames=0,fixedTotal=0,duration=0;
console.log(`Batch: n=${n}, seeds=${start}..${start+n-1}, players=8 (1 hunter / 7 hiders), hunt=${CONFIG.huntSec??600}s`);
for(let i=0;i<n;i++){
 const g=simulate(start+i),hiders=g.players.filter(p=>p.role==='hider');
 const captures=hiders.filter(p=>p.caught).length,fixed=g.generators.filter(p=>p.fixed).length;
 // Result deadline minus result screen gives the actual end of play.
 const seconds=(g.phaseEndsAt-CONFIG.resultSec*1000-g.startedAt)/1000;
 wins+=Number(g.winner==='hider');caught+=captures/hiders.length;
 fixedGames+=Number(fixed>0);fixedTotal+=fixed;duration+=seconds;
 console.log(`seed=${start+i} winner=${g.winner} caught=${captures}/${hiders.length} generators=${fixed} duration=${seconds.toFixed(2)}s`);
}
console.log(`藏者胜率: ${(wins/n*100).toFixed(2)}% (${wins}/${n})`);
console.log(`平均被抓比例: ${(caught/n*100).toFixed(2)}% (曾被抓的独立藏者，含获救者)`);
console.log(`至少修好 1 台发电机: ${fixedGames}/${n} (${(fixedGames/n*100).toFixed(2)}%); 总修好 ${fixedTotal} 台`);
console.log(`平均对局时长: ${(duration/n).toFixed(2)}s (分配+躲藏+追捕，不含结算)`);
