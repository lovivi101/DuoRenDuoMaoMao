import type {GameMap,Pos,Rect} from '../../types.js';

// Tile ids (see wireMap legend): 0 floor 1 wall 2 cracked 3 door 4 rubble 5 void 6 furniture 7 shelf 8 curtain 9 atrium.
export const T={floor:0,wall:1,cracked:2,door:3,rubble:4,void:5,furniture:6,shelf:7,curtain:8,atrium:9} as const;
export const center=(x:number,y:number):Pos=>({x:x+.5,y:y+.5});

// Small drawing kit for authoring maps cell by cell; every new map is a sequence of
// rooms, walls and doors on a W×H grid whose border is solid wall.
export class Grid {
 tiles:Uint8Array;
 constructor(public w:number,public h:number){
  this.tiles=new Uint8Array(w*h);
  this.hline(0,w-1,0);this.hline(0,w-1,h-1);this.vline(0,0,h-1);this.vline(w-1,0,h-1);
 }
 get(x:number,y:number){return x<0||y<0||x>=this.w||y>=this.h?T.wall:this.tiles[y*this.w+x]}
 set(x:number,y:number,t:number){if(x>=0&&y>=0&&x<this.w&&y<this.h)this.tiles[y*this.w+x]=t}
 fill(x:number,y:number,w:number,h:number,t:number){for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)this.set(xx,yy,t)}
 hline(x1:number,x2:number,y:number,t:number=T.wall){for(let x=x1;x<=x2;x++)this.set(x,y,t)}
 vline(x:number,y1:number,y2:number,t:number=T.wall){for(let y=y1;y<=y2;y++)this.set(x,y,t)}
 // Wall outline of a room whose outer corners are (x,y) and (x+w-1,y+h-1).
 box(x:number,y:number,w:number,h:number){this.hline(x,x+w-1,y);this.hline(x,x+w-1,y+h-1);this.vline(x,y,y+h-1);this.vline(x+w-1,y,y+h-1)}
 doors(...cells:[number,number][]){for(const [x,y] of cells)this.set(x,y,T.door)}
 // Deterministically crack ~ratio of the interior walls (design: breakable partitions
 // have visible cracks); `keep` protects load-bearing or scripted walls.
 crack(ratio=.4,keep:(x:number,y:number)=>boolean=()=>false){
  const interior:number[]=[];
  for(let y=1;y<this.h-1;y++)for(let x=1;x<this.w-1;x++)if(this.tiles[y*this.w+x]===T.wall&&!keep(x,y))interior.push(y*this.w+x);
  const target=Math.round(interior.length*ratio);
  for(let i=0;i<target;i++)this.tiles[interior[Math.floor(i*interior.length/target)]]=T.cracked;
 }
}

export interface MapSpec {
 id:string;theme:string;grid:Grid;zones:GameMap['zones'];hunterSpawn:Pos;cage:Pos;hiderSpawns:Pos[];generators:Pos[];itemSpots:Pos[];
 props:[number,number,string][];lockedDoors?:Pos[];furniture?:GameMap['furniture'];decor?:GameMap['decor'];portals?:GameMap['portals'];mechanics?:GameMap['mechanics'];
}
export function finish(spec:MapSpec):GameMap{
 const {grid}=spec;
 return {id:spec.id,theme:spec.theme,w:grid.w,h:grid.h,tileSize:32,tiles:grid.tiles,zones:spec.zones,hunterSpawn:spec.hunterSpawn,cage:spec.cage,
  hiderSpawns:spec.hiderSpawns,generators:spec.generators.map((p,id)=>({id,...p})),itemSpots:spec.itemSpots,
  props:spec.props.map(([x,y,prop])=>({...center(x,y),prop})),lockedDoors:spec.lockedDoors??[],
  furniture:spec.furniture??[],decor:spec.decor??[],portals:spec.portals??[],mechanics:spec.mechanics??{}};
}
// Two-way transit between cells a and b.
export function portalPair(id:string,kind:string,a:[number,number],b:[number,number],delaySec:number,cap:number):NonNullable<GameMap['portals']>{
 return [{id:id+'_a',kind,x:a[0],y:a[1],to:{x:b[0],y:b[1]},delaySec,cap},{id:id+'_b',kind,x:b[0],y:b[1],to:{x:a[0],y:a[1]},delaySec,cap}];
}
export const inRect=(p:Pos,r:Rect)=>p.x>=r.x&&p.y>=r.y&&p.x<r.x+r.w&&p.y<r.y+r.h;
