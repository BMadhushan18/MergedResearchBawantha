import React, {
  useMemo, useState, useCallback, useRef, memo, useEffect,
  createContext, useContext, Suspense,
} from "react";
import * as THREE from "three";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Grid, Edges, Text } from "@react-three/drei";

// ═══════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════
const FT = 0.3048;
const SQFT = 0.092903;
const WT_M = 0.115;
const WT_FT = WT_M / FT;

// ═══════════════════════════════════════════════════════════════════════════
// DATA PRESETS
// ═══════════════════════════════════════════════════════════════════════════
const BRICK_P = {
  clay:        { label:"Clay Brick",    l:215,  w:102.5, h:65,  waste:5 },
  cementBlock: { label:"Cement Block",  l:390,  w:190,   h:140, waste:5 },
  custom:      { label:"Custom Unit",   l:215,  w:102.5, h:65,  waste:5 },
};
const PLASTER_P = {
  normal:  { label:"Normal Plaster",  mm:12, ratio:"1:5", waste:8  },
  thick:   { label:"Thick Plaster",   mm:15, ratio:"1:5", waste:8  },
  premium: { label:"Premium Finish",  mm:20, ratio:"1:4", waste:10 },
};
const PAINT_P = {
  primer:   { label:"Primer",            cov:9,  coats:1, waste:5  },
  emulsion: { label:"Interior Emulsion", cov:10, coats:2, waste:8  },
  weather:  { label:"Weather Shield",    cov:8,  coats:2, waste:10 },
};
const PUTTY_P = {
  standard: { label:"Standard Putty", kpc:0.8, coats:1, waste:5 },
  smooth:   { label:"Smooth Finish",  kpc:0.8, coats:2, waste:8 },
};
const TILE_P = {
  small300:  { label:"300×300 mm",  w:300,   h:300   },
  medium600: { label:"600×600 mm",  w:600,   h:600   },
  large800:  { label:"800×800 mm",  w:800,   h:800   },
  ft1:       { label:"1×1 ft",      w:304.8, h:304.8 },
  ft2:       { label:"2×2 ft",      w:609.6, h:609.6 },
};
const TILE_COL = {
  cream:  { label:"Cream",  c1:"#ede9e0", c2:"#e0dbd0" },
  white:  { label:"White",  c1:"#f5f5f3", c2:"#eaeae8" },
  grey:   { label:"Grey",   c1:"#c5c0ba", c2:"#b8b3ad" },
  marble: { label:"Marble", c1:"#eee8df", c2:"#ddd4c6" },
  dark:   { label:"Dark",   c1:"#545048", c2:"#48443f" },
};
const WALL_SURF = {
  plaster: { label:"Plaster (default)" },
  brick:   { label:"Face Brick" },
  paint:   { label:"Painted" },
  stone:   { label:"Stone Cladding" },
};
const WALL_COLORS = {
  white:   { label:"White",       hex:"#f5f0e8" },
  cream:   { label:"Cream",       hex:"#f0e8d5" },
  grey:    { label:"Light Grey",  hex:"#d8d4cc" },
  blue:    { label:"Soft Blue",   hex:"#d0dde8" },
  green:   { label:"Sage Green",  hex:"#ccd8c0" },
};

const OPENINGS = {
  doors: {
    D1: { widthFt:4.5,  heightFt:9,   description:"Timber Paneled Door" },
    D2: { widthFt:3,    heightFt:9,   description:"Timber Paneled Door" },
    D3: { widthFt:2.75, heightFt:7.5, description:"Aluminium Door" },
    D4: { widthFt:2.5,  heightFt:6.5, description:"Aluminium Door" },
  },
  windows: {
    FW:  { widthFt:13.5, heightFt:9, description:"Timber Glazed French Window" },
    FW1: { widthFt:12,   heightFt:9, description:"Timber Glazed French Window" },
    FW2: { widthFt:9.5,  heightFt:9, description:"Timber Glazed Door & Window" },
    FW3: { widthFt:10,   heightFt:9, description:"Timber Glazed Door & Window" },
    FW4: { widthFt:6,    heightFt:9, description:"Timber Glazed Door & Window" },
    W5:  { widthFt:7,    heightFt:6, description:"Timber Glazed Window" },
    W6:  { widthFt:6.25, heightFt:6, description:"Timber Glazed Window" },
    W7:  { widthFt:3,    heightFt:9, description:"Timber Glazed Window" },
    W8:  { widthFt:6,    heightFt:9, description:"Timber Glazed Window" },
    FL:  { widthFt:1.5,  heightFt:4, description:"Timber Glazed Fanlight" },
  },
};

// ═══════════════════════════════════════════════════════════════════════════
// RAW FLOOR DATA  — corrected from plan drawings
// wallPos: 0.0-1.0 = fraction along wall from north/west end → overrides auto-spacing
// ═══════════════════════════════════════════════════════════════════════════
const RAW_FLOORS = [
  {
    id:"groundFloor", label:"Ground Floor", heightFt:11,
    layoutRows:[
      ["A_LivingDining","D_KitchenPantry","OpenToSky_Ground"],
      ["Passage_Left","Toilet_GroundLeft","Laundry","Toilet_GroundCenter"],
      ["Passage_Right","C_Bedroom","B_Bedroom"],
    ],
    components:[
      {
        // West facade = 29'-6" (main entrance facade with 3 openings)
        // From north→south: FW (13.5ft) | D1 (4.5ft) | FW3 (10ft) = 28ft of 29.5ft
        id:"A_LivingDining", label:"A", name:"Living & Dining",
        widthFt:25, depthFt:29.5,
        doors:[
          { type:"D1", quantity:1,
            location:"West wall — center main entrance",
            wallPos:0.53 },  // center: (13.5+2.25)/29.5
        ],
        windows:[
          { type:"FW",  quantity:1,
            location:"West wall — north section (large French window, left of door)",
            wallPos:0.23 },  // 13.5/2 / 29.5
          { type:"FW3", quantity:1,
            location:"West wall — south section (right of door)",
            wallPos:0.78 },  // (13.5+4.5+5)/29.5
          { type:"FW1", quantity:1,
            location:"South wall — front facing French window" },
          { type:"W7",  quantity:1,
            location:"South wall — beside FW1, east portion" },
        ],
      },
      { id:"D_KitchenPantry", label:"D", name:"Kitchen & Pantry",
        widthFt:4, depthFt:13.5,
        windows:[
          {type:"W5",quantity:2,location:"East wall — facing Open-to-Sky courtyard"},
          {type:"FL",quantity:1,location:"North wall upper — ventilation fanlight"},
        ]},
      { id:"Passage_Left", name:"Passage (left block)",
        widthFt:3.917, depthFt:5.5,
        doors:[{type:"D4",quantity:1,location:"South wall — entry from passage"}]},
      { id:"Toilet_GroundLeft", name:"Toilet (ground left)",
        widthFt:5.5, depthFt:4.167,
        doors:[{type:"D4",quantity:1,location:"East wall — entry from passage"}],
        windows:[{type:"FL",quantity:1,location:"South wall — ventilation"}]},
      { id:"Laundry", name:"Laundry",
        widthFt:4.167, depthFt:2.583,    // 2'-7" from plan
        windows:[{type:"FL",quantity:1,location:"South wall — ventilation"}]},
      { id:"OpenToSky_Ground", name:"Open To Sky (courtyard)",
        widthFt:9, depthFt:9, openToSky:true },
      { id:"Toilet_GroundCenter", name:"Toilet (ground center)",
        widthFt:9.5, depthFt:4.833,
        doors:[{type:"D4",quantity:1,location:"North wall — entry from passage"}],
        windows:[{type:"FL",quantity:1,location:"Upper south wall — ventilation"}]},
      { id:"Passage_Right", name:"Passage (right / main corridor)",
        widthFt:4.167, depthFt:9.5 },
      { id:"C_Bedroom", label:"C", name:"Bedroom C",
        widthFt:13.083, depthFt:11.25,  // 13'-1" × 11'-3"
        doors:[{type:"D3",quantity:1,location:"North wall — entry from passage"}],
        windows:[
          {type:"FW4",quantity:1,location:"South wall — west bay",wallPos:0.28},
          {type:"FW4",quantity:1,location:"South wall — east bay",wallPos:0.72},
        ]},
      { id:"B_Bedroom", label:"B", name:"Bedroom B",
        widthFt:13, depthFt:11.25,      // 13'-0" span from north wall dimension
        doors:[
          {type:"D3",quantity:1,location:"North wall — entry from passage"},
          {type:"D2",quantity:1,location:"East wall — exit to right balcony/exterior"},
        ],
        windows:[
          {type:"FW4",quantity:1,location:"South wall — west bay",wallPos:0.3},
          {type:"FW4",quantity:1,location:"South wall — east bay",wallPos:0.7},
          {type:"FW4",quantity:1,location:"East wall — side window"},
        ]},
    ],
  },
  {
    id:"upperFloor", label:"Upper Floor", heightFt:11,
    layoutRows:[
      ["F_MasterBedroom","Bathroom_Upper","E_Lobby"],
      ["G_Bedroom","OpenToSky_Upper","H_Bedroom"],
      ["Toilet_UpperLeft","Passage_Upper","I_Pantry","Toilet_UpperRight"],
      ["Balcony_Front","Balcony_Right"],
    ],
    components:[
      { id:"E_Lobby", label:"E", name:"Lobby",
        widthFt:8.5, depthFt:21.458,    // 8'-6" wide
        doors:[
          {type:"D3",quantity:1,location:"South wall — stair entry from ground floor"},
          {type:"D3",quantity:1,location:"East wall — passage to bedroom G area"},
        ]},
      { id:"F_MasterBedroom", label:"F", name:"Master Bedroom",
        widthFt:21.667, depthFt:16.125, // 21'-8" × 16'-1½"
        doors:[
          {type:"D3",quantity:1,location:"East wall — connecting to Lobby E"},
          {type:"D2",quantity:1,location:"West wall — access to left balcony"},
        ],
        windows:[
          {type:"FW2",quantity:1,location:"West wall — large glazed door & window to balcony"},
        ]},
      { id:"Bathroom_Upper", name:"Bathroom",
        widthFt:7.417, depthFt:7.417,   // 7'-5" × 7'-5" approx square
        doors:[{type:"D4",quantity:1,location:"South wall — entry from Master Bedroom"}],
        windows:[{type:"FL",quantity:1,location:"North wall upper — ventilation fanlight"}]},
      { id:"G_Bedroom", label:"G", name:"Bedroom G",
        widthFt:14, depthFt:15.833,     // 14'-0" (from plan dimension) × 15'-10"
        doors:[{type:"D3",quantity:1,location:"West wall — entry from Lobby E"}],
        windows:[{type:"W5",quantity:1,location:"East wall — facing Open-to-Sky void"}]},
      { id:"OpenToSky_Upper", name:"Open To Sky (upper void)",
        widthFt:9, depthFt:9, openToSky:true,
        windows:[{type:"W6",quantity:1,location:"East wall — bordering Bedroom H"}]},
      { id:"Toilet_UpperLeft", name:"Toilet (upper left)",
        widthFt:9.25, depthFt:4.833, heightFt:7.5,  // 9'-3" × 4'-10" at 7'-6" clear height
        doors:[{type:"D4",quantity:1,location:"North wall — entry from passage"}],
        windows:[{type:"FL",quantity:1,location:"Upper south wall — ventilation"}]},
      { id:"Toilet_UpperRight", name:"Toilet (upper right)",
        widthFt:5, depthFt:7.5,         // 5'-0" × 7'-6"
        doors:[{type:"D4",quantity:1,location:"South wall — entry from passage"}],
        windows:[{type:"FL",quantity:1,location:"North wall upper — ventilation"}]},
      { id:"H_Bedroom", label:"H", name:"Bedroom H",
        widthFt:11.25, depthFt:11.375,  // 11'-3" × 11'-4½"
        doors:[{type:"D3",quantity:1,location:"West wall — entry from passage"}],
        windows:[{type:"W6",quantity:1,location:"West wall — facing Open-to-Sky void"}]},
      { id:"I_Pantry", label:"I", name:"Pantry",
        widthFt:15.75, depthFt:13.583,  // 15'-9" × 13'-7"
        doors:[{type:"D3",quantity:1,location:"West wall — entry from passage"}],
        windows:[{type:"FW4",quantity:1,location:"North wall — window opening"}]},
      { id:"Passage_Upper", name:"Passage (upper corridor)",
        widthFt:4.167, depthFt:24, estimated:true },  // 4'-2" wide; full building length estimated
      { id:"Balcony_Front", name:"Balcony (front / south)",
        widthFt:40.5, depthFt:3,        // 3'-0" deep; ~40.5ft wide (full south facade)
        windows:[
          {type:"FW1",quantity:1,location:"North wall — opening from Lobby / Master Bedroom",wallPos:0.25},
          {type:"W7", quantity:1,location:"North wall — Lobby area window",wallPos:0.42},
          {type:"W8", quantity:1,location:"North wall — passage window east 1",wallPos:0.60},
          {type:"W8", quantity:1,location:"North wall — passage window east 2",wallPos:0.75},
          {type:"W8", quantity:1,location:"North wall — passage window east 3",wallPos:0.90},
        ]},
      { id:"Balcony_Right", name:"Balcony (right / east)",
        widthFt:4, depthFt:13.583,      // 4'-0" × 13'-7"
        doors:[{type:"D2",quantity:1,location:"West wall — access from Pantry / stair block"}],
        windows:[{type:"FW4",quantity:1,location:"West wall — window opening to interior"}]},
    ],
  },
  {
    id:"roofTop", label:"Roof Top", heightFt:7,
    layoutRows:[["RoofTerrace","OpenToSky_Roof"]],
    components:[
      { id:"RoofTerrace", name:"Roof Terrace",
        widthFt:21.833, depthFt:15.708,  // 21'-10" (9'+12'-10") × 15'-8½"
        doors:[{type:"D2",quantity:1,location:"East wall — stair entry to roof terrace"}],
        windows:[{type:"FW4",quantity:1,location:"East wall — adjacent to stair block"}]},
      { id:"OpenToSky_Roof", name:"Open To Sky (roof void)",
        widthFt:9, depthFt:9, openToSky:true },
    ],
  },
];

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const sn = (v, fb=0) => { const n=Number(v); return isFinite(n)?n:fb; };
const clamp = (v,a,b) => Math.min(Math.max(sn(v,a),a),b);
const fmt = (v,d=2) => { const n=sn(v); return isFinite(n)?n.toLocaleString(undefined,{minimumFractionDigits:d,maximumFractionDigits:d}):"—"; };
const locSide = s => {
  const t=(s||"").toLowerCase();
  if(t.includes("north")||t.includes("top")||t.includes("upper")) return "north";
  if(t.includes("south")||t.includes("bottom")||t.includes("front")) return "south";
  if(t.includes("east")||t.includes("right")) return "east";
  return "west";
};

// ═══════════════════════════════════════════════════════════════════════════
// TEXTURE FACTORY  (canvas-based, deterministic, cached)
// ═══════════════════════════════════════════════════════════════════════════
const _TC = {};
const tc = (key, fn) => { if(!_TC[key]) _TC[key]=fn(); return _TC[key]; };

function brickTex(type="clay") {
  return tc(`brick_${type}`, () => {
    const W=256,H=128,cv=document.createElement("canvas");
    cv.width=W; cv.height=H;
    const c=cv.getContext("2d");
    const cfg = {
      clay:        { m:"#c2af96", cols:["#bb4018","#b23910","#c4481c","#ad3810","#c04215"] },
      cementBlock: { m:"#9aa3aa", cols:["#8c979e","#929ba2","#87929a","#8e9aa0","#939fa6"] },
      custom:      { m:"#b8a280", cols:["#c57838","#cf7f3e","#c0722f","#ca7a35","#c87233"] },
      stone:       { m:"#aaa59a", cols:["#9c9890","#a8a49c","#9a9690","#b0aca4","#a4a098"] },
    };
    const {m,cols} = cfg[type]||cfg.clay;
    c.fillStyle=m; c.fillRect(0,0,W,H);
    const bW=56,bH=24,g=5;
    for(let row=0;row*(bH+g)<H+bH;row++){
      const off=row%2?(bW+g)/2:0;
      for(let col=-1;col*(bW+g)-off<W+bW;col++){
        const x=Math.floor(col*(bW+g)-off)+g;
        const y=Math.floor(row*(bH+g))+g;
        c.fillStyle=cols[(row*7+Math.abs(col)*3)%cols.length];
        c.fillRect(x,y,bW,bH);
        c.fillStyle="rgba(255,255,255,0.07)"; c.fillRect(x,y,bW,4);
        c.fillStyle="rgba(0,0,0,0.14)"; c.fillRect(x,y+bH-4,bW,4);
        c.fillStyle="rgba(0,0,0,0.06)"; c.fillRect(x+bW-3,y,3,bH);
      }
    }
    const t=new THREE.CanvasTexture(cv);
    t.wrapS=t.wrapT=THREE.RepeatWrapping; return t;
  });
}

function tileTex(colorKey="cream") {
  return tc(`tile_${colorKey}`, () => {
    const S=256,cv=document.createElement("canvas");
    cv.width=S; cv.height=S;
    const c=cv.getContext("2d");
    const {c1,c2}=TILE_COL[colorKey]||TILE_COL.cream;
    c.fillStyle=c1; c.fillRect(0,0,S,S);
    // subtle diagonal sheen
    const g=c.createLinearGradient(0,0,S,S);
    g.addColorStop(0,"rgba(255,255,255,0.12)");
    g.addColorStop(0.5,c2);
    g.addColorStop(1,"rgba(255,255,255,0.08)");
    c.fillStyle=g; c.fillRect(0,0,S,S);
    // grout border
    c.strokeStyle="#908880"; c.lineWidth=7; c.strokeRect(0,0,S,S);
    // inner highlight
    c.strokeStyle="rgba(255,255,255,0.35)"; c.lineWidth=1;
    c.strokeRect(8,8,S-16,S-16);
    const t=new THREE.CanvasTexture(cv);
    t.wrapS=t.wrapT=THREE.RepeatWrapping; return t;
  });
}

function plasterTex(colorHex="#f4efe6") {
  return tc(`plaster_${colorHex}`, () => {
    const S=256,cv=document.createElement("canvas");
    cv.width=S; cv.height=S;
    const c=cv.getContext("2d");
    c.fillStyle=colorHex; c.fillRect(0,0,S,S);
    const img=c.getImageData(0,0,S,S);
    for(let i=0;i<img.data.length;i+=4){
      const n=(((i/4)%173)*((i/4)%113))%15-7;
      img.data[i]+=n; img.data[i+1]+=n; img.data[i+2]+=n;
    }
    c.putImageData(img,0,0);
    const t=new THREE.CanvasTexture(cv);
    t.wrapS=t.wrapT=THREE.RepeatWrapping; return t;
  });
}

function woodTex() {
  return tc("wood", () => {
    const W=128,H=256,cv=document.createElement("canvas");
    cv.width=W; cv.height=H;
    const c=cv.getContext("2d");
    c.fillStyle="#7a5230"; c.fillRect(0,0,W,H);
    for(let i=0;i<32;i++){
      c.strokeStyle=`rgba(0,0,0,${0.04+(i%3)*0.03})`;
      c.lineWidth=1+(i%2);
      c.beginPath(); c.moveTo(i*4,0); c.lineTo(i*4+3,H); c.stroke();
    }
    c.fillStyle="rgba(255,200,120,0.08)"; c.fillRect(0,0,W,H);
    const t=new THREE.CanvasTexture(cv);
    t.wrapS=t.wrapT=THREE.RepeatWrapping; return t;
  });
}

function alumTex() {
  return tc("alum", () => {
    const S=64,cv=document.createElement("canvas");
    cv.width=S; cv.height=S;
    const c=cv.getContext("2d");
    const g=c.createLinearGradient(0,0,S,0);
    g.addColorStop(0,"#c8cdd0"); g.addColorStop(0.5,"#e0e4e6"); g.addColorStop(1,"#b8bdc0");
    c.fillStyle=g; c.fillRect(0,0,S,S);
    const t=new THREE.CanvasTexture(cv);
    t.wrapS=t.wrapT=THREE.RepeatWrapping; return t;
  });
}

// Cloned tile tex with correct repeat
function tiledFloorTex(colorKey, wFt, dFt, tilePreset) {
  const base=tileTex(colorKey);
  const clone=base.clone();
  clone.needsUpdate=true;
  const tSizeM=(tilePreset.w/1000);
  clone.repeat.set(
    Math.max(1,(wFt*FT)/tSizeM),
    Math.max(1,(dFt*FT)/tSizeM)
  );
  return clone;
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA ENHANCEMENT
// ═══════════════════════════════════════════════════════════════════════════
function normalizeOpenings(comp,floorId,floorLabel) {
  const items=[];
  const add=(entries,cat)=>{
    const sched=cat==="door"?OPENINGS.doors:OPENINGS.windows;
    (entries||[]).forEach(e=>{
      const src=sched[e.type]||{};
      const qty=Math.max(1,Math.floor(sn(e.quantity,1)));
      for(let i=0;i<qty;i++){
        items.push({
          id:`${comp.id}_${cat}_${e.type}_${i+1}`,
          type:cat, code:e.type||cat.toUpperCase(),
          description:e.description||src.description||e.type||cat,
          widthFt:Math.max(0.5,sn(e.widthFt??src.widthFt,3)),
          heightFt:Math.max(0.5,sn(e.heightFt??src.heightFt,6)),
          location:e.location||"Unspecified",
          side:locSide(e.location),
          wallPos:e.wallPos,          // 0–1 explicit position along wall (overrides auto-spacing)
          sillFt:e.sillFt,            // vertical position from floor level
          floorId, floorLabel,
        });
      }
    });
  };
  add(comp.doors,"door"); add(comp.windows,"window");
  return items;
}

function buildFloors() {
  return RAW_FLOORS.map(f=>{
    const comps=(f.components||[]).map(c=>{
      const wFt=Math.max(0.5,sn(c.widthFt??c.fallbackWidthFt,10));
      const dFt=Math.max(0.5,sn(c.depthFt??c.fallbackDepthFt,10));
      const hFt=Math.max(0.5,sn(c.heightFt??f.heightFt,10));
      const estimated=!c.widthFt||!c.depthFt||!!c.estimated;
      const openings=normalizeOpenings(c,f.id,f.label);
      const walls=["north","south","east","west"].map(side=>{
        const len=side==="north"||side==="south"?wFt:dFt;
        const wallOpenings=openings.filter(o=>o.side===side);
        return {
          id:`${c.id}_wall_${side}`, side, lengthFt:len,
          widthFt:wFt, depthFt:dFt, heightFt:hFt,
          thicknessM:WT_M, objectType:"wall",
          componentId:c.id, componentName:c.name,
          floorId:f.id, floorLabel:f.label,
          openings:wallOpenings,
          openingAreaSqFt:wallOpenings.reduce((s,o)=>s+o.widthFt*o.heightFt,0),
        };
      });
      const floorObject={
        id:`${c.id}_floor`, objectType:"floor",
        componentId:c.id, componentName:c.name,
        floorId:f.id, floorLabel:f.label,
        widthFt:wFt, depthFt:dFt, areaSqFt:wFt*dFt,
        estimated,
      };
      return {...c,widthFt:wFt,depthFt:dFt,heightFt:hFt,estimated,openings,walls,floorObject,
              floorId:f.id,floorLabel:f.label};
    });
    return {...f,components:comps};
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SELECTION CONTEXT (ref-based — zero scene re-renders on click)
// ═══════════════════════════════════════════════════════════════════════════
const SelCtx=createContext({selRef:{current:null}});


// ═══════════════════════════════════════════════════════════════════════════
// 3D — SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

// Drag context — ref-based so dragging causes zero React re-renders
const DragCtx = createContext({ dragRef: { current: null }, dragPosRef: { current: { wallPos: 0.5, sillFt: 0 } } });

function openingRunPos(opening, wallLen, wallOpenings) {
  if (opening.wallPos !== undefined) return opening.wallPos * wallLen;
  const auto = wallOpenings.filter(o => o.wallPos === undefined);
  const idx  = auto.findIndex(o => o.id === opening.id);
  const slot = wallLen / (auto.length + 1);
  return slot * Math.max(0, idx + 1);
}

function openingSill(opening, wallH) {
  if (opening.sillFt !== undefined) return Math.max(0, Math.min(wallH - opening.heightFt, opening.sillFt));
  if (opening.type === "door") return 0;
  if (opening.code === "FL")   return Math.max(0, wallH - opening.heightFt - 0.3);
  return Math.min(3, Math.max(0.5, wallH - opening.heightFt - 0.5));
}

// ═══════════════════════════════════════════════════════════════════════════
// 3D — DRAG CAPTURE PLANE
// Invisible plane aligned with a wall that captures pointer events during drag
// ═══════════════════════════════════════════════════════════════════════════
function DragCapturePlane({ side, component, onMove, onCommit }) {
  const isNS = side === "north" || side === "south";
  const W = component.widthFt, D = component.depthFt, H = component.heightFt;
  const wallLen = isNS ? W : D;
  const SNAP = 0.5; // snap grid in feet

  // Position plane flush with the wall exterior
  const px = side === "east"  ?  W/2 + 0.1
           : side === "west"  ? -W/2 - 0.1 : 0;
  const pz = side === "north" ? -D/2 - 0.1
           : side === "south" ?  D/2 + 0.1 : 0;
  const ry = isNS ? 0 : Math.PI / 2;

  return (
    <mesh position={[px, H/2, pz]} rotation={[0, ry, 0]}
      onPointerMove={e => {
        e.stopPropagation();
        // World-space X for N/S walls, Z for E/W walls → wallPos 0-1
        const raw = isNS
          ? (e.point.x + W/2) / W
          : (e.point.z + D/2) / D;
        const snappedFt = Math.round(raw * wallLen / SNAP) * SNAP;
        const sillFt = Math.round(e.point.y / SNAP) * SNAP;
        onMove({
          wallPos: Math.max(0.05, Math.min(0.95, snappedFt / wallLen)),
          sillFt: Math.max(0, Math.min(H - 0.5, sillFt)),
        });
      }}
      onPointerUp={e => { e.stopPropagation(); onCommit(); }}>
      <planeGeometry args={[isNS ? W + 30 : 30, H + 30]}/>
      <meshBasicMaterial transparent opacity={0} depthWrite={false} side={THREE.DoubleSide}/>
    </mesh>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// 3D — WALL MESH (assembled box with texture + opening colour fills)
// ═══════════════════════════════════════════════════════════════════════════
const WallMesh = memo(function WallMesh({ wall, onSelect, appliedMat }) {
  const { selRef } = useContext(SelCtx);
  const matRef = useRef();
  const H = wall.heightFt, T = WT_FT;
  const isNS = wall.side === "north" || wall.side === "south";
  const geo = isNS ? [wall.lengthFt, H, T] : [T, H, wall.lengthFt];
  const x = wall.side === "east" ?  wall.widthFt/2 : wall.side === "west"  ? -wall.widthFt/2 : 0;
  const z = wall.side === "north" ? -wall.depthFt/2 : wall.side === "south" ?  wall.depthFt/2 : 0;

  const surf = appliedMat?.surface || "plaster";
  const paintHex = WALL_COLORS[appliedMat?.paintColor]?.hex || "#f4ede0";

  useEffect(() => {
    if (!matRef.current) return;
    if (surf === "brick" || surf === "stone") {
      const bt = brickTex(surf === "stone" ? "stone" : (appliedMat?.brickType || "clay"));
      const cl = bt.clone(); cl.wrapS = cl.wrapT = THREE.RepeatWrapping;
      cl.repeat.set(wall.lengthFt / 5, H / 3); cl.needsUpdate = true;
      matRef.current.map = cl; matRef.current.color.set("#ffffff");
    } else if (surf === "paint") {
      matRef.current.map = null; matRef.current.color.set(paintHex);
    } else {
      const pt = plasterTex(paintHex).clone(); pt.wrapS = pt.wrapT = THREE.RepeatWrapping;
      pt.repeat.set(wall.lengthFt / 7, H / 5); pt.needsUpdate = true;
      matRef.current.map = pt; matRef.current.color.set("#ffffff");
    }
    matRef.current.needsUpdate = true;
  }, [surf, appliedMat, wall.lengthFt, H, paintHex]);

  useFrame(() => {
    if (!matRef.current) return;
    const sel = selRef.current === wall.id;
    matRef.current.emissive.setHex(sel ? 0x1e4a8a : 0x000000);
    matRef.current.emissiveIntensity = sel ? 0.2 : 0;
  });

  const handleClick = useCallback(e => {
    e.stopPropagation(); selRef.current = wall.id;
    onSelect({ ...wall, displayName: `${wall.componentName} — ${wall.side} wall` });
  }, [wall, onSelect, selRef]);

  return (
    <mesh position={[x, H/2, z]} onClick={handleClick} castShadow receiveShadow>
      <boxGeometry args={geo}/>
      <meshStandardMaterial ref={matRef} roughness={0.87} emissive="#000000" emissiveIntensity={0}/>
    </mesh>
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 3D — FLOOR MESH
// ═══════════════════════════════════════════════════════════════════════════
const FloorMesh = memo(function FloorMesh({ component, onSelect, appliedMat }) {
  const { selRef } = useContext(SelCtx);
  const matRef = useRef();
  const id = component.floorObject?.id;
  const W = component.widthFt, D = component.depthFt;

  const { tex, col } = useMemo(() => {
    if (component.openToSky) return { tex: null, col: "#a8f0e0" };
    if (appliedMat?.tileType) {
      const preset = TILE_P[appliedMat.tileType] || TILE_P.medium600;
      return { tex: tiledFloorTex(appliedMat.tileColor || "cream", W, D, preset), col: "#ffffff" };
    }
    return { tex: null, col: "#d0cbc0" };
  }, [appliedMat, W, D, component.openToSky]);

  useEffect(() => {
    if (!matRef.current) return;
    matRef.current.map = tex || null;
    matRef.current.color.set(col);
    matRef.current.needsUpdate = true;
  }, [tex, col]);

  useFrame(() => {
    if (!matRef.current) return;
    const sel = selRef.current === id;
    matRef.current.emissiveIntensity = sel ? 0.2 : 0;
  });

  const handleClick = useCallback(e => {
    e.stopPropagation(); selRef.current = id;
    onSelect({ ...component.floorObject, openToSky: component.openToSky });
  }, [component, id, onSelect, selRef]);

  return (
    <mesh position={[0, -0.04, 0]} onClick={handleClick} receiveShadow>
      <boxGeometry args={[W, 0.08, D]}/>
      <meshStandardMaterial ref={matRef} roughness={0.65}
        transparent={!!component.openToSky} opacity={component.openToSky ? 0.3 : 1}
        emissive="#000000" emissiveIntensity={0}/>
    </mesh>
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 3D — DOOR MESH  (realistic + double-click to drag)
// ═══════════════════════════════════════════════════════════════════════════
const DoorMesh = memo(function DoorMesh({ opening, component, onSelect, indexOnSide, totalOnSide, onStartDrag }) {
  const { selRef } = useContext(SelCtx);
  const { dragRef, dragPosRef } = useContext(DragCtx);
  const grpRef = useRef();
  const { widthFt: cW, depthFt: cD, heightFt: cH } = component;
  const isNS = opening.side === "north" || opening.side === "south";
  const maxRun = isNS ? cW : cD;
  const wallOpenings = component.openings.filter(o => o.side === opening.side);
  const baseRunPos = openingRunPos(opening, maxRun, wallOpenings);
  const so = 0.32;
  const x0 = opening.side === "east" ?  cW/2 + so : opening.side === "west"  ? -cW/2 - so : 0;
  const z0 = opening.side === "north" ? -cD/2 - so : opening.side === "south" ?  cD/2 + so : 0;
  const ry = isNS ? 0 : Math.PI / 2;
  const dW = clamp(opening.widthFt, 0.5, maxRun * 0.9);
  const dH = clamp(opening.heightFt, 1, cH * 0.96);
  const ft = 0.11;
  const isTimber = opening.code === "D1" || opening.code === "D2";
  const frameMat = isTimber ? "#4a2c14" : "#8090a0";
  const wood = useMemo(() => isTimber ? woodTex() : alumTex(), [isTimber]);

  useFrame(() => {
    if (!grpRef.current) return;
    const isDragging = dragRef.current?.openingId === opening.id;
    const isSel = selRef.current === opening.id;
    if (isDragging) {
      const runPos = dragPosRef.current.wallPos * maxRun;
      const x = isNS ? runPos - maxRun/2 : x0;
      const z = isNS ? z0 : runPos - maxRun/2;
      const y = Math.max(0, Math.min(cH - dH, dragPosRef.current.sillFt));
      grpRef.current.position.set(x, y, z);
    }
    grpRef.current.traverse(ch => {
      if (ch.isMesh && ch.material) {
        if (ch.name === "dragRing") {
          ch.visible = isDragging;
        } else {
          ch.material.emissiveIntensity = isDragging ? 0.5 : isSel ? 0.35 : 0;
        }
      }
    });
  });

  const handleClick = useCallback(e => {
    e.stopPropagation(); selRef.current = opening.id;
    onSelect({ ...opening, objectType: "door", componentName: component.name,
               displayName: `${opening.code} — ${opening.description}`,
               areaSqFt: opening.widthFt * opening.heightFt });
  }, [opening, component, onSelect, selRef]);

  const handleDblClick = useCallback(e => {
    e.stopPropagation();
    onStartDrag(opening, component);
  }, [opening, component, onStartDrag]);

  // Static computed position (updated by useFrame when dragging)
  const rx = isNS ? baseRunPos - maxRun/2 : x0;
  const rz = isNS ? z0 : baseRunPos - maxRun/2;
  const ryPos = openingSill(opening, cH);

  return (
    <group ref={grpRef} position={[rx, ryPos, rz]} rotation={[0, ry, 0]}
      onClick={handleClick} onDoubleClick={handleDblClick}>
      {/* Left jamb */}
      <mesh position={[-dW/2+ft/2, dH/2, 0]}>
        <boxGeometry args={[ft, dH, 0.16]}/>
        <meshStandardMaterial color={frameMat} roughness={0.5} emissive={frameMat} emissiveIntensity={0}/>
      </mesh>
      {/* Right jamb */}
      <mesh position={[dW/2-ft/2, dH/2, 0]}>
        <boxGeometry args={[ft, dH, 0.16]}/>
        <meshStandardMaterial color={frameMat} roughness={0.5} emissive={frameMat} emissiveIntensity={0}/>
      </mesh>
      {/* Head */}
      <mesh position={[0, dH-ft/2, 0]}>
        <boxGeometry args={[dW, ft, 0.16]}/>
        <meshStandardMaterial color={frameMat} roughness={0.5} emissive={frameMat} emissiveIntensity={0}/>
      </mesh>
      {/* Door leaf */}
      <mesh position={[0, (dH-ft)/2, 0]}>
        <boxGeometry args={[dW-ft*2, dH-ft, 0.08]}/>
        <meshStandardMaterial color={isTimber?"#7a5030":"#90a0b0"} map={wood} roughness={0.4}
          emissive={isTimber?"#7a5030":"#90a0b0"} emissiveIntensity={0}/>
      </mesh>
      {/* Panel insets (timber) */}
      {isTimber && [dH*0.25, dH*0.68].map((py,i) => (
        <mesh key={i} position={[0, py, 0.04]}>
          <boxGeometry args={[dW*0.68, dH*0.28, 0.025]}/>
          <meshStandardMaterial color="#6a4228" roughness={0.5} emissive="#6a4228" emissiveIntensity={0}/>
        </mesh>
      ))}
      {/* Handle */}
      <mesh position={[dW/2-ft-0.18, dH*0.44, 0.09]}>
        <cylinderGeometry args={[0.025, 0.025, 0.28, 8]}/>
        <meshStandardMaterial color="#c8a040" metalness={0.85} roughness={0.15}
          emissive="#c8a040" emissiveIntensity={0}/>
      </mesh>
      {/* Drag indicator ring — only visible while being dragged */}
      <mesh position={[0, dH/2, 0]} visible={false} name="dragRing">
        <torusGeometry args={[Math.max(dW,dH)*0.55, 0.05, 8, 32]}/>
        <meshStandardMaterial color="#60c0ff" emissive="#60c0ff" emissiveIntensity={1}
          transparent opacity={0.85}/>
      </mesh>
    </group>
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 3D — WINDOW MESH (realistic + double-click to drag)
// ═══════════════════════════════════════════════════════════════════════════
const WindowMesh = memo(function WindowMesh({ opening, component, onSelect, indexOnSide, totalOnSide, onStartDrag }) {
  const { selRef } = useContext(SelCtx);
  const { dragRef, dragPosRef } = useContext(DragCtx);
  const grpRef = useRef();
  const { widthFt: cW, depthFt: cD, heightFt: cH } = component;
  const isNS = opening.side === "north" || opening.side === "south";
  const maxRun = isNS ? cW : cD;
  const wallOpenings = component.openings.filter(o => o.side === opening.side);
  const baseRunPos = openingRunPos(opening, maxRun, wallOpenings);
  const sill = openingSill(opening, cH);
  const y = sill + opening.heightFt/2;
  const so = 0.32;
  const x0 = opening.side === "east" ?  cW/2 + so : opening.side === "west"  ? -cW/2 - so : 0;
  const z0 = opening.side === "north" ? -cD/2 - so : opening.side === "south" ?  cD/2 + so : 0;
  const ry = isNS ? 0 : Math.PI / 2;
  const wW = clamp(opening.widthFt, 0.5, maxRun * 0.9);
  const wH = clamp(opening.heightFt, 0.5, cH * 0.9);
  const ft = 0.09;
  const frameColor = "#503c20";

  useFrame(() => {
    if (!grpRef.current) return;
    const isDragging = dragRef.current?.openingId === opening.id;
    const isSel = selRef.current === opening.id;
    if (isDragging) {
      const runPos = dragPosRef.current.wallPos * maxRun;
      const x = isNS ? runPos - maxRun/2 : x0;
      const z = isNS ? z0 : runPos - maxRun/2;
      const bottom = Math.max(0, Math.min(cH - wH, dragPosRef.current.sillFt));
      grpRef.current.position.set(x, bottom + opening.heightFt/2, z);
    }
    grpRef.current.traverse(ch => {
      if (ch.isMesh && ch.material) {
        ch.material.emissiveIntensity = isDragging ? 0.55 : isSel ? 0.35 : 0;
      }
    });
  });

  const handleClick = useCallback(e => {
    e.stopPropagation(); selRef.current = opening.id;
    onSelect({ ...opening, objectType: "window", componentName: component.name,
               displayName: `${opening.code} — ${opening.description}`,
               areaSqFt: opening.widthFt * opening.heightFt });
  }, [opening, component, onSelect, selRef]);

  const handleDblClick = useCallback(e => {
    e.stopPropagation();
    onStartDrag(opening, component);
  }, [opening, component, onStartDrag]);

  const rx = isNS ? baseRunPos - maxRun/2 : x0;
  const rz = isNS ? z0 : baseRunPos - maxRun/2;
  const mullionH = wW > 3;
  const mullionV = wW > 4;

  return (
    <group ref={grpRef} position={[rx, y, rz]} rotation={[0, ry, 0]}
      onClick={handleClick} onDoubleClick={handleDblClick}>
      {/* Frame — 4 edges */}
      {[
        [0, wH/2-ft/2, 0, [wW, ft, 0.15]],
        [0,-wH/2+ft/2, 0, [wW, ft, 0.15]],
        [-wW/2+ft/2, 0, 0, [ft, wH, 0.15]],
        [ wW/2-ft/2, 0, 0, [ft, wH, 0.15]],
      ].map(([px,py,pz,a],i) => (
        <mesh key={i} position={[px,py,pz]}>
          <boxGeometry args={a}/>
          <meshStandardMaterial color={frameColor} roughness={0.45}
            emissive={frameColor} emissiveIntensity={0}/>
        </mesh>
      ))}
      {/* Glass */}
      <mesh>
        <boxGeometry args={[wW-ft*2, wH-ft*2, 0.05]}/>
        <meshStandardMaterial color="#9ed8f5" transparent opacity={0.35}
          roughness={0} metalness={0.1} emissive="#9ed8f5" emissiveIntensity={0}/>
      </mesh>
      {/* Mullions */}
      {mullionH && <mesh>
        <boxGeometry args={[wW-ft*2, ft*0.7, 0.1]}/>
        <meshStandardMaterial color={frameColor} roughness={0.45} emissive={frameColor} emissiveIntensity={0}/>
      </mesh>}
      {mullionV && <mesh>
        <boxGeometry args={[ft*0.7, wH-ft*2, 0.1]}/>
        <meshStandardMaterial color={frameColor} roughness={0.45} emissive={frameColor} emissiveIntensity={0}/>
      </mesh>}
      {/* Sill */}
      <mesh position={[0, -wH/2-0.04, 0.1]}>
        <boxGeometry args={[wW+0.2, ft, 0.3]}/>
        <meshStandardMaterial color="#d0c8b8" roughness={0.7} emissive="#d0c8b8" emissiveIntensity={0}/>
      </mesh>
    </group>
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 3D — ROOM GROUP (assembled room — all 4 walls + floor + openings together)
// ═══════════════════════════════════════════════════════════════════════════
const RoomGroup = memo(function RoomGroup({ component, onSelect, onStartDrag, mats }) {
  if (!component) return null;
  const openings = component.openings || [];
  const walls = component.walls || [];
  const sideIdx = {};

  return (
    <group>
      <FloorMesh component={component} onSelect={onSelect}
        appliedMat={mats[component.floorObject?.id]}/>
      {!component.openToSky && walls.map(w => (
        <WallMesh key={w.id} wall={w} onSelect={onSelect} appliedMat={mats[w.id]}/>
      ))}
      {!component.openToSky && openings.map(o => {
        const idx = sideIdx[o.side] || 0;
        sideIdx[o.side] = idx + 1;
        const total = openings.filter(x => x.side === o.side).length;
        const props = { opening:o, component, onSelect, indexOnSide:idx, totalOnSide:total, onStartDrag };
        return o.type === "door"
          ? <DoorMesh key={o.id} {...props}/>
          : <WindowMesh key={o.id} {...props}/>;
      })}
    </group>
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 3D — FLOOR LAYOUT (all rooms assembled together for full-floor view)
// ═══════════════════════════════════════════════════════════════════════════
function layoutFloor(floor) {
  const map = Object.fromEntries((floor.components||[]).map(c=>[c.id,c]));
  const gap = 1.5;
  const rows = (floor.layoutRows||[]).map(ids => (ids||[]).map(id=>map[id]).filter(Boolean));
  const rowH = rows.map(r => Math.max(0,...r.map(c=>c.depthFt)));
  const totalD = rowH.reduce((s,h)=>s+h,0)+gap*Math.max(0,rows.length-1);
  const placed = [];
  let zC = -totalD/2;
  rows.forEach((row,ri) => {
    const rW = row.reduce((s,c)=>s+c.widthFt,0)+gap*Math.max(0,row.length-1);
    let xC = -rW/2;
    row.forEach(c => {
      placed.push({ component:c, position:[xC+c.widthFt/2, 0, zC+rowH[ri]/2] });
      xC += c.widthFt+gap;
    });
    zC += rowH[ri]+gap;
  });
  return placed;
}

const FloorLayout = memo(function FloorLayout({ floor, onSelect, onStartDrag, mats }) {
  const placed = useMemo(() => layoutFloor(floor), [floor]);
  return (
    <group>
      {placed.map(({ component, position }) => (
        <group key={component.id} position={position}>
          <RoomGroup component={component} onSelect={onSelect}
            onStartDrag={onStartDrag} mats={mats}/>
        </group>
      ))}
    </group>
  );
});

// ═══════════════════════════════════════════════════════════════════════════
// 3D — SCENE ROOT  (drag state lives here)
// ═══════════════════════════════════════════════════════════════════════════
function SceneInner({ selComp, selFloor, onSelect, mats, editFns }) {
  const dragRef = useRef(null);
  const dragPosRef = useRef({ wallPos: 0.5, sillFt: 0 });
  const [dragOpId, setDragOpId] = useState(null);
  const dragCtxVal = useMemo(() => ({ dragRef, dragPosRef }), []);

  const startDrag = useCallback((opening, component) => {
    dragRef.current = {
      openingId: opening.id,
      side:      opening.side,
      compId:    component.id,
      isNS:      opening.side === "north" || opening.side === "south",
      wallLen:   (opening.side === "north" || opening.side === "south")
                   ? component.widthFt : component.depthFt,
    };
    dragPosRef.current = {
      wallPos: opening.wallPos ?? 0.5,
      sillFt: openingSill(opening, component.heightFt),
    };
    setDragOpId(opening.id);
    // Select the opening in the info panel too
    onSelect({ ...opening, objectType: opening.type, componentName: component.name,
               displayName: `${opening.code} — ${opening.description}`,
               areaSqFt: opening.widthFt * opening.heightFt });
  }, [onSelect]);

  const commitDrag = useCallback(() => {
    if (!dragRef.current) return;
    editFns.editOpening(dragRef.current.compId, dragRef.current.openingId,
      { wallPos: dragPosRef.current.wallPos, sillFt: dragPosRef.current.sillFt });
    dragRef.current = null;
    setDragOpId(null);
  }, [editFns]);

  // Find which component is being dragged (for DragCapturePlane)
  const dragComp = useMemo(() => {
    if (!dragOpId || !selComp) return null;
    if (selComp.isFullFloor) {
      return selFloor?.components?.find(c =>
        c.openings?.some(o => o.id === dragOpId)
      );
    }
    return selComp.openings?.some(o => o.id === dragOpId) ? selComp : null;
  }, [dragOpId, selComp, selFloor]);

  const dragOp = dragComp?.openings?.find(o => o.id === dragOpId);

  return (
    <DragCtx.Provider value={dragCtxVal}>
      <ambientLight intensity={0.55}/>
      <directionalLight position={[18,28,14]} intensity={0.9} castShadow
        shadow-mapSize={[1024,1024]} shadow-camera-far={120}/>
      <directionalLight position={[-10,14,-8]} intensity={0.3}/>
      <hemisphereLight skyColor="#b8d4f0" groundColor="#101820" intensity={0.35}/>
      <Grid args={[200,200]} cellSize={1} sectionSize={5}
        cellColor="#1a2838" sectionColor="#1e3050"
        fadeDistance={120} position={[0,-0.1,0]}/>

      {/* Invisible drag-capture plane (renders only during active drag) */}
      {dragOp && dragComp && (
        <DragCapturePlane side={dragOp.side} component={dragComp}
          onMove={pos => {
            dragPosRef.current = {
              wallPos: pos.wallPos,
              sillFt: Math.max(0, Math.min(dragComp.heightFt - dragOp.heightFt, pos.sillFt)),
            };
          }}
          onCommit={commitDrag}/>
      )}

      {selComp?.isFullFloor
        ? <FloorLayout floor={selFloor} onSelect={onSelect}
            onStartDrag={startDrag} mats={mats}/>
        : <RoomGroup component={selComp} onSelect={onSelect}
            onStartDrag={startDrag} mats={mats}/>
      }
      <OrbitControls makeDefault enableDamping dampingFactor={0.07}
        minDistance={4} maxDistance={200}
        enabled={!dragOpId}/>
    </DragCtx.Provider>
  );
}


// QUANTITY CALCULATIONS
// ═══════════════════════════════════════════════════════════════════════════
function calcWall(wall,s={}){
  const len=sn(wall?.lengthFt); const h=sn(wall?.heightFt);
  const gross=len*h;
  const openSqFt=Math.min(sn(wall?.openingAreaSqFt),gross*0.95);
  const net=Math.max(0,gross-openSqFt);
  const netM=net*SQFT;
  const tM=Math.max(0.01,sn(wall?.thicknessM,WT_M));
  const vol=netM*tM;
  const bp=BRICK_P[s.brickType]||BRICK_P.clay;
  const bVol=Math.max(1e-6,(bp.l/1000)*(bp.w/1000)*(bp.h/1000));
  const bricks=Math.ceil((vol/bVol)*(1+clamp(bp.waste,0,100)/100));
  const pp=PLASTER_P[s.plasterType]||PLASTER_P.normal;
  const pWet=netM*(sn(pp.mm,12)/1000);
  const pDry=pWet*1.33*(1+clamp(pp.waste,0,100)/100);
  const rp=pp.ratio==="1:4"?5:6; const sp=rp-1;
  const cement=Math.ceil((pDry/rp)/0.035);
  const sand=(pDry*sp)/rp;
  const pp2=PAINT_P[s.paintType]||PAINT_P.emulsion;
  const paint=(netM*Math.max(1,sn(pp2.coats))/Math.max(0.1,sn(pp2.cov)))*(1+clamp(pp2.waste,0,100)/100);
  const pp3=PUTTY_P[s.puttyType]||PUTTY_P.smooth;
  const putty=netM*Math.max(0,sn(pp3.kpc,0.8))*Math.max(1,sn(pp3.coats))*(1+clamp(pp3.waste,0,100)/100);
  return {gross,openSqFt,net,netM,vol,bricks,pDry,cement,sand,paint,putty};
}

function calcFloor(obj,s={}){
  const aFt=Math.max(0,sn(obj?.areaSqFt,sn(obj?.widthFt)*sn(obj?.depthFt)));
  const aM=aFt*SQFT;
  const tp=TILE_P[s.tileType]||TILE_P.medium600;
  const ta=Math.max(1e-6,(tp.w/1000)*(tp.h/1000));
  const waste=clamp(s.tileWastage,0,100)||10;
  const tiles=Math.ceil((aM/ta)*(1+waste/100));
  const grout=Math.ceil(aM*0.25*(1+waste/100));
  return {aFt,aM,ta,tiles,grout,waste};
}

// ═══════════════════════════════════════════════════════════════════════════
// UI HELPERS
// ═══════════════════════════════════════════════════════════════════════════
function Sel({value,onChange,children,label}){
  return(
    <div style={{marginBottom:10}}>
      {label&&<div style={{fontSize:10,color:"#8a9aaa",marginBottom:4,letterSpacing:"0.08em",textTransform:"uppercase"}}>{label}</div>}
      <select value={value} onChange={e=>onChange(e.target.value)}
        style={{width:"100%",background:"#1a2030",border:"1px solid #2a3548",color:"#d0dae8",
                padding:"7px 10px",borderRadius:6,fontSize:12,outline:"none"}}>
        {children}
      </select>
    </div>
  );
}
function Row({label,value,accent}){
  return(
    <div style={{display:"flex",justifyContent:"space-between",alignItems:"center",
                 padding:"5px 0",borderBottom:"1px solid #1e2838"}}>
      <span style={{fontSize:11,color:"#7a8a9a"}}>{label}</span>
      <span style={{fontSize:12,fontWeight:500,color:accent||"#c8d8e8",fontFamily:"monospace"}}>{value}</span>
    </div>
  );
}
function Btn({children,onClick,primary,small}){
  return(
    <button onClick={onClick} style={{
      background:primary?"#2563eb":"#1e2c40",
      border:primary?"none":"1px solid #2a3850",
      color:primary?"#fff":"#90a8c0",
      padding:small?"5px 12px":"8px 16px",
      borderRadius:6,fontSize:small?11:12,cursor:"pointer",
      fontWeight:primary?600:400,letterSpacing:"0.02em",
    }}>{children}</button>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// SIDEBAR COMPONENT TREE
// ═══════════════════════════════════════════════════════════════════════════
function Sidebar({floors,selId,setSelId,search,setSearch}){
  const q=search.trim().toLowerCase();
  return(
    <aside style={{width:260,background:"#0f1620",borderRight:"1px solid #1e2c3c",
                   display:"flex",flexDirection:"column",height:"100%",flexShrink:0}}>
      {/* Header */}
      <div style={{padding:"16px 16px 12px",borderBottom:"1px solid #1e2c3c"}}>
        <div style={{fontSize:10,color:"#4a6a8a",letterSpacing:"0.12em",textTransform:"uppercase",marginBottom:4}}>
          3D Quantity Viewer
        </div>
        <div style={{fontSize:14,fontWeight:600,color:"#c8dae8",lineHeight:1.2}}>Galle Site</div>
        <div style={{fontSize:10,color:"#506070",marginTop:2}}>1735.87 sq.ft · South, Sri Lanka</div>
        <input value={search} onChange={e=>setSearch(e.target.value)}
          placeholder="Search rooms…"
          style={{marginTop:10,width:"100%",background:"#141e2a",border:"1px solid #243040",
                  color:"#a0b8cc",padding:"6px 10px",borderRadius:5,fontSize:11,
                  outline:"none",boxSizing:"border-box"}}/>
      </div>
      {/* Tree */}
      <div style={{flex:1,overflowY:"auto",padding:"8px 8px"}}>
        {floors.map(f=>{
          const vis=f.components.filter(c=>!q||c.name.toLowerCase().includes(q)||c.id.toLowerCase().includes(q));
          if(!vis.length&&q) return null;
          const isFloorSel=selId===`full_${f.id}`;
          return(
            <div key={f.id} style={{marginBottom:12}}>
              <button onClick={()=>setSelId(`full_${f.id}`)} style={{
                width:"100%",textAlign:"left",background:isFloorSel?"#1a3a5c":"#141e2c",
                border:`1px solid ${isFloorSel?"#2563eb":"#1e2c3c"}`,color:isFloorSel?"#60a8e8":"#7a98b0",
                padding:"7px 10px",borderRadius:6,fontSize:11,cursor:"pointer",
                fontWeight:600,letterSpacing:"0.06em",textTransform:"uppercase",
                display:"flex",justifyContent:"space-between",
              }}>
                {f.label}
                <span style={{fontSize:9,opacity:0.7}}>FULL 3D</span>
              </button>
              <div style={{paddingLeft:6,marginTop:3,display:"flex",flexDirection:"column",gap:1}}>
                {vis.map(c=>{
                  const isSel=selId===c.id;
                  return(
                    <button key={c.id} onClick={()=>setSelId(c.id)} style={{
                      textAlign:"left",background:isSel?"#0e2040":"transparent",
                      border:isSel?"1px solid #1e4a7a":"1px solid transparent",
                      color:isSel?"#78b8e8":"#5a7888",
                      padding:"5px 8px",borderRadius:5,fontSize:11,cursor:"pointer",
                    }}>
                      <div style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}>
                        <span style={{fontWeight:isSel?500:400}}>
                          {c.label?<span style={{color:isSel?"#a8d0f0":"#4a7890",marginRight:4,fontWeight:700}}>{c.label}</span>:null}
                          {c.name}
                        </span>
                        {c.estimated&&<span style={{fontSize:9,background:"#302010",color:"#c08030",padding:"1px 5px",borderRadius:3}}>est</span>}
                      </div>
                      <div style={{fontSize:9,color:"#3a5060",marginTop:1,fontFamily:"monospace"}}>
                        {c.widthFt.toFixed(1)}ft × {c.depthFt.toFixed(1)}ft
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </aside>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TOOLBAR
// ═══════════════════════════════════════════════════════════════════════════
function Toolbar({unit,setUnit,viewMode,setViewMode}){
  const modes=["solid","wireframe","exploded"];
  return(
    <div style={{position:"absolute",top:12,left:12,zIndex:10,display:"flex",
                 gap:6,alignItems:"center",
                 background:"rgba(10,16,26,0.88)",border:"1px solid #1e3050",
                 padding:"6px 10px",borderRadius:8,backdropFilter:"blur(4px)"}}>
      <button onClick={()=>setUnit(u=>u==="ft"?"m":"ft")} style={{
        background:"#162030",border:"1px solid #2a4060",color:"#60a0d0",
        padding:"4px 10px",borderRadius:5,fontSize:10,cursor:"pointer",
        fontWeight:600,letterSpacing:"0.08em",fontFamily:"monospace",
      }}>{unit.toUpperCase()}</button>
      <div style={{width:1,height:16,background:"#1e3050"}}/>
      {modes.map(m=>(
        <button key={m} onClick={()=>setViewMode(m)} style={{
          background:viewMode===m?"#1a3a6c":"transparent",
          border:viewMode===m?"1px solid #2a5a9c":"1px solid transparent",
          color:viewMode===m?"#78baf0":"#4a7090",
          padding:"4px 9px",borderRadius:5,fontSize:10,cursor:"pointer",
          textTransform:"capitalize",fontWeight:viewMode===m?600:400,
        }}>{m}</button>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS TAB — HELPERS
// ═══════════════════════════════════════════════════════════════════════════

// Mini SVG wall diagram showing opening positions
function WallDiagram({ wall, allOpenings, selectedOpId, onSelectOp }) {
  if (!wall) return null;
  const W = wall.lengthFt;
  const svgW = 278, svgH = 72, mL = 8, mR = 8;
  const bw = svgW - mL - mR;
  const scale = bw / W;
  const wallOpenings = allOpenings.filter(o => o.side === wall.side);

  return (
    <svg width={svgW} height={svgH} style={{ display:"block", overflow:"visible" }}>
      {/* Wall label */}
      <text x={mL} y={10} fontSize={8} fill="#4a6a8a" textAnchor="start" style={{textTransform:"uppercase",letterSpacing:"0.08em"}}>
        {wall.side} wall — {W.toFixed(1)} ft
      </text>
      {/* Wall bar */}
      <rect x={mL} y={16} width={bw} height={22} fill="#1a2838" rx={2}/>
      {/* Wall cross-hatch edge lines */}
      <line x1={mL} y1={16} x2={mL} y2={38} stroke="#2a4060" strokeWidth={2}/>
      <line x1={mL+bw} y1={16} x2={mL+bw} y2={38} stroke="#2a4060" strokeWidth={2}/>

      {wallOpenings.map(o => {
        const rp = openingRunPos(o, W, wallOpenings);
        const ow = Math.min(o.widthFt, W * 0.9);
        const rawOx = (rp - ow/2) * scale + mL;
        const ox = Math.max(mL, Math.min(rawOx, mL+bw - ow*scale));
        const owPx = ow * scale;
        const isWin = o.type === "window";
        const isSel = selectedOpId === o.id;
        const fillC = isSel ? "#2563eb" : isWin ? "#2a6a9a" : "#7a4020";
        const pct = Math.round((rp / W) * 100);
        return (
          <g key={o.id} onClick={() => onSelectOp(o.id)}
             style={{ cursor:"pointer" }}>
            <rect x={ox} y={17} width={Math.max(owPx,1)} height={20}
              fill={fillC} opacity={0.9} rx={1}/>
            {isSel && <rect x={ox-1} y={16} width={Math.max(owPx,1)+2} height={22}
              fill="none" stroke="#60a8ff" strokeWidth={1.5} rx={2}/>}
            {owPx > 18 && (
              <text x={ox + owPx/2} y={30} textAnchor="middle"
                fontSize={owPx > 28 ? 7 : 6} fill="#fff" fontWeight={600}>
                {o.code}
              </text>
            )}
            {/* Position tick below */}
            <line x1={ox + owPx/2} y1={39} x2={ox + owPx/2} y2={44}
              stroke={isSel?"#60a8ff":"#3a5878"} strokeWidth={1}/>
            <text x={ox + owPx/2} y={52} textAnchor="middle"
              fontSize={6} fill={isSel?"#78b8f0":"#4a6878"}>
              {pct}%
            </text>
          </g>
        );
      })}
      {/* Ruler ticks */}
      {[0, 0.25, 0.5, 0.75, 1].map(f => (
        <line key={f} x1={mL + f*bw} y1={38} x2={mL + f*bw} y2={42}
          stroke="#2a3848" strokeWidth={1}/>
      ))}
      {wallOpenings.length === 0 && (
        <text x={mL + bw/2} y={30} textAnchor="middle" fontSize={8} fill="#2a4060" fontStyle="italic">
          no openings
        </text>
      )}
    </svg>
  );
}

// Small numeric stepper input
function NumInput({ value, onChange, min=0, max=999, step=0.5, unit="" }) {
  const dec = step < 1 ? 2 : 1;
  return (
    <div style={{ display:"flex", alignItems:"center", gap:4 }}>
      <button onClick={() => onChange(Math.max(min, +(+value - step).toFixed(dec)))}
        style={{ width:22, height:22, background:"#1a2838", border:"1px solid #2a3848",
                 color:"#60a0c0", borderRadius:4, cursor:"pointer", fontSize:12, lineHeight:1 }}>−</button>
      <input type="number" min={min} max={max} step={step} value={+value}
        onChange={e => onChange(Math.max(min, +e.target.value))}
        style={{ width:52, background:"#141e2c", border:"1px solid #2a3548", color:"#c8dae8",
                 padding:"3px 6px", borderRadius:4, fontSize:11, textAlign:"center", outline:"none",
                 fontFamily:"monospace" }}/>
      <button onClick={() => onChange(+(+value + step).toFixed(dec))}
        style={{ width:22, height:22, background:"#1a2838", border:"1px solid #2a3848",
                 color:"#60a0c0", borderRadius:4, cursor:"pointer", fontSize:12, lineHeight:1 }}>+</button>
      {unit && <span style={{ fontSize:10, color:"#4a6070" }}>{unit}</span>}
    </div>
  );
}

// Labeled range slider with live readout
function PosSlider({ label, value, onChange }) {
  const pct = Math.round(value * 100);
  return (
    <div style={{ marginBottom:8 }}>
      <div style={{ display:"flex", justifyContent:"space-between", marginBottom:3 }}>
        <span style={{ fontSize:10, color:"#5a7888" }}>{label}</span>
        <span style={{ fontSize:10, color:"#78b8f0", fontFamily:"monospace", fontWeight:600 }}>{pct}%</span>
      </div>
      <input type="range" min={1} max={99} value={pct}
        onChange={e => onChange(+e.target.value / 100)}
        style={{ width:"100%", accentColor:"#2563eb", height:3 }}/>
      <div style={{ display:"flex", justifyContent:"space-between", marginTop:2 }}>
        <span style={{ fontSize:8, color:"#2a3848" }}>0%</span>
        <span style={{ fontSize:8, color:"#2a3848" }}>50%</span>
        <span style={{ fontSize:8, color:"#2a3848" }}>100%</span>
      </div>
    </div>
  );
}

// Section card wrapper
function SCard({ title, badge, children, danger }) {
  return (
    <div style={{ background: danger?"#1a0c0c":"#141e2c",
                  border:`1px solid ${danger?"#4a1818":"#1e2c3c"}`,
                  borderRadius:8, padding:12, marginBottom:10 }}>
      <div style={{ display:"flex", justifyContent:"space-between", alignItems:"center",
                    marginBottom:8, borderBottom:`1px solid ${danger?"#3a1212":"#1e2c3c"}`,
                    paddingBottom:6 }}>
        <span style={{ fontSize:9, color: danger?"#c04040":"#4a6a8a",
                       letterSpacing:"0.1em", textTransform:"uppercase", fontWeight:600 }}>{title}</span>
        {badge && <span style={{ fontSize:8, background:"#0c2040", color:"#4a8acc",
                                 padding:"2px 6px", borderRadius:3 }}>{badge}</span>}
      </div>
      {children}
    </div>
  );
}

// Small icon button
function IconBtn({ label, onClick, color="#90a8c0", bg="#1a2838", title="" }) {
  return (
    <button onClick={onClick} title={title}
      style={{ background:bg, border:"1px solid #2a3848", color, padding:"4px 10px",
               borderRadius:5, fontSize:10, cursor:"pointer", whiteSpace:"nowrap" }}>
      {label}
    </button>
  );
}

// Opening row in the list
function OpeningRow({ op, isSelected, onSelect, onRemove }) {
  const isWin = op.type === "window";
  const pct = op.wallPos !== undefined ? Math.round(op.wallPos*100)+"%" : "auto";
  return (
    <div onClick={() => onSelect(op.id)}
      style={{ display:"flex", alignItems:"center", gap:6, padding:"6px 8px",
               background: isSelected ? "#0e2040" : "transparent",
               border: isSelected ? "1px solid #1e4a7a" : "1px solid transparent",
               borderRadius:5, cursor:"pointer", marginBottom:3, transition:"all 0.1s" }}>
      <div style={{ width:8, height:8, borderRadius:2, flexShrink:0,
                    background: isWin ? "#3a8ab0" : "#8b5030" }}/>
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ fontSize:11, color: isSelected?"#90c8f0":"#8ab0c8",
                      fontWeight: isSelected?600:400, truncate:true }}>
          {op.code} <span style={{ fontSize:10, color:"#4a6070", fontWeight:400 }}>
            {op.description?.slice(0,22)}{op.description?.length>22?"…":""}
          </span>
        </div>
        <div style={{ fontSize:9, color:"#3a5060", fontFamily:"monospace" }}>
          {op.widthFt.toFixed(1)}ft × {op.heightFt.toFixed(1)}ft · {op.side} · {pct}
        </div>
      </div>
      <button onClick={e=>{e.stopPropagation();onRemove();}}
        style={{ background:"#2a1010", border:"1px solid #4a2020", color:"#c06060",
                 padding:"2px 7px", borderRadius:4, fontSize:9, cursor:"pointer",
                 flexShrink:0 }}>
        ✕
      </button>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// SETTINGS TAB — MAIN COMPONENT
// ═══════════════════════════════════════════════════════════════════════════
function SettingsTab({ selComp, selObj, editFns, unit }) {
  // ── Room dimensions local state
  const [dims, setDims] = useState({ widthFt:10, depthFt:10, heightFt:11 });
  useEffect(() => {
    if (selComp && !selComp.isFullFloor) {
      setDims({ widthFt: selComp.widthFt, depthFt: selComp.depthFt, heightFt: selComp.heightFt });
    }
  }, [selComp?.id]);

  // ── Which opening is being edited
  const [editOpId, setEditOpId] = useState(null);
  const [opEdit, setOpEdit] = useState(null);

  // Sync opEdit when editOpId changes
  const allOpenings = selComp?.openings || [];
  useEffect(() => {
    if (!editOpId) { setOpEdit(null); return; }
    const op = allOpenings.find(o => o.id === editOpId);
    if (op) setOpEdit({ wallPos: op.wallPos ?? 0.5, widthFt: op.widthFt, heightFt: op.heightFt, side: op.side });
  }, [editOpId]);

  // If clicking active wall in 3D, pre-scroll to that wall's openings
  const activeWallId = selObj?.objectType === "wall" ? selObj.id : null;
  const activeWall = selComp?.walls?.find(w => w.id === activeWallId) || null;

  // ── Add-opening form state
  const [addForm, setAddForm] = useState({
    type:"window", code:"FW4", side:"south",
    wallPos:0.5, widthFt:6, heightFt:9
  });
  const [justAdded, setJustAdded] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);
  const [dimsApplied, setDimsApplied] = useState(false);

  const openingCodes = {
    door:   Object.keys(OPENINGS.doors),
    window: Object.keys(OPENINGS.windows),
  };

  const ftm = v => unit === "m" ? `${(v*FT).toFixed(2)} m` : `${v.toFixed(2)} ft`;

  if (!selComp || selComp.isFullFloor) {
    return (
      <div style={{ padding:20, color:"#304050", fontSize:12, textAlign:"center", marginTop:24 }}>
        <div style={{ fontSize:28, marginBottom:8 }}>⚙</div>
        Select a room from the sidebar<br/>to edit its dimensions,<br/>openings and settings.
      </div>
    );
  }

  const editingOp = editOpId ? allOpenings.find(o => o.id === editOpId) : null;
  const sides = ["north","south","east","west"];

  return (
    <div style={{ padding:"10px 12px" }}>

      {/* ── ROOM DIMENSIONS ─────────────────────────── */}
      <SCard title="Room Dimensions" badge={selComp.name}>
        {[
          { key:"widthFt",   label:"Width",  max:80 },
          { key:"depthFt",   label:"Depth",  max:80 },
          { key:"heightFt",  label:"Height", max:20 },
        ].map(({ key, label, max }) => (
          <div key={key} style={{ marginBottom:10 }}>
            <div style={{ display:"flex", justifyContent:"space-between", marginBottom:4 }}>
              <span style={{ fontSize:10, color:"#5a7888" }}>{label}</span>
              <span style={{ fontSize:10, color:"#4a8acc", fontFamily:"monospace" }}>
                {ftm(dims[key])}
              </span>
            </div>
            <div style={{ display:"flex", alignItems:"center", gap:8 }}>
              <input type="range" min={1} max={max} step={0.25} value={dims[key]}
                onChange={e => setDims(d => ({ ...d, [key]: +e.target.value }))}
                style={{ flex:1, accentColor:"#2563eb", height:3 }}/>
              <NumInput value={dims[key]} onChange={v => setDims(d => ({ ...d, [key]:v }))}
                min={0.5} max={max} step={0.25} unit="ft"/>
            </div>
          </div>
        ))}
        <div style={{ display:"flex", gap:6, marginTop:4 }}>
          <button onClick={() => {
            editFns.editRoomDims(selComp.id, dims);
            setDimsApplied(true);
            setTimeout(() => setDimsApplied(false), 2000);
          }} style={{ flex:1, background:"#1a3a6c", border:"1px solid #2a5a9c",
                      color:"#78baf0", padding:"7px 0", borderRadius:6, fontSize:11,
                      cursor:"pointer", fontWeight:600 }}>
            {dimsApplied ? "✓ Applied!" : "Apply Dimensions"}
          </button>
          <button onClick={() => setDims({ widthFt: selComp.widthFt, depthFt: selComp.depthFt, heightFt: selComp.heightFt })}
            style={{ background:"#1a2030", border:"1px solid #2a3040", color:"#4a6070",
                     padding:"7px 10px", borderRadius:6, fontSize:10, cursor:"pointer" }}>
            ↺
          </button>
        </div>
      </SCard>

      {/* ── OPENING MANAGER ─────────────────────────── */}
      <SCard title={activeWall ? `${activeWall.side} wall openings` : "All Openings"}
             badge={`${allOpenings.length} total`}>

        {/* Wall diagram — shows when a wall is selected in 3D */}
        {activeWall && (
          <div style={{ background:"#0e1828", borderRadius:6, padding:"6px 4px", marginBottom:8, overflowX:"auto" }}>
            <WallDiagram wall={activeWall} allOpenings={allOpenings}
              selectedOpId={editOpId} onSelectOp={id => setEditOpId(id === editOpId ? null : id)}/>
          </div>
        )}

        {/* All openings tabs: show by wall */}
        {!activeWall && (
          <div style={{ marginBottom:8 }}>
            {sides.map(side => {
              const wallOps = allOpenings.filter(o => o.side === side);
              const wall = selComp.walls?.find(w => w.side === side);
              if (!wallOps.length) return null;
              return (
                <div key={side} style={{ marginBottom:8 }}>
                  <div style={{ marginBottom:4, background:"#0e1828", borderRadius:4, padding:"4px 6px", overflowX:"auto" }}>
                    <WallDiagram wall={wall} allOpenings={allOpenings}
                      selectedOpId={editOpId}
                      onSelectOp={id => setEditOpId(id === editOpId ? null : id)}/>
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Opening list */}
        <div style={{ maxHeight:200, overflowY:"auto" }}>
          {(activeWall ? allOpenings.filter(o=>o.side===activeWall.side) : allOpenings).map(op => (
            <OpeningRow key={op.id} op={op} isSelected={editOpId===op.id}
              onSelect={id => setEditOpId(id === editOpId ? null : id)}
              onRemove={() => {
                editFns.removeOpening(selComp.id, op.id);
                if (editOpId === op.id) setEditOpId(null);
              }}/>
          ))}
          {allOpenings.length === 0 && (
            <div style={{ fontSize:10, color:"#2a4050", textAlign:"center", padding:"10px 0", fontStyle:"italic" }}>
              No openings — add one below
            </div>
          )}
        </div>
      </SCard>

      {/* ── EDIT SELECTED OPENING ───────────────────── */}
      {editingOp && opEdit && (
        <SCard title="Edit Opening" badge={editingOp.code}>
          <div style={{ display:"flex", gap:6, marginBottom:8, flexWrap:"wrap" }}>
            <span style={{ fontSize:9, background:"#0c2040", color:"#5090d0",
                           padding:"2px 8px", borderRadius:3, fontWeight:600, textTransform:"uppercase" }}>
              {editingOp.type}
            </span>
            <span style={{ fontSize:9, background:"#141e2c", color:"#4a6a8a",
                           padding:"2px 8px", borderRadius:3 }}>
              {editingOp.description}
            </span>
          </div>

          {/* Position on wall */}
          <PosSlider label="Position along wall" value={opEdit.wallPos ?? 0.5}
            onChange={v => setOpEdit(s => ({ ...s, wallPos:v }))}/>

          {/* Width and height */}
          <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:8, marginBottom:10 }}>
            <div>
              <div style={{ fontSize:10, color:"#5a7888", marginBottom:4 }}>Width (ft)</div>
              <NumInput value={opEdit.widthFt} min={0.5} max={30} step={0.25} unit="ft"
                onChange={v => setOpEdit(s => ({ ...s, widthFt:v }))}/>
            </div>
            <div>
              <div style={{ fontSize:10, color:"#5a7888", marginBottom:4 }}>Height (ft)</div>
              <NumInput value={opEdit.heightFt} min={0.5} max={15} step={0.25} unit="ft"
                onChange={v => setOpEdit(s => ({ ...s, heightFt:v }))}/>
            </div>
          </div>

          {/* Move to different wall */}
          <div style={{ marginBottom:10 }}>
            <div style={{ fontSize:10, color:"#5a7888", marginBottom:6 }}>Move to wall</div>
            <div style={{ display:"flex", gap:5, flexWrap:"wrap" }}>
              {sides.map(s => (
                <button key={s} onClick={() => setOpEdit(e => ({ ...e, side:s }))}
                  style={{ background: opEdit.side===s?"#1a3a6c":"#1a2030",
                           border: opEdit.side===s?"1px solid #2a5a9c":"1px solid #2a3040",
                           color: opEdit.side===s?"#78baf0":"#4a6070",
                           padding:"4px 10px", borderRadius:5, fontSize:10, cursor:"pointer",
                           textTransform:"capitalize" }}>
                  {s}
                </button>
              ))}
            </div>
          </div>

          {/* Actions */}
          <div style={{ display:"flex", gap:6 }}>
            <button onClick={() => {
              editFns.editOpening(selComp.id, editingOp.id, opEdit);
              setEditOpId(null);
            }} style={{ flex:1, background:"#1a3a6c", border:"1px solid #2a5a9c", color:"#78baf0",
                       padding:"6px 0", borderRadius:6, fontSize:11, cursor:"pointer", fontWeight:600 }}>
              Save Changes
            </button>
            <button onClick={() => setEditOpId(null)}
              style={{ background:"#1a2030", border:"1px solid #2a3040", color:"#4a6070",
                       padding:"6px 10px", borderRadius:6, fontSize:10, cursor:"pointer" }}>
              Cancel
            </button>
            <button onClick={() => {
              editFns.removeOpening(selComp.id, editingOp.id);
              setEditOpId(null);
            }} style={{ background:"#2a1010", border:"1px solid #4a2020", color:"#c06060",
                       padding:"6px 10px", borderRadius:6, fontSize:10, cursor:"pointer" }}>
              Remove
            </button>
          </div>
        </SCard>
      )}

      {/* ── ADD NEW OPENING ─────────────────────────── */}
      <SCard title="Add New Opening">
        {/* Type selector (door/window toggles) */}
        <div style={{ display:"flex", gap:6, marginBottom:10 }}>
          {["door","window"].map(t => (
            <button key={t} onClick={() => {
              const firstCode = openingCodes[t][0];
              const src = OPENINGS[t+"s"]?.[firstCode] || {};
              setAddForm(f => ({ ...f, type:t, code:firstCode,
                widthFt: src.widthFt || (t==="door"?3:6),
                heightFt: src.heightFt || (t==="door"?7:9) }));
            }}
              style={{ flex:1, background: addForm.type===t?"#1a3a6c":"#1a2030",
                       border: addForm.type===t?"1px solid #2a5a9c":"1px solid #2a3040",
                       color: addForm.type===t?"#78baf0":"#4a6070",
                       padding:"6px 0", borderRadius:6, fontSize:11,
                       cursor:"pointer", textTransform:"capitalize", fontWeight:600 }}>
              {t === "door" ? "🚪 Door" : "🪟 Window"}
            </button>
          ))}
        </div>

        {/* Code selector with live preview of dimensions */}
        <div style={{ marginBottom:10 }}>
          <div style={{ fontSize:10, color:"#5a7888", marginBottom:4 }}>Type / Code</div>
          <div style={{ display:"flex", flexWrap:"wrap", gap:4 }}>
            {openingCodes[addForm.type].map(code => {
              const src = OPENINGS[addForm.type+"s"]?.[code] || {};
              return (
                <button key={code} onClick={() => setAddForm(f => ({
                  ...f, code,
                  widthFt: src.widthFt || f.widthFt,
                  heightFt: src.heightFt || f.heightFt
                }))}
                  title={`${src.description || code} — ${src.widthFt}'× ${src.heightFt}'`}
                  style={{ background: addForm.code===code?"#1a3a6c":"#141e2c",
                           border: addForm.code===code?"1px solid #2a5a9c":"1px solid #2a3040",
                           color: addForm.code===code?"#78baf0":"#4a6070",
                           padding:"3px 8px", borderRadius:4, fontSize:10,
                           cursor:"pointer", fontWeight: addForm.code===code?600:400 }}>
                  {code}
                </button>
              );
            })}
          </div>
          {(OPENINGS[addForm.type+"s"]?.[addForm.code]) && (
            <div style={{ fontSize:9, color:"#3a5878", marginTop:4, fontStyle:"italic" }}>
              {OPENINGS[addForm.type+"s"][addForm.code].description}
            </div>
          )}
        </div>

        {/* Target wall */}
        <div style={{ marginBottom:10 }}>
          <div style={{ fontSize:10, color:"#5a7888", marginBottom:6 }}>Place on wall</div>
          <div style={{ display:"flex", gap:5, flexWrap:"wrap" }}>
            {sides.map(s => (
              <button key={s} onClick={() => setAddForm(f => ({ ...f, side:s }))}
                style={{ background: addForm.side===s?"#1a3a6c":"#1a2030",
                         border: addForm.side===s?"1px solid #2a5a9c":"1px solid #2a3040",
                         color: addForm.side===s?"#78baf0":"#4a6070",
                         padding:"4px 10px", borderRadius:5, fontSize:10, cursor:"pointer",
                         textTransform:"capitalize" }}>
                {s}
              </button>
            ))}
          </div>
        </div>

        {/* Position */}
        <PosSlider label="Position on wall" value={addForm.wallPos}
          onChange={v => setAddForm(f => ({ ...f, wallPos:v }))}/>

        {/* Dimensions */}
        <div style={{ display:"grid", gridTemplateColumns:"1fr 1fr", gap:8, marginBottom:12 }}>
          <div>
            <div style={{ fontSize:10, color:"#5a7888", marginBottom:4 }}>Width (ft)</div>
            <NumInput value={addForm.widthFt} min={0.5} max={30} step={0.25}
              onChange={v => setAddForm(f => ({ ...f, widthFt:v }))}/>
          </div>
          <div>
            <div style={{ fontSize:10, color:"#5a7888", marginBottom:4 }}>Height (ft)</div>
            <NumInput value={addForm.heightFt} min={0.5} max={15} step={0.25}
              onChange={v => setAddForm(f => ({ ...f, heightFt:v }))}/>
          </div>
        </div>

        <button onClick={() => {
          editFns.addOpening(selComp.id, addForm);
          setJustAdded(true);
          setTimeout(() => setJustAdded(false), 2000);
        }} style={{ width:"100%", background:"#0e3020", border:"1px solid #1a6040",
                   color:"#40c878", padding:"8px 0", borderRadius:6, fontSize:12,
                   cursor:"pointer", fontWeight:600 }}>
          {justAdded ? "✓ Opening Added!" : `+ Add ${addForm.code} to ${addForm.side} wall`}
        </button>
      </SCard>

      {/* ── DANGER ZONE ─────────────────────────────── */}
      <SCard title="Danger Zone" danger>
        <div style={{ fontSize:10, color:"#6a4040", marginBottom:8, lineHeight:1.5 }}>
          Reset this room to its original dimensions and openings from the architectural drawings.
        </div>
        {!confirmReset ? (
          <button onClick={() => setConfirmReset(true)}
            style={{ width:"100%", background:"#2a1010", border:"1px solid #5a2020",
                     color:"#c06060", padding:"7px 0", borderRadius:6, fontSize:11,
                     cursor:"pointer", fontWeight:600 }}>
            Reset Room to Original
          </button>
        ) : (
          <div style={{ display:"flex", gap:6 }}>
            <button onClick={() => { editFns.resetRoom(selComp.id); setConfirmReset(false); setEditOpId(null); }}
              style={{ flex:1, background:"#3a1010", border:"1px solid #7a2020", color:"#e06060",
                       padding:"7px 0", borderRadius:6, fontSize:11, cursor:"pointer", fontWeight:700 }}>
              Yes, Reset
            </button>
            <button onClick={() => setConfirmReset(false)}
              style={{ flex:1, background:"#1a2030", border:"1px solid #2a3040", color:"#6a8898",
                       padding:"7px 0", borderRadius:6, fontSize:11, cursor:"pointer" }}>
              Cancel
            </button>
          </div>
        )}
      </SCard>

      <div style={{ height:12 }}/>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// RIGHT PANEL
// ═══════════════════════════════════════════════════════════════════════════
function RightPanel({selObj,selComp,unit,settings,setSettings,mats,setMats,editFns}){
  const [tab,setTab]=useState("info");

  // Auto-jump to settings if user selects something editable from 3D and we detect an opening click
  useEffect(()=>{
    if(selObj?.objectType==="door"||selObj?.objectType==="window") {
      // don't forcibly switch tab — let user choose
    }
  },[selObj]);

  const applyWallMat=useCallback(()=>{
    if(!selObj||selObj.objectType!=="wall") return;
    setMats(m=>({...m,[selObj.id]:{
      surface:settings.wallSurface,
      brickType:settings.brickType,
      paintColor:settings.paintColor,
    }}));
  },[selObj,settings,setMats]);

  const applyFloorMat=useCallback(()=>{
    if(!selObj||selObj.objectType!=="floor") return;
    setMats(m=>({...m,[selObj.id]:{
      tileType:settings.tileType,
      tileColor:settings.tileColor,
    }}));
  },[selObj,settings,setMats]);

  const clearMat=useCallback(()=>{
    if(!selObj) return;
    setMats(m=>{const n={...m};delete n[selObj.id];return n;});
  },[selObj,setMats]);

  const wq=useMemo(()=>selObj?.objectType==="wall"?calcWall(selObj,settings):null,[selObj,settings]);
  const fq=useMemo(()=>selObj?.objectType==="floor"?calcFloor(selObj,settings):null,[selObj,settings]);
  const compTotals=useMemo(()=>{
    if(!selComp||selComp.isFullFloor) return null;
    const wt=(selComp.walls||[]).reduce((a,w)=>{const q=calcWall(w,settings);return{
      bricks:a.bricks+q.bricks,paint:a.paint+q.paint,
      putty:a.putty+q.putty,cement:a.cement+q.cement};},{bricks:0,paint:0,putty:0,cement:0});
    const fo=calcFloor(selComp.floorObject,settings);
    return{wt,fo};
  },[selComp,settings]);

  const ftm=v=>unit==="m"?`${fmt(v*FT)} m`:`${fmt(v)} ft`;
  const am=v=>unit==="m"?`${fmt(v*SQFT)} m²`:`${fmt(v)} sq.ft`;

  const tabs=["info","materials","quantities","settings"];
  const appliedMat=selObj?mats[selObj.id]:null;

  return(
    <aside style={{width:320,background:"#0f1620",borderLeft:"1px solid #1e2c3c",
                   display:"flex",flexDirection:"column",height:"100%",flexShrink:0}}>
      {/* Header */}
      <div style={{padding:"12px 14px 0",borderBottom:"1px solid #1e2c3c"}}>
        <div style={{fontSize:10,color:"#4a6a8a",letterSpacing:"0.1em",textTransform:"uppercase",marginBottom:8}}>
          {selComp&&!selComp.isFullFloor?selComp.name:"Details"}
        </div>
        <div style={{display:"flex",gap:2,paddingBottom:0,flexWrap:"wrap"}}>
          {tabs.map(t=>(
            <button key={t} onClick={()=>setTab(t)} style={{
              background:"transparent",border:"none",
              borderBottom:tab===t?"2px solid #2a6adc":"2px solid transparent",
              color:t==="settings"?(tab===t?"#f0c060":"#4a6030"):tab===t?"#78baf0":"#3a5878",
              padding:"5px 7px",fontSize:10,cursor:"pointer",
              textTransform:"capitalize",fontWeight:tab===t?600:400,
            }}>{t==="settings"?"⚙ Settings":t}</button>
          ))}
        </div>
      </div>

      <div style={{flex:1,overflowY:"auto",padding:tab==="settings"?"0":"12px 14px"}}>
        {/* ── SETTINGS TAB ─────────────────────────── */}
        {tab==="settings"&&(
          <SettingsTab selComp={selComp} selObj={selObj} editFns={editFns} unit={unit}/>
        )}
        {/* ── INFO TAB ─────────────────────────────── */}
        {tab==="info"&&(
          <>
            {/* Room summary */}
            {selComp&&!selComp.isFullFloor&&(
              <div style={{background:"#141e2c",border:"1px solid #1e2c3c",borderRadius:8,padding:12,marginBottom:12}}>
                <div style={{display:"flex",justifyContent:"space-between",alignItems:"start",marginBottom:10}}>
                  <div>
                    <div style={{fontSize:13,fontWeight:600,color:"#c0d8ec"}}>{selComp.name}</div>
                    <div style={{fontSize:10,color:"#4a6a8a",marginTop:2}}>{selComp.floorLabel}</div>
                  </div>
                  {selComp.estimated&&<span style={{fontSize:9,background:"#302010",color:"#c08030",padding:"2px 6px",borderRadius:3,fontWeight:600}}>ESTIMATED</span>}
                </div>
                <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:6}}>
                  {[["Width",ftm(selComp.widthFt)],["Depth",ftm(selComp.depthFt)],
                    ["Height",ftm(selComp.heightFt)],["Area",am(selComp.widthFt*selComp.depthFt)],
                    ["Openings",(selComp.openings||[]).length],
                  ].map(([l,v])=>(
                    <div key={l} style={{background:"#0f1828",borderRadius:5,padding:"6px 8px"}}>
                      <div style={{fontSize:9,color:"#4a6070",marginBottom:2}}>{l}</div>
                      <div style={{fontSize:12,color:"#90c0e0",fontFamily:"monospace",fontWeight:500}}>{v}</div>
                    </div>
                  ))}
                </div>
                {compTotals&&(
                  <div style={{marginTop:10,borderTop:"1px solid #1e2c3c",paddingTop:10}}>
                    <div style={{fontSize:10,color:"#4a6a8a",marginBottom:6,letterSpacing:"0.08em",textTransform:"uppercase"}}>Room Estimate</div>
                    <Row label="Bricks/blocks" value={`${fmt(compTotals.wt.bricks,0)} pcs`}/>
                    <Row label="Paint" value={`${fmt(compTotals.wt.paint,1)} L`}/>
                    <Row label="Putty" value={`${fmt(compTotals.wt.putty,1)} kg`}/>
                    <Row label="Tiles" value={`${fmt(compTotals.fo.tiles,0)} pcs`}/>
                  </div>
                )}
              </div>
            )}

            {/* Selected object */}
            <div style={{background:"#141e2c",border:"1px solid #1e2c3c",borderRadius:8,padding:12}}>
              <div style={{fontSize:10,color:"#4a6a8a",marginBottom:8,letterSpacing:"0.08em",textTransform:"uppercase"}}>Selected object</div>
              {!selObj?(
                <div style={{fontSize:11,color:"#304050",fontStyle:"italic"}}>Click any wall, floor, door, or window in the 3D view</div>
              ):(
                <>
                  <div style={{display:"flex",gap:6,marginBottom:8,flexWrap:"wrap"}}>
                    <span style={{fontSize:9,background:"#0c2040",color:"#5090d0",padding:"2px 8px",borderRadius:3,fontWeight:600,textTransform:"uppercase"}}>{selObj.objectType}</span>
                    {selObj.floorLabel&&<span style={{fontSize:9,background:"#0c1828",color:"#3a6080",padding:"2px 8px",borderRadius:3,textTransform:"uppercase"}}>{selObj.floorLabel}</span>}
                    {appliedMat&&<span style={{fontSize:9,background:"#0c2818",color:"#40a060",padding:"2px 8px",borderRadius:3}}>material applied</span>}
                  </div>
                  <div style={{fontSize:12,fontWeight:500,color:"#c0d8e8",marginBottom:8}}>{selObj.displayName||selObj.code||selObj.componentName}</div>
                  {selObj.objectType==="wall"&&<>
                    <Row label="Side" value={selObj.side}/>
                    <Row label="Length" value={ftm(selObj.lengthFt)}/>
                    <Row label="Height" value={ftm(selObj.heightFt)}/>
                    <Row label="Thickness" value={unit==="m"?`${fmt(selObj.thicknessM)} m`:`${fmt(selObj.thicknessM/FT)} ft`}/>
                    <Row label="Openings" value={`${(selObj.openings||[]).length}`}/>
                  </>}
                  {selObj.objectType==="floor"&&<>
                    <Row label="Width" value={ftm(selObj.widthFt)}/>
                    <Row label="Depth" value={ftm(selObj.depthFt)}/>
                    <Row label="Area" value={am(selObj.areaSqFt)}/>
                  </>}
                  {(selObj.objectType==="door"||selObj.objectType==="window")&&<>
                    <Row label="Code" value={selObj.code}/>
                    <Row label="Description" value={selObj.description}/>
                    <Row label="Width" value={ftm(selObj.widthFt)}/>
                    <Row label="Height" value={ftm(selObj.heightFt)}/>
                    <Row label="Area" value={am(selObj.areaSqFt)}/>
                    <Row label="Location" value={selObj.location}/>
                  </>}
                </>
              )}
            </div>
          </>
        )}

        {/* ── MATERIALS TAB ────────────────────────── */}
        {tab==="materials"&&(
          <>
            {selObj?.objectType==="wall"&&(
              <div style={{background:"#141e2c",border:"1px solid #1e2c3c",borderRadius:8,padding:12,marginBottom:10}}>
                <div style={{fontSize:10,color:"#4a6a8a",marginBottom:10,letterSpacing:"0.08em",textTransform:"uppercase"}}>Wall Surface</div>
                <Sel label="Surface type" value={settings.wallSurface} onChange={v=>setSettings(s=>({...s,wallSurface:v}))}>
                  {Object.entries(WALL_SURF).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                {(settings.wallSurface==="brick"||settings.wallSurface==="stone")&&(
                  <Sel label="Brick / stone type" value={settings.brickType} onChange={v=>setSettings(s=>({...s,brickType:v}))}>
                    {Object.entries(BRICK_P).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                    <option value="stone">Stone Cladding</option>
                  </Sel>
                )}
                {settings.wallSurface==="paint"&&(
                  <Sel label="Paint color" value={settings.paintColor} onChange={v=>setSettings(s=>({...s,paintColor:v}))}>
                    {Object.entries(WALL_COLORS).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                  </Sel>
                )}
                {/* Preview swatch */}
                <div style={{background:"#0e1824",borderRadius:6,padding:8,marginBottom:10}}>
                  <div style={{fontSize:9,color:"#4a6070",marginBottom:5}}>Preview</div>
                  <div style={{height:32,borderRadius:4,overflow:"hidden",display:"flex"}}>
                    {settings.wallSurface==="brick"||settings.wallSurface==="stone"?
                      (()=>{
                        const brickSwatches={clay:["#bb4018","#c4481c","#b23910","#c04215"],
                          cementBlock:["#8c979e","#929ba2","#87929a","#939fa6"],
                          stone:["#9c9890","#a8a49c","#9a9690","#b0aca4"],
                          custom:["#c57838","#cf7f3e","#c0722f","#ca7a35"]};
                        const cols=brickSwatches[settings.brickType]||brickSwatches.clay;
                        return Array.from({length:8}).map((_,i)=>(
                          <div key={i} style={{flex:1,background:cols[i%cols.length],margin:"1px",borderRadius:1}}/>
                        ));
                      })():
                      <div style={{flex:1,background:WALL_COLORS[settings.paintColor]?.hex||"#f4efe6",borderRadius:4}}/>
                    }
                    }
                  </div>
                </div>
                <div style={{display:"flex",gap:6}}>
                  <Btn primary onClick={applyWallMat}>Apply to Wall</Btn>
                  {appliedMat&&<Btn onClick={clearMat} small>Reset</Btn>}
                </div>
                {appliedMat&&(
                  <div style={{marginTop:8,fontSize:10,color:"#40a060"}}>
                    ✓ Material applied — visible in 3D
                  </div>
                )}
              </div>
            )}

            {selObj?.objectType==="floor"&&(
              <div style={{background:"#141e2c",border:"1px solid #1e2c3c",borderRadius:8,padding:12,marginBottom:10}}>
                <div style={{fontSize:10,color:"#4a6a8a",marginBottom:10,letterSpacing:"0.08em",textTransform:"uppercase"}}>Floor Tiles</div>
                <Sel label="Tile size" value={settings.tileType} onChange={v=>setSettings(s=>({...s,tileType:v}))}>
                  {Object.entries(TILE_P).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                <Sel label="Tile color" value={settings.tileColor} onChange={v=>setSettings(s=>({...s,tileColor:v}))}>
                  {Object.entries(TILE_COL).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                {/* Tile preview grid */}
                <div style={{background:"#0e1824",borderRadius:6,padding:8,marginBottom:10}}>
                  <div style={{fontSize:9,color:"#4a6070",marginBottom:5}}>Preview</div>
                  <div style={{display:"grid",gridTemplateColumns:"repeat(4,1fr)",gap:3,height:32}}>
                    {Array.from({length:8}).map((_,i)=>(
                      <div key={i} style={{background:TILE_COL[settings.tileColor]?.c1||"#ede9e0",
                        border:"1px solid #808070",borderRadius:1}}/>
                    ))}
                  </div>
                </div>
                <div style={{display:"flex",gap:6}}>
                  <Btn primary onClick={applyFloorMat}>Apply to Floor</Btn>
                  {appliedMat&&<Btn onClick={clearMat} small>Reset</Btn>}
                </div>
                {appliedMat&&(
                  <div style={{marginTop:8,fontSize:10,color:"#40a060"}}>
                    ✓ Tiles applied — visible in 3D
                  </div>
                )}
              </div>
            )}

            {(!selObj||(!["wall","floor"].includes(selObj.objectType)))&&(
              <div style={{fontSize:11,color:"#304050",fontStyle:"italic",textAlign:"center",marginTop:30}}>
                Click a wall or floor to apply materials
              </div>
            )}
          </>
        )}

        {/* ── QUANTITIES TAB ───────────────────────── */}
        {tab==="quantities"&&selObj&&(
          <>
            {selObj.objectType==="wall"&&wq&&(
              <div style={{background:"#141e2c",border:"1px solid #1e2c3c",borderRadius:8,padding:12,marginBottom:10}}>
                <div style={{fontSize:10,color:"#4a6a8a",marginBottom:10,letterSpacing:"0.08em",textTransform:"uppercase"}}>Wall Calculator</div>
                <Sel label="Brick type" value={settings.brickType} onChange={v=>setSettings(s=>({...s,brickType:v}))}>
                  {Object.entries(BRICK_P).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                <Sel label="Plaster" value={settings.plasterType} onChange={v=>setSettings(s=>({...s,plasterType:v}))}>
                  {Object.entries(PLASTER_P).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                <Sel label="Paint" value={settings.paintType} onChange={v=>setSettings(s=>({...s,paintType:v}))}>
                  {Object.entries(PAINT_P).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                <Sel label="Putty" value={settings.puttyType} onChange={v=>setSettings(s=>({...s,puttyType:v}))}>
                  {Object.entries(PUTTY_P).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                <div style={{marginTop:8}}>
                  <Row label="Gross wall area" value={am(wq.gross)}/>
                  <Row label="Opening deduction" value={am(wq.openSqFt)}/>
                  <Row label="Net wall area" value={unit==="m"?`${fmt(wq.netM)} m²`:am(wq.net)} accent="#78d8a8"/>
                  <Row label="Wall volume" value={`${fmt(wq.vol,3)} m³`}/>
                  <Row label="Bricks / blocks" value={`${fmt(wq.bricks,0)} pcs`} accent="#f0c870"/>
                  <Row label="Plaster mortar" value={`${fmt(wq.pDry,3)} m³`}/>
                  <Row label="Cement" value={`${fmt(wq.cement,0)} bags`} accent="#f0c870"/>
                  <Row label="Sand" value={`${fmt(wq.sand,3)} m³`}/>
                  <Row label="Putty" value={`${fmt(wq.putty,1)} kg`}/>
                  <Row label="Paint" value={`${fmt(wq.paint,1)} L`}/>
                </div>
              </div>
            )}
            {selObj.objectType==="floor"&&fq&&(
              <div style={{background:"#141e2c",border:"1px solid #1e2c3c",borderRadius:8,padding:12,marginBottom:10}}>
                <div style={{fontSize:10,color:"#4a6a8a",marginBottom:10,letterSpacing:"0.08em",textTransform:"uppercase"}}>Floor Calculator</div>
                <Sel label="Tile size" value={settings.tileType} onChange={v=>setSettings(s=>({...s,tileType:v}))}>
                  {Object.entries(TILE_P).map(([k,v])=><option key={k} value={k}>{v.label}</option>)}
                </Sel>
                <div style={{marginBottom:8}}>
                  <div style={{fontSize:10,color:"#4a6a8a",marginBottom:4,textTransform:"uppercase",letterSpacing:"0.08em"}}>Wastage %</div>
                  <input type="number" min={0} max={30} step={1} value={settings.tileWastage}
                    onChange={e=>setSettings(s=>({...s,tileWastage:clamp(Number(e.target.value),0,30)}))}
                    style={{width:"100%",background:"#1a2030",border:"1px solid #2a3548",color:"#d0dae8",
                            padding:"7px 10px",borderRadius:6,fontSize:12,outline:"none",boxSizing:"border-box"}}/>
                </div>
                <div style={{marginTop:8}}>
                  <Row label="Floor area" value={unit==="m"?`${fmt(fq.aM)} m²`:am(fq.aFt)} accent="#78d8a8"/>
                  <Row label="Tile size" value={`${fmt(fq.ta*1e6,0)} cm²`}/>
                  <Row label="Tiles needed" value={`${fmt(fq.tiles,0)} pcs`} accent="#f0c870"/>
                  <Row label="Grout estimate" value={`${fmt(fq.grout,0)} kg`}/>
                  <Row label="Wastage" value={`${fq.waste}%`}/>
                </div>
              </div>
            )}
            {(selObj.objectType==="door"||selObj.objectType==="window")&&(
              <div style={{background:"#141e2c",border:"1px solid #1e2c3c",borderRadius:8,padding:12}}>
                <div style={{fontSize:10,color:"#4a6a8a",marginBottom:10,letterSpacing:"0.08em",textTransform:"uppercase"}}>Opening Schedule</div>
                <Row label="Code" value={selObj.code}/>
                <Row label="Type" value={selObj.description}/>
                <Row label="Width" value={ftm(selObj.widthFt)}/>
                <Row label="Height" value={ftm(selObj.heightFt)}/>
                <Row label="Area" value={am(selObj.areaSqFt)} accent="#78d8a8"/>
                <Row label="Location" value={selObj.location}/>
                <Row label="Side" value={selObj.side}/>
              </div>
            )}
            {!selObj&&(
              <div style={{fontSize:11,color:"#304050",fontStyle:"italic",textAlign:"center",marginTop:30}}>
                Select an object to view quantities
              </div>
            )}
          </>
        )}
        {tab==="quantities"&&!selObj&&(
          <div style={{fontSize:11,color:"#304050",fontStyle:"italic",textAlign:"center",marginTop:30}}>
            Click a wall or floor to calculate quantities
          </div>
        )}
        <div style={{height:16}}/>
        {tab!=="info"&&<div style={{fontSize:9,color:"#2a4050",textAlign:"center",lineHeight:1.5}}>
          Fast estimate only. Confirm with a certified QS before procurement.
        </div>}
      </div>
    </aside>
  );
}

// Rebuild walls for a component after opening/dimension changes
function rebuildCompWalls(comp, newOpenings, newDims) {
  const wFt = newDims?.widthFt || comp.widthFt;
  const dFt = newDims?.depthFt || comp.depthFt;
  const hFt = newDims?.heightFt || comp.heightFt;
  const walls = ["north","south","east","west"].map(side => {
    const len = (side==="north"||side==="south") ? wFt : dFt;
    const base = comp.walls?.find(w => w.side === side) || {};
    const wallOps = newOpenings.filter(o => o.side === side);
    return { ...base, side, lengthFt:len, widthFt:wFt, depthFt:dFt, heightFt:hFt,
             thicknessM:WT_M, objectType:"wall",
             componentId:comp.id, componentName:comp.name,
             floorId:comp.floorId, floorLabel:comp.floorLabel,
             openings:wallOps,
             openingAreaSqFt:wallOps.reduce((s,o)=>s+o.widthFt*o.heightFt,0) };
  });
  return walls;
}

function updateComp(floors, roomId, updater) {
  return floors.map(floor => ({
    ...floor,
    components: floor.components.map(comp => comp.id === roomId ? updater(comp) : comp)
  }));
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════════════════════════════════════
export default function App(){
  const [floors, setFloors] = useState(() => buildFloors());
  const allComps=useMemo(()=>floors.flatMap(f=>f.components),[floors]);

  const [selId,setSelId]=useState("full_groundFloor");
  const [selObj,setSelObj]=useState(null);
  const [unit,setUnit]=useState("ft");
  const [viewMode,setViewMode]=useState("solid");
  const [search,setSearch]=useState("");
  const [mats,setMats]=useState({});
  const [settings,setSettings]=useState({
    wallSurface:"plaster",brickType:"clay",paintColor:"white",
    plasterType:"normal",puttyType:"smooth",paintType:"emulsion",
    tileType:"medium600",tileColor:"cream",tileWastage:10,
  });

  const selRef=useRef(null);
  const ctxValue=useMemo(()=>({selRef}),[]);

  // ── EDIT FUNCTIONS ────────────────────────────────────────────────────────

  const editRoomDims = useCallback((roomId, dims) => {
    setFloors(prev => updateComp(prev, roomId, comp => {
      const wFt = Math.max(0.5, dims.widthFt || comp.widthFt);
      const dFt = Math.max(0.5, dims.depthFt || comp.depthFt);
      const hFt = Math.max(1, dims.heightFt || comp.heightFt);
      const walls = rebuildCompWalls({ ...comp, widthFt:wFt, depthFt:dFt, heightFt:hFt }, comp.openings, { widthFt:wFt, depthFt:dFt, heightFt:hFt });
      return { ...comp, widthFt:wFt, depthFt:dFt, heightFt:hFt,
               walls, estimated:false,
               floorObject:{ ...comp.floorObject, widthFt:wFt, depthFt:dFt, areaSqFt:wFt*dFt }};
    }));
  }, []);

  const removeOpening = useCallback((roomId, openingId) => {
    setFloors(prev => updateComp(prev, roomId, comp => {
      const newOpenings = comp.openings.filter(o => o.id !== openingId);
      return { ...comp, openings:newOpenings, walls:rebuildCompWalls(comp, newOpenings) };
    }));
  }, []);

  const editOpening = useCallback((roomId, openingId, changes) => {
    setFloors(prev => updateComp(prev, roomId, comp => {
      const newOpenings = comp.openings.map(o =>
        o.id === openingId ? { ...o, ...changes } : o
      );
      return { ...comp, openings:newOpenings, walls:rebuildCompWalls(comp, newOpenings) };
    }));
  }, []);

  const addOpening = useCallback((roomId, formData) => {
    setFloors(prev => updateComp(prev, roomId, comp => {
      const sched = formData.type === "door" ? OPENINGS.doors : OPENINGS.windows;
      const src = sched[formData.code] || {};
      const newOp = {
        id: `${comp.id}_${formData.type}_${formData.code}_custom_${Date.now()}`,
        type: formData.type, code: formData.code,
        description: src.description || formData.code,
        widthFt: Math.max(0.5, formData.widthFt),
        heightFt: Math.max(0.5, formData.heightFt),
        side: formData.side,
        wallPos: formData.wallPos,
        location: `${formData.side} wall — custom`,
        floorId: comp.floorId, floorLabel: comp.floorLabel,
      };
      const newOpenings = [...comp.openings, newOp];
      return { ...comp, openings:newOpenings, walls:rebuildCompWalls(comp, newOpenings) };
    }));
  }, []);

  const resetRoom = useCallback((roomId) => {
    const freshFloors = buildFloors();
    const freshComp = freshFloors.flatMap(f => f.components).find(c => c.id === roomId);
    if (!freshComp) return;
    setFloors(prev => updateComp(prev, roomId, () => freshComp));
  }, []);

  const editFns = useMemo(() => ({
    editRoomDims, removeOpening, editOpening, addOpening, resetRoom,
  }), [editRoomDims, removeOpening, editOpening, addOpening, resetRoom]);

  const selFloor=useMemo(()=>{
    if(selId.startsWith("full_")) return floors.find(f=>f.id===selId.slice(5))||floors[0];
    const comp=allComps.find(c=>c.id===selId);
    return floors.find(f=>f.id===comp?.floorId)||floors[0];
  },[selId,floors,allComps]);

  const selComp=useMemo(()=>{
    if(selId.startsWith("full_")) return{id:selId,name:`Full ${selFloor.label}`,
      floorId:selFloor.id,floorLabel:selFloor.label,isFullFloor:true};
    return allComps.find(c=>c.id===selId)||allComps[0];
  },[selId,selFloor,allComps]);

  const handleSelectId=useCallback(id=>{setSelId(id);setSelObj(null);selRef.current=null;},[]);

  const handleSelectObj=useCallback(obj=>{
    setSelObj(obj);
  },[]);

  // Wireframe flag passed to scene via key
  const sceneKey=viewMode;

  return(
    <SelCtx.Provider value={ctxValue}>
      <div style={{display:"flex",height:"100vh",width:"100%",overflow:"hidden",
                   background:"#080f18",color:"#c0d0e0",fontFamily:"system-ui,sans-serif"}}>
        <Sidebar floors={floors} selId={selId} setSelId={handleSelectId} search={search} setSearch={setSearch}/>
        <div style={{flex:1,position:"relative",minWidth:0}}>
          <Toolbar unit={unit} setUnit={setUnit} viewMode={viewMode} setViewMode={setViewMode}/>
          <Canvas key={sceneKey} camera={{position:[24,20,28],fov:45}} shadows dpr={[1,1.5]}
            style={{background:"linear-gradient(180deg,#080e14 0%,#0a1318 100%)"}}
            onPointerMissed={() => {}}>
            <Suspense fallback={null}>
              <SceneInner selComp={selComp} selFloor={selFloor} onSelect={handleSelectObj}
                mats={mats} editFns={editFns}/>
            </Suspense>
          </Canvas>
          {/* Controls hint */}
          <div style={{position:"absolute",bottom:12,left:12,zIndex:10,
                       background:"rgba(10,16,26,0.82)",border:"1px solid #1e3050",
                       padding:"6px 12px",borderRadius:6,fontSize:9,color:"#3a5878",
                       backdropFilter:"blur(4px)",lineHeight:1.8}}>
            <span style={{color:"#5a8aaa",fontWeight:600}}>Click</span> wall / floor / opening for details
            &nbsp;·&nbsp;<span style={{color:"#f0c060",fontWeight:600}}>Double-click</span> door or window → drag to move
            &nbsp;·&nbsp;Release to place &nbsp;·&nbsp; <span style={{color:"#5a8aaa"}}>Orbit / Zoom / Pan</span> disabled during drag
          </div>
        </div>
        <RightPanel selObj={selObj} selComp={selComp} unit={unit}
          settings={settings} setSettings={setSettings} mats={mats} setMats={setMats}
          editFns={editFns}/>
      </div>
    </SelCtx.Provider>
  );
}
