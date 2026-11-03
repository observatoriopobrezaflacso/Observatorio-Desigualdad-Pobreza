// Genera las cifras (cifras.tex) y los datos de las figuras (*.dat) de la presentación
// con el MISMO modelo del simulador: se carga el código de plantilla_tablero.html y los
// resultados del análisis en R (resultados.json). Uso: node insumos/generar_insumos.js
const fs = require('fs'), path = require('path');
const AQUI = __dirname, CODE = path.join(AQUI, '..', '..', 'Code');
const DATOS = JSON.parse(fs.readFileSync(path.join(CODE, 'resultados.json'), 'utf8'));
const tpl = fs.readFileSync(path.join(CODE, 'plantilla_tablero.html'), 'utf8');
const ini = tpl.indexOf('/* ---------------------------------------------------------------- utils');
const fin = tpl.indexOf('/* ------------------------------------------------------- gráficos');
const modelo = tpl.slice(ini, fin);

const cuerpo = `
const out = {macros: [], dat: {}};
const mac = (k, v) => out.macros.push([k, v]);
const f0 = x => num(x, 0), f1 = x => num(x, 1), f2 = x => num(x, 2);
const mm = x => num(x/1e6, 0), p1 = x => num(100*x, 1), p2 = x => num(100*x, 2);
const DEF = {fil: S.fil, hl: S.hl, infl: S.infl, adm: S.adm};
const reset = () => Object.assign(S, DEF, {grupo:'total'});

// ---- parámetros por defecto
mac('DefFil', f1(DEF.fil)); mac('DefHL', f0(DEF.hl)); mac('DefInfl', f0(DEF.infl)); mac('DefAdm', f0(DEF.adm));
mac('LP', f2(M.linea_pobreza)); mac('LPE', f2(M.linea_pobreza_extrema));
mac('MontoRefSinInfl', f2(M.monto_referencia_pobreza)); mac('MontoRefESinInfl', f2(M.monto_referencia_extrema));
mac('NHog', f0(M.n_hogares)); mac('NPer', f0(M.n_personas));
mac('LineaMin', f2(Math.min(...M.lineas_mensuales.linea_pobreza))); mac('LineaMax', f2(Math.max(...M.lineas_mensuales.linea_pobreza)));
mac('PIB', num(DATOS.macro.pib_2025/1e9, 1)); mac('PGE', num(DATOS.macro.pge_2025/1e9, 1));

// ---- punto de partida
mac('PobInc', p1(N.incidencia_pobreza.est)); mac('PobLi', p1(N.incidencia_pobreza.li)); mac('PobLs', p1(N.incidencia_pobreza.ls));
mac('ExtInc', p1(N.incidencia_extrema.est)); mac('ExtLi', p1(N.incidencia_extrema.li)); mac('ExtLs', p1(N.incidencia_extrema.ls));
mac('PobPer', f0(N.pobres.est)); mac('ExtPer', f0(N.pobres_extremos.est));
mac('PobHog', f0(N.hogares_pobres.est)); mac('ExtHog', f0(N.hogares_pobres_extremos.est));
mac('PobHogInc', p1(N.hogares_pobres.est/N.hogares.est)); mac('ExtHogInc', p1(N.hogares_pobres_extremos.est/N.hogares.est));
mac('Hogares', f0(N.hogares.est)); mac('Poblacion', f0(N.poblacion.est));
mac('BrechaMedia', f0(G.total__pobreza.brecha_media_hogar)); mac('BrechaMediaE', f0(G.total__extrema.brecha_media_hogar));
mac('BrechaAnual', mm(12*G.total__pobreza.brecha_mensual.est)); mac('BrechaAnualE', mm(12*G.total__extrema.brecha_mensual.est));
mac('BrechaAnualPIB', p2(12*G.total__pobreza.brecha_mensual.est/DATOS.macro.pib_2025));
mac('TamPobre', f1(G.total__pobreza.tamano_hogar_pobre)); mac('TamNoPobre', f1(N.tamano_hogar_nopobre));
mac('Gini', num(N.gini, 3)); mac('FGTuno', p1(N.fgt1_pobreza.est)); mac('IngMedio', f0(N.ingreso_pc_medio.est));
mac('RefHog', f0(REF.hogares.est)); mac('RefPob', f0(REF.hogares_pobres.est));
mac('RefBrechaMedia', f0(REF.brecha_media)); mac('RefBrechaMax', f0(REF.brecha_maxima));

// ---- BDH observado
const B = DATOS.bdh_observado.lineas;
mac('BdhFil', f2(B.pobreza.grupos.total.filtracion.est)); mac('BdhFilLi', f2(B.pobreza.grupos.total.filtracion.li));
mac('BdhFilLs', f2(B.pobreza.grupos.total.filtracion.ls)); mac('BdhCob', p1(B.pobreza.grupos.total.cobertura_pobres.est));
mac('BdhHL', f0(100*B.pobreza.vida_media)); mac('BdhFilE', f1(B.extrema.grupos.total.filtracion.est));
mac('BdhHLE', f0(100*B.extrema.vida_media)); mac('BdhCobE', p1(B.extrema.grupos.total.cobertura_pobres.est));

// ---- escenario base (todos los hogares) para las dos metas
for (const [lk, P] of [['pobreza',''], ['extrema','E']]) {
  reset(); S.linea = lk; S.monto = montoRef(); const s = simular();
  mac('Monto'+P, f2(S.monto));
  mac('HogBenef'+P, f0(s.hogBenef)); mac('HogNP'+P, f0(s.hogNoPobres)); mac('PerNP'+P, f0(s.perNoPobres));
  mac('Costo'+P, mm(s.anual.est)); mac('CostoLi'+P, mm(s.anual.li)); mac('CostoLs'+P, mm(s.anual.ls));
  mac('CostoMes'+P, mm(s.mes.est));
  mac('CostoPIB'+P, p2(s.anual.est/DATOS.macro.pib_2025)); mac('CostoPGE'+P, p1(s.anual.est/DATOS.macro.pge_2025));
  mac('SalenHog'+P, p1(s.shareHogSalen)); mac('SalenPer'+P, p1(s.sharePerSalen)); mac('PerSalen'+P, f0(s.perSalen));
  mac('HogSiguen'+P, f0(s.hogSiguenPobres));
  mac('Caen'+P, f0(s.perCaen)); mac('CaenSin'+P, f0(s.perCaenSinProteccion));
  mac('Despues'+P, p1(s.residual)); mac('DespuesHog'+P, p1(s.residualHog)); mac('Antes'+P, p1(s.inicial));
  mac('CostoPorPer'+P, f0(s.costoPorPersona)); mac('BrechaCub'+P, p1(s.brechaCub/s.brechaObj));
  mac('TransfNP'+P, mm(s.transfNoPobresAnual)); mac('TransfNPShare'+P, p1(s.transfNoPobresAnual/(s.anual.est/(1+S.adm/100))));
  // Del costo mínimo al costo del programa
  const r = esc(), z = lineaZ(), infl = S.infl/100;
  S.adm = 0;
  const c0 = 12*r.brecha_mensual.est;
  const c1 = simular(M.tam_referencia*z, 0, 0).anual.est;
  const c2 = simular(M.tam_referencia*z*(1+infl), 0, infl).anual.est;
  const c3 = simular(M.tam_referencia*z*(1+infl), DEF.fil, infl).anual.est;
  S.adm = DEF.adm;
  const c4 = simular(M.tam_referencia*z*(1+infl), DEF.fil, infl).anual.est;
  [['Brecha',c0],['Uniforme',c1],['Inflacion',c2],['Filtracion',c3],['Adm',c4]].forEach(([k,v])=>{
    mac('Desc'+k+P, mm(v)); mac('Desc'+k+'PIB'+P, p2(v/DATOS.macro.pib_2025)); });
  out.dat['descomposicion'+(P||'P')] = [['paso','costo'], [1,c0/1e6],[2,c1/1e6],[3,c2/1e6],[4,c3/1e6],[5,c4/1e6]];
}

// ---- uniformidad: brecha y salida de la pobreza según el tamaño del hogar (pobreza, base)
reset(); S.linea='pobreza'; S.monto = montoRef();
{ const z = lineaZ(), zi = z*(1+S.infl/100), T = S.monto, filas = [['tam','sharehog','brecha','salen']];
  const acc = {};
  for (let i=0;i<MD.y.length;i++){ if (MD.y[i] >= z) continue;
    const k = Math.min(MD.n[i], 8), w = MD.w[i], br = (zi - MD.y[i])*MD.n[i];
    acc[k] = acc[k] || {w:0, br:0, sal:0}; acc[k].w += w; acc[k].br += w*br; if (T >= br) acc[k].sal += w; }
  const tot = Object.values(acc).reduce((a,b)=>a+b.w,0);
  for (const k of Object.keys(acc).map(Number).sort((a,b)=>a-b)) {
    const a = acc[k]; filas.push([k, 100*a.w/tot, a.br/a.w, 100*a.sal/a.w]);
    mac('TamShare'+'ABCDEFGH'[k-1], f1(100*a.w/tot)); mac('TamBrecha'+'ABCDEFGH'[k-1], f0(a.br/a.w));
    mac('TamSalen'+'ABCDEFGH'[k-1], f0(100*a.sal/a.w)); }
  out.dat.tamano = filas;
  // sobrepago: lo que reciben por encima de su brecha los hogares que salen
  let pagado=0, sobre=0;
  for (let i=0;i<MD.y.length;i++){ if (MD.y[i] >= z) continue; const br=(zi-MD.y[i])*MD.n[i];
    pagado += MD.w[i]*T; sobre += MD.w[i]*Math.max(0, T-br); }
  mac('Sobrepago', p1(sobre/pagado));
}

// ---- curvas según el monto
reset(); S.linea='pobreza'; S.monto = montoRef();
out.dat.monto = [['monto','salen','costo']].concat(Array.from({length:71},(_,i)=>i*10).map(t=>{
  const s = simular(t); return [t, s.perSalen/1e6, s.anual.est/1e6]; }));

// ---- inflación: monto fijo en el de referencia por defecto
reset(); S.linea='pobreza'; S.monto = montoRef();
out.dat.inflacion = [['infl','base','sinfil','hlbaja','antes']].concat(Array.from({length:41},(_,v)=>{
  const a = simular(S.monto, DEF.fil, v/100, DEF.hl/100).residual, b = simular(S.monto, 0, v/100).residual,
        c = simular(S.monto, DEF.fil, v/100, 0.25).residual;
  return [v, 100*a, 100*b, 100*c, 100*N.incidencia_pobreza.est]; }));

// ---- sensibilidad: inflación × filtración (el monto sigue a la línea encarecida)
for (const v of [0, 5, 10, 20]) {
  reset(); S.linea='pobreza'; S.infl = v; const T = montoRef();
  const rows = [['SinFil', 0, DEF.hl], ['Base', DEF.fil, DEF.hl], ['HLBaja', DEF.fil, 25]];
  for (const [k, fil, hl] of rows) { const s = simular(T, fil, v/100, hl/100);
    const id = 'Sens'+k+['Cero','Cinco','Diez','Veinte'][[0,5,10,20].indexOf(v)];
    mac(id+'Desp', p1(s.residual)); mac(id+'Caen', num(s.perCaen/1e3, 0)); mac(id+'Costo', mm(s.anual.est)); }
}

// ---- filtración
reset(); S.linea='pobreza'; S.monto = montoRef();
out.dat.filtracion = [['fil','costo','porpersona']].concat(Array.from({length:36},(_,i)=>i/10).map(f=>{
  const s = simular(S.monto, f); return [f, s.anual.est/1e6, s.costoPorPersona]; }));
{ const s0 = simular(S.monto, 0), s1 = simular(S.monto, DEF.fil);
  mac('CostoSinFil', mm(s0.anual.est)); mac('CostoPorPerSinFil', f0(s0.costoPorPersona)); }

// ---- perfil de inclusión: modelo (por defecto y concentrado) y BDH observado
reset(); S.linea='pobreza';
{ const z = lineaZ(), n85 = nivelFiltracion('total','pobreza',DEF.fil, DEF.hl/100), n25 = nivelFiltracion('total','pobreza',DEF.fil, 0.25);
  out.dat.perfil = [['rel','base','hlbaja']].concat(Array.from({length:81},(_,i)=>1+i*0.025).map(r=>[r,
    100*Math.min(1, n85.c*perfil(r*z, z, DEF.hl/100)), 100*Math.min(1, n25.c*perfil(r*z, z, 0.25))]));
  const tr = B.pobreza.grupos.total.tramos;
  out.dat.perfil_bdh = [['rel','prob']].concat(tr.prob.map((p,i)=>[(tr.desde[i]+tr.hasta[i])/2, 100*p]));
  mac('ProbLineaModelo', f0(100*Math.min(1, n85.c))); mac('ProbLineaBdh', f0(100*tr.prob[0]));
  const bandaBaja = 1 + 0.25*Math.log2(n25.c); mac('BandaHLBaja', num(bandaBaja, 2));
}

// ---- seis escenarios
{ const filas = [];
  for (const gk of ['total','menor5','mayor65']) for (const lk of ['pobreza','extrema']) {
    reset(); S.grupo = gk; S.linea = lk; const r = esc(), T = montoRef(); S.monto = T;
    const s0 = simular(T, 0), s1 = simular(T, DEF.fil);
    const id = {total:'Tot', menor5:'Cinco', mayor65:'Mayor'}[gk] + (lk==='pobreza'?'P':'E');
    mac('Esc'+id+'Hog', f0(r.hogares_pobres.est)); mac('Esc'+id+'Salen', f0(100*s0.shareHogSalen));
    mac('Esc'+id+'SinFil', mm(s0.anual.est)); mac('Esc'+id+'ConFil', mm(s1.anual.est));
    mac('Esc'+id+'Antes', p1(s1.inicial)); mac('Esc'+id+'Desp', p1(s1.residual)); mac('Esc'+id+'PIB', p2(s1.anual.est/DATOS.macro.pib_2025));
  }
}

// ---- comparación con gasto público (escenario base de pobreza)
reset(); S.linea='pobreza'; S.monto = montoRef();
{ const s = simular(); const items = DATOS.gasto_publico.filter(g=>g.tipo!=='total')
    .map(g=>({n:g.nombre, v:g.monto/1e6})).concat([{n:'Bono uniforme (escenario base)', v:s.anual.est/1e6}])
    .sort((a,b)=>a.v-b.v);
  out.dat.gasto = [['id','monto','etiqueta']].concat(items.map((d,i)=>[i, d.v, '{'+d.n+'}']));
  const ib = items.findIndex(d=>d.n.startsWith('Bono uniforme'));
  mac('GastoIdBase', String(ib)); mac('GastoValorBase', items[ib].v.toFixed(1));
  mac('GastoMax', String(Math.ceil(Math.max(...items.map(d=>d.v))*1.12/1000)*1000)); }
return out;`;

const r = new Function('DATOS', 'document', modelo + cuerpo)(DATOS, {getElementById: () => ({})});
const esc = s => String(s).replace(/%/g, '\\%');
fs.writeFileSync(path.join(AQUI, 'cifras.tex'),
  '% Generado por insumos/generar_insumos.js a partir de Code/resultados.json. No editar a mano.\n' +
  r.macros.map(([k, v]) => `\\newcommand{\\c${k}}{${esc(v)}}`).join('\n') + '\n');
for (const [k, filas] of Object.entries(r.dat))
  fs.writeFileSync(path.join(AQUI, k + '.dat'),
    filas.map(f => f.map(x => typeof x === 'number' ? +x.toFixed(4) : x).join('\t')).join('\n') + '\n');
console.log(`${r.macros.length} cifras y ${Object.keys(r.dat).length} archivos de datos`);
