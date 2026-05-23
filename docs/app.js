/* ===== Dashboard Application ===== */
(function () {
    'use strict';

    /* ---------- Color Palette ---------- */
    const COLORS = {
        cyan: { bg: 'rgba(6,182,212,0.15)', border: '#06b6d4' },
        indigo: { bg: 'rgba(99,102,241,0.15)', border: '#6366f1' },
        purple: { bg: 'rgba(168,85,247,0.15)', border: '#a855f7' },
        amber: { bg: 'rgba(245,158,11,0.15)', border: '#f59e0b' },
        red: { bg: 'rgba(239,68,68,0.15)', border: '#ef4444' },
        emerald: { bg: 'rgba(16,185,129,0.15)', border: '#10b981' },
        rose: { bg: 'rgba(244,63,94,0.15)', border: '#f43f5e' },
        sky: { bg: 'rgba(56,189,248,0.15)', border: '#38bdf8' },
        lime: { bg: 'rgba(132,204,22,0.15)', border: '#84cc16' },
        orange: { bg: 'rgba(251,146,60,0.15)', border: '#fb923c' },
    };
    const COLOR_ARR = Object.values(COLORS);

    const COUNTRY_COLORS = {};
    const COUNTRY_LIST = [
        'Argentina', 'Bolivia', 'Brasil', 'Chile', 'Colombia', 'Costa Rica', 'Cuba',
        'Ecuador', 'El Salvador', 'Guatemala', 'Haití', 'Honduras', 'México',
        'Nicaragua', 'Panamá', 'Paraguay', 'Perú', 'Rep. Dominicana', 'Uruguay', 'Venezuela'
    ];
    COUNTRY_LIST.forEach((c, i) => {
        COUNTRY_COLORS[c] = COLOR_ARR[i % COLOR_ARR.length];
    });

    /* ---------- Chart.js Defaults ---------- */
    Chart.defaults.color = '#94a3b8';
    Chart.defaults.borderColor = 'rgba(99,102,241,0.08)';
    Chart.defaults.font.family = "'Inter', system-ui, sans-serif";
    Chart.defaults.font.size = 12;
    Chart.defaults.plugins.legend.labels.usePointStyle = true;
    Chart.defaults.plugins.legend.labels.pointStyle = 'circle';
    Chart.defaults.plugins.legend.labels.padding = 16;
    Chart.defaults.plugins.tooltip.backgroundColor = 'rgba(15,23,42,0.92)';
    Chart.defaults.plugins.tooltip.titleFont = { weight: '600' };
    Chart.defaults.plugins.tooltip.padding = 12;
    Chart.defaults.plugins.tooltip.cornerRadius = 8;
    Chart.defaults.plugins.tooltip.borderColor = 'rgba(99,102,241,0.2)';
    Chart.defaults.plugins.tooltip.borderWidth = 1;
    Chart.defaults.elements.point.radius = 3;
    Chart.defaults.elements.point.hoverRadius = 6;
    Chart.defaults.elements.line.tension = 0.3;
    Chart.defaults.elements.line.borderWidth = 2.5;
    Chart.defaults.animation.duration = 800;

    /* ---------- Helpers ---------- */
    const charts = {};

    function makeChart(id, config) {
        if (charts[id]) charts[id].destroy();
        const ctx = document.getElementById(id);
        if (!ctx) return null;
        charts[id] = new Chart(ctx, config);
        return charts[id];
    }

    function uniqueSorted(arr) {
        return [...new Set(arr)].sort((a, b) => a - b);
    }

    function groupBy(data, key) {
        const map = {};
        data.forEach(r => {
            const k = r[key];
            if (!map[k]) map[k] = [];
            map[k].push(r);
        });
        return map;
    }

    /* ---------- Navigation ---------- */
    const navLinks = document.querySelectorAll('.nav-items a');
    const pages = document.querySelectorAll('.page');
    const sidebar = document.getElementById('sidebar');
    const menuToggle = document.getElementById('menuToggle');

    navLinks.forEach(link => {
        link.addEventListener('click', e => {
            e.preventDefault();
            const pageId = link.dataset.page;
            navLinks.forEach(l => l.classList.remove('active'));
            link.classList.add('active');
            pages.forEach(p => p.classList.remove('active'));
            document.getElementById('page-' + pageId).classList.add('active');
            sidebar.classList.remove('open');
            // Render charts lazily
            if (pageId === 'pobreza') renderPobreza();
            if (pageId === 'ingresos') renderIngresos();
            if (pageId === 'empleo') renderEmpleo();
            if (pageId === 'crecimiento') renderCrecimiento();
            if (pageId === 'desigualdad') renderDesigualdad();
            if (pageId === 'violencia') renderViolenciaPage();
        });
    });

    menuToggle.addEventListener('click', () => sidebar.classList.toggle('open'));

    /* ---------- Sub-tab Toggles ---------- */
    document.querySelectorAll('.sub-tabs').forEach(tabBar => {
        if (tabBar.id === 'concentracion-inner-tabs' || tabBar.id === 'ingpc-inner-tabs' || tabBar.id === 'inglab-inner-tabs') return;
        tabBar.querySelectorAll('.sub-tab').forEach(btn => {
            btn.addEventListener('click', () => {
                const subtab = btn.dataset.subtab;
                const parent = tabBar.closest('.page');
                tabBar.querySelectorAll('.sub-tab').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                parent.querySelectorAll('.sub-tab-content').forEach(c => c.classList.remove('active'));
                const targetId = tabBar.id.replace('-tabs', '') + '-' + subtab;
                const target = document.getElementById(targetId);
                if (target) target.classList.add('active');
                // Re-render on tab switch
                if (parent.id === 'page-pobreza') renderPobreza();
                if (parent.id === 'page-ingresos') renderIngresos();
                if (parent.id === 'page-empleo') renderEmpleo();
                if (parent.id === 'page-desigualdad') renderDesigualdad();
                if (parent.id === 'page-violencia') renderViolenciaPage();
            });
        });
    });

    /* ============================================================
       PAGE: INICIO
       ============================================================ */
    function renderInicio() {
        // Scorecards
        const scContainer = document.getElementById('scorecards');
        const pobSorted = DATA.seriesHistoricas.filter(r => r.indicador === 'Pobreza' && r.valor != null).sort((a, b) => b.anio - a.anio);
        const pobrezaVal = pobSorted.length ? pobSorted[0] : null;
        const extSorted = DATA.seriesHistoricas.filter(r => r.indicador === 'Pobreza extrema' && r.valor != null).sort((a, b) => b.anio - a.anio);
        const extremaVal = extSorted.length ? extSorted[0] : null;

        // Also get latest Gini from giniPanel
        const giniEc = DATA.giniPanel
            .filter(r => r.categoria === 'Ecuador' && r.valor != null)
            .sort((a, b) => b.ano - a.ano);
        const latestGini = giniEc.length ? giniEc[0] : null;

        // Employment scorecards
        const empNoAdecuado = DATA.empleoScorecard ? DATA.empleoScorecard.find(r => r.indicador === 'Empleo no adecuado') : null;
        const desempleo = DATA.empleoScorecard ? DATA.empleoScorecard.find(r => r.indicador === 'Desempleo') : null;

        // Top 1% income share
        const top1Data = DATA.widIngresoPercentiles
            .filter(r => r.percentil === 'Top 1%' && r['participacionEnElIngresoNacional(%)'] != null)
            .sort((a, b) => b.ano - a.ano);
        const latestTop1 = top1Data.length ? top1Data[0] : null;

        // Informalidad
        const infData = DATA.informalidadComponentes
            ? DATA.informalidadComponentes.filter(r => r.informal2 != null).sort((a, b) => b.anio - a.anio)
            : [];
        const latestInf = infData.length ? infData[0] : null;

        // Pobreza laboral
        const plData = DATA.pobrezaLaboral
            ? DATA.pobrezaLaboral.filter(r => r.tasaPobrezaPct != null).sort((a, b) => b.anio - a.anio)
            : [];
        const latestPL = plData.length ? plData[0] : null;

        const cards = [
            { icon: '<img src="icons/poverty.png" alt="" style="width:1.5em;height:1.5em;vertical-align:middle;">', label: 'Pobreza', value: pobrezaVal ? pobrezaVal.valor.toFixed(1) + '%' : '—', year: pobrezaVal ? pobrezaVal.anio : '' },
            { icon: '<img src="icons/extreme poverty.png" alt="" style="width:1.5em;height:1.5em;vertical-align:middle;">', label: 'Pobreza Extrema', value: extremaVal ? extremaVal.valor.toFixed(1) + '%' : '—', year: extremaVal ? extremaVal.anio : '' },
            { icon: '💼', label: 'Empleo no adecuado', value: empNoAdecuado ? empNoAdecuado.valor.toFixed(1) + '%' : '—', year: empNoAdecuado ? empNoAdecuado.anio : '' },
            { icon: '📊', label: 'Desempleo', value: desempleo ? desempleo.valor.toFixed(1) + '%' : '—', year: desempleo ? desempleo.anio : '' },
            { icon: '<img src="icons/informality.png" alt="" style="width:1.5em;height:1.5em;vertical-align:middle;">', label: 'Informalidad', value: latestInf ? latestInf.informal2.toFixed(1) + '%' : '—', year: latestInf ? latestInf.anio : '' },
            { icon: '<img src="icons/pobreza-laboral.png" alt="" style="width:1.5em;height:1.5em;vertical-align:middle;">', label: 'Pobreza Laboral', value: latestPL ? latestPL.tasaPobrezaPct.toFixed(1) + '%' : '—', year: latestPL ? latestPL.anio : '' },
            { icon: '<span style="display:inline-block;transform:rotate(-20deg)">⚖️</span>', label: 'Gini (Ecuador)', value: latestGini ? (+latestGini.valor).toFixed(3) : '—', year: latestGini ? latestGini.ano : '' },
            { icon: '💰', label: 'Top 1% Ingreso', value: latestTop1 ? latestTop1['participacionEnElIngresoNacional(%)'].toFixed(1) + '%' : '—', year: latestTop1 ? latestTop1.ano : '' },
        ];

        scContainer.innerHTML = cards.map(c => `
      <div class="card scorecard">
        <span class="sc-icon">${c.icon}</span>
        <div class="sc-value">${c.value}</div>
        <div class="sc-label">${c.label}</div>
        <div class="sc-year">${c.year}</div>
      </div>
    `).join('');

    }

    /* ============================================================
       PAGE: POBREZA
       ============================================================ */
    let pobrezaRendered = false;

    function renderPobreza() {
        const activeTab = document.querySelector('#pobreza-tabs .sub-tab.active');
        const tabId = activeTab ? activeTab.dataset.subtab : 'ultimo-ano';

        if (tabId === 'ultimo-ano') {
            renderPobrezaBarNivel();
            renderPobrezaEtnia();
            renderPobrezaBarSexo();
            renderPobrezaBarEducacion();
            renderPobrezaBarEdad();
            renderPobrezaBarRegion();
            setupProvTable();
        } else if (tabId === 'variaciones') {
            setupSigTable();
        } else {
            renderPobrezaHistCombined();
            renderPobrezaHistSexo();
            renderPobrezaNivel();
            renderPobrezaSexo();
            renderPobrezaEducacion();
            renderPobrezaEdad();
            renderPobrezaRegion();
        }
        pobrezaRendered = true;
    }

    function getSelectedPovIndicator() {
        return document.getElementById('pov-indicator').value;
    }

    // Nivel chart
    function renderPobrezaNivel() {
        const indicator = getSelectedPovIndicator();
        const filtered = DATA.pobrezaTableau.filter(r => r.indicador === indicator && r.valor != null);
        const byNivel = groupBy(filtered, 'nivel');
        const years = uniqueSorted(filtered.map(r => r.ano));
        const nivelColors = { 'Nacional': COLORS.cyan, 'Urbano': COLORS.indigo, 'Rural': COLORS.amber };

        const datasets = Object.entries(byNivel).map(([nivel, rows]) => {
            const c = nivelColors[nivel] || COLORS.purple;
            const map = {};
            rows.forEach(r => map[r.ano] = r.valor);
            return {
                label: nivel,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-pov-nivel', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Etnia bar chart — latest year
    function showNoData(canvasId) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return;
        const container = canvas.parentElement;
        makeChart(canvasId, { type: 'bar', data: { labels: [], datasets: [] }, options: { responsive: true, maintainAspectRatio: false } });
        // Overlay a message
        let msg = container.querySelector('.no-data-msg');
        if (!msg) {
            msg = document.createElement('div');
            msg.className = 'no-data-msg';
            msg.style.cssText = 'position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);color:var(--text-muted);font-size:0.95rem;font-weight:500;text-align:center;pointer-events:none;';
            container.appendChild(msg);
        }
        msg.textContent = 'Sin datos para este indicador';
        msg.style.display = 'block';
    }

    function clearNoData(canvasId) {
        const canvas = document.getElementById(canvasId);
        if (!canvas) return;
        const msg = canvas.parentElement.querySelector('.no-data-msg');
        if (msg) msg.style.display = 'none';
    }

    function renderPobrezaEtnia() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza' ? 'Pobreza' : indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaSexoEtnia.filter(r => r.tipoGrupo === 'etnia' && r.indicador === mapInd && r.valor != null);
        if (!data.length) {
            showNoData('chart-pov-etnia');
            return;
        }
        clearNoData('chart-pov-etnia');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.valor - a.valor);

        makeChart('chart-pov-etnia', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.grupo),
                datasets: [{
                    label: mapInd + ' (' + latestYear + ')',
                    data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border),
                    borderWidth: 1,
                    borderRadius: 6,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                scales: { x: { beginAtZero: true, ticks: { callback: v => v.toFixed(0) + '%' } } },
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: ctx => ctx.parsed.x.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Sexo chart — time series
    function renderPobrezaSexo() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza' ? 'Pobreza' : indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaSexoEtnia.filter(r => r.tipoGrupo === 'sexo' && r.indicador === mapInd && r.valor != null);
        if (!data.length) { showNoData('chart-pov-sexo'); return; }
        clearNoData('chart-pov-sexo');
        const byGrupo = groupBy(data, 'grupo');
        const years = uniqueSorted(data.map(r => r.anio));
        const sexColors = { 'Hombre': COLORS.cyan, 'Mujer': COLORS.rose };

        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = sexColors[g] || COLORS.indigo;
            const map = {};
            rows.forEach(r => map[r.anio] = r.valor);
            return {
                label: g,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-pov-sexo', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Provincial table
    function setupProvTable() {
        const years = uniqueSorted(DATA.pobrezaProvincial.map(r => r.anio));
        const sel = document.getElementById('prov-year');
        if (!sel.options.length) {
            years.forEach(y => {
                const opt = document.createElement('option');
                opt.value = y;
                opt.textContent = y;
                sel.appendChild(opt);
            });
            sel.value = years[years.length - 1];
            sel.addEventListener('change', renderProvTable);
        }
        renderProvTable();
    }

    function renderProvTable() {
        const year = +document.getElementById('prov-year').value;
        const data = DATA.pobrezaProvincial.filter(r => r.anio === year);
        const byProv = groupBy(data, 'provincia');
        const tbody = document.querySelector('#prov-table tbody');
        document.getElementById('prov-table-title').textContent = 'Pobreza Provincial — ' + year;

        const rows = Object.entries(byProv).map(([prov, rs]) => {
            const pob = rs.find(r => r.indicador === 'Pobreza');
            const ext = rs.find(r => r.indicador === 'Pobreza extrema');
            return { prov, pob: pob ? +pob.valor : null, ext: ext ? +ext.valor : null };
        }).sort((a, b) => (b.pob || 0) - (a.pob || 0));

        const maxPob = Math.max(...rows.map(r => r.pob || 0));

        tbody.innerHTML = rows.map(r => `
      <tr>
        <td>${r.prov}</td>
        <td>
          ${r.pob != null ? r.pob.toFixed(1) : '—'}
          <span class="prov-bar" style="width:${r.pob != null ? (r.pob / maxPob * 80) : 0}px"></span>
        </td>
        <td>${r.ext != null ? r.ext.toFixed(1) : '—'}</td>
      </tr>
    `).join('');
    }

    // Educacion chart — time series
    function renderPobrezaEducacion() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza' ? 'Pobreza' : indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaEducacion.filter(r => r.indicador === mapInd && r.valor != null);
        if (!data.length) { showNoData('chart-pov-educacion'); return; }
        clearNoData('chart-pov-educacion');
        const byNivel = groupBy(data, 'nivelEducativo');
        const years = uniqueSorted(data.map(r => r.anio));
        const educColors = {
            'Superior': COLORS.indigo,
            'Menos que superior': COLORS.amber
        };

        const datasets = Object.entries(byNivel).map(([nivel, rows]) => {
            const c = educColors[nivel] || COLORS.cyan;
            const map = {};
            rows.forEach(r => map[r.anio] = r.valor);
            return {
                label: nivel,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-pov-educacion', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Edad chart — time series
    function renderPobrezaEdad() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza' ? 'Pobreza' : indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaEdad.filter(r => r.indicador === mapInd && r.valor != null);
        if (!data.length) { showNoData('chart-pov-edad'); return; }
        clearNoData('chart-pov-edad');
        const byGrupo = groupBy(data, 'grupoEtario');
        const years = uniqueSorted(data.map(r => r.anio));
        const ageColors = {
            'Niños (0-17)': COLORS.rose,
            'Jóvenes (18-29)': COLORS.amber,
            'Adultos (30-64)': COLORS.indigo,
            'Adultos mayores (65+)': COLORS.purple
        };

        const datasets = Object.entries(byGrupo).map(([grupo, rows]) => {
            const c = ageColors[grupo] || COLORS.cyan;
            const map = {};
            rows.forEach(r => map[r.anio] = r.valor);
            return {
                label: grupo,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-pov-edad', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Region chart — time series
    function renderPobrezaRegion() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza' ? 'Pobreza' : indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaRegion.filter(r => r.indicador === mapInd && r.valor != null);
        if (!data.length) { showNoData('chart-pov-region'); return; }
        clearNoData('chart-pov-region');
        const byRegion = groupBy(data, 'region');
        const years = uniqueSorted(data.map(r => r.anio));
        const regionColors = {
            'Costa': COLORS.cyan,
            'Sierra': COLORS.indigo,
            'Oriente': COLORS.amber
        };

        const datasets = Object.entries(byRegion).map(([region, rows]) => {
            const c = regionColors[region] || COLORS.purple;
            const map = {};
            rows.forEach(r => map[r.anio] = r.valor);
            return {
                label: region,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-pov-region', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Statistical variation table — national level only
    function setupSigTable() {
        renderSigTable();
    }

    function renderSigTable() {
        const raw = DATA.variacionPobrezaSignificancia;
        if (!raw || !raw.length) {
            document.querySelector('#sig-table tbody').innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-muted)">Sin datos de significancia</td></tr>';
            return;
        }
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza' ? 'Pobreza' : indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const rows = raw
            .filter(r => r.dimension === 'Nacional' && r.nivel === 'Nacional' && r.indicador === mapInd)
            .sort((a, b) => b.anio - a.anio);

        const tbody = document.querySelector('#sig-table tbody');
        tbody.innerHTML = rows.map(r => {
            const sigClass = r.significativo && r.significativo.startsWith('Sí') ? 'sig-yes' :
                r.significativo === 'No' ? 'sig-no' : 'sig-maybe';
            return `
            <tr>
                <td>${r.anio}</td>
                <td>${r.indicador}</td>
                <td>${r.valor != null ? r.valor.toFixed(2) : '—'}</td>
                <td>${r.valorAnterior != null ? r.valorAnterior.toFixed(2) : '—'}</td>
                <td style="color:${r.variacionPp < 0 ? '#10b981' : '#ef4444'}">${r.variacionPp != null ? (r.variacionPp > 0 ? '+' : '') + r.variacionPp.toFixed(2) : '—'}</td>
                <td><span class="${sigClass}">${r.significativo || '—'}</span></td>
            </tr>
            `;
        }).join('');
    }

    // Bind indicator filter — re-render whichever sub-tab is active
    document.getElementById('pov-indicator').addEventListener('change', () => {
        renderPobreza();
    });

    // ---- Pobreza Último Año: Bar Charts ----
    function renderPobrezaBarNivel() {
        const indicator = getSelectedPovIndicator();
        const filtered = DATA.pobrezaTableau.filter(r => r.indicador === indicator && r.valor != null);
        const years = uniqueSorted(filtered.map(r => r.ano));
        const latestYear = years.length ? years[years.length - 1] : null;
        if (!latestYear) { makeChart('chart-pov-bar-nivel', { type: 'bar', data: { labels: [], datasets: [] } }); return; }
        const latest = filtered.filter(r => r.ano === latestYear);
        document.getElementById('pov-bar-nivel-title').textContent = indicator + ' por Nivel (' + latestYear + ')';
        makeChart('chart-pov-bar-nivel', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.nivel),
                datasets: [{
                    label: indicator, data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border),
                    borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(1) + '%' } } } }
        });
    }

    function renderPobrezaBarSexo() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaSexoEtnia.filter(r => r.tipoGrupo === 'sexo' && r.indicador === mapInd && r.valor != null);
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years.length ? years[years.length - 1] : null;
        if (!latestYear) { showNoData('chart-pov-bar-sexo'); return; }
        clearNoData('chart-pov-bar-sexo');
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('pov-bar-sexo-title').textContent = indicator + ' por Sexo (' + latestYear + ')';
        makeChart('chart-pov-bar-sexo', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.grupo), datasets: [{
                    label: indicator, data: latest.map(r => +r.valor),
                    backgroundColor: [COLORS.cyan.border + '99', COLORS.purple.border + '99'],
                    borderColor: [COLORS.cyan.border, COLORS.purple.border], borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(1) + '%' } } } }
        });
    }

    function renderPobrezaBarEducacion() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaEducacion.filter(r => r.indicador === mapInd && r.valor != null);
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years.length ? years[years.length - 1] : null;
        if (!latestYear) { showNoData('chart-pov-bar-educacion'); return; }
        clearNoData('chart-pov-bar-educacion');
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('pov-bar-educ-title').textContent = indicator + ' por Educación (' + latestYear + ')';
        makeChart('chart-pov-bar-educacion', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.nivelEducativo), datasets: [{
                    label: indicator, data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(1) + '%' } } } }
        });
    }

    function renderPobrezaBarEdad() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaEdad.filter(r => r.indicador === mapInd && r.valor != null);
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years.length ? years[years.length - 1] : null;
        if (!latestYear) { showNoData('chart-pov-bar-edad'); return; }
        clearNoData('chart-pov-bar-edad');
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('pov-bar-edad-title').textContent = indicator + ' por Grupo Etario (' + latestYear + ')';
        makeChart('chart-pov-bar-edad', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.grupoEtario), datasets: [{
                    label: indicator, data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(1) + '%' } } } }
        });
    }

    function renderPobrezaBarRegion() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaRegion.filter(r => r.indicador === mapInd && r.valor != null);
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years.length ? years[years.length - 1] : null;
        if (!latestYear) { showNoData('chart-pov-bar-region'); return; }
        clearNoData('chart-pov-bar-region');
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('pov-bar-region-title').textContent = indicator + ' por Región (' + latestYear + ')';
        makeChart('chart-pov-bar-region', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.region), datasets: [{
                    label: indicator, data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(1) + '%' } } } }
        });
    }

    // ---- Pobreza Serie Histórica: Combined line charts ----
    function renderPobrezaHistCombined() {
        const pob = DATA.seriesHistoricas.filter(r => r.indicador === 'Pobreza' && r.valor != null);
        const ext = DATA.seriesHistoricas.filter(r => r.indicador === 'Pobreza extrema' && r.valor != null);
        const years = uniqueSorted([...pob, ...ext].map(r => r.anio));
        const pobMap = {}; pob.forEach(r => pobMap[r.anio] = r.valor);
        const extMap = {}; ext.forEach(r => extMap[r.anio] = r.valor);
        makeChart('chart-pov-hist-combined', {
            type: 'line',
            data: {
                labels: years, datasets: [
                    { label: 'Pobreza', data: years.map(y => pobMap[y] ?? null), borderColor: COLORS.cyan.border, backgroundColor: COLORS.cyan.bg, fill: false, spanGaps: true },
                    { label: 'Pobreza extrema', data: years.map(y => extMap[y] ?? null), borderColor: COLORS.red.border, backgroundColor: COLORS.red.bg, fill: false, spanGaps: true }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderPobrezaHistSexo() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaSexoEtnia.filter(r => r.tipoGrupo === 'sexo' && r.indicador === mapInd && r.valor != null);
        if (!data.length) { showNoData('chart-pov-hist-sexo'); return; }
        clearNoData('chart-pov-hist-sexo');
        const byGrupo = groupBy(data, 'grupo');
        const years = uniqueSorted(data.map(r => r.anio));
        const sexColors = { 'Hombre': COLORS.cyan, 'Mujer': COLORS.rose };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = sexColors[g] || COLORS.indigo;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-pov-hist-sexo', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    /* ============================================================
       PAGE: INGRESOS
       ============================================================ */
    let ingresosRendered = false;
    let ingpcInnerInit = false;

    function renderIngresos() {
        const activeTab = document.querySelector('#ingresos-tabs .sub-tab.active');
        const tabId = activeTab ? activeTab.dataset.subtab : 'percapita';

        if (tabId === 'percapita') {
            initIngpcInnerTabs();
            renderIngpcInner();
        } else if (tabId === 'laboral') {
            initInglabInnerTabs();
            renderInglabInner();
        } else if (tabId === 'descomposicion') {
            renderDecomposicion();
        }
        ingresosRendered = true;
    }

    function initIngpcInnerTabs() {
        if (ingpcInnerInit) return;
        const bar = document.getElementById('ingpc-inner-tabs');
        if (!bar) return;
        bar.querySelectorAll('.sub-tab').forEach(btn => {
            btn.addEventListener('click', () => {
                bar.querySelectorAll('.sub-tab').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                document.querySelectorAll('.ingpc-panel').forEach(p => {
                    p.style.display = 'none';
                    p.classList.remove('active');
                });
                const panel = document.getElementById('ingpc-panel-' + btn.dataset.inner);
                if (panel) { panel.style.display = ''; panel.classList.add('active'); }
                renderIngpcInner();
            });
        });
        ingpcInnerInit = true;
    }

    function renderIngpcInner() {
        const activeBtn = document.querySelector('#ingpc-inner-tabs .sub-tab.active');
        const innerId = activeBtn ? activeBtn.dataset.inner : 'ultimo-ano';
        if (innerId === 'ultimo-ano') {
            renderIngBarArea();
            renderIngBarEtnia();
            renderIngBarSexo();
            renderIngBarEducacion();
            renderIngBarEdad();
            renderIngBarRegion();
            setupIngProvTable();
        } else {
            renderIngSeries();
            renderIngAreaSerie();
            renderIngSexoSerie();
            renderIngEtniaSerie();
            renderIngEducacionSerie();
            renderIngEdadSerie();
            renderIngRegionSerie();
        }
    }

    function fmtUSD(v) { return '$' + v.toFixed(0); }

    // ── Series: nominal + deflated ────────────────────────────────
    function renderIngSeries() {
        const data = DATA.ingresosSeries;
        if (!data || !data.length) return;
        const nom = data.filter(r => r.tipo === 'Nominal');
        const real = data.filter(r => r.tipo === 'Real (precios 2000)');
        const years = uniqueSorted([...nom, ...real].map(r => r.anio));
        const nomMap = {}; nom.forEach(r => nomMap[r.anio] = r.valor);
        const realMap = {}; real.forEach(r => realMap[r.anio] = r.valor);
        makeChart('chart-ing-series', {
            type: 'line',
            data: {
                labels: years, datasets: [
                    { label: 'Nominal', data: years.map(y => nomMap[y] ?? null), borderColor: COLORS.cyan.border, backgroundColor: COLORS.cyan.bg, fill: false, spanGaps: true },
                    { label: 'Real (precios 2000)', data: years.map(y => realMap[y] ?? null), borderColor: COLORS.amber.border, backgroundColor: COLORS.amber.bg, fill: false, spanGaps: true }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } }
            }
        });
    }

    // ── Serie Histórica by Nivel (area) ───────────────────────────
    function renderIngAreaSerie() {
        const data = DATA.ingresosArea;
        if (!data || !data.length) return;
        const byNivel = groupBy(data, 'nivel');
        const years = uniqueSorted(data.map(r => r.anio));
        const nivelColors = { 'Nacional': COLORS.cyan, 'Urbano': COLORS.indigo, 'Rural': COLORS.amber };
        const datasets = Object.entries(byNivel).map(([nivel, rows]) => {
            const c = nivelColors[nivel] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: nivel, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-ing-area', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    // ── Serie Histórica by Sexo ───────────────────────────────────
    function renderIngSexoSerie() {
        const data = (DATA.ingresosSexoEtnia || []).filter(r => r.tipoGrupo === 'sexo');
        if (!data.length) return;
        const byGrupo = groupBy(data, 'grupo');
        const years = uniqueSorted(data.map(r => r.anio));
        const sexColors = { 'Hombre': COLORS.cyan, 'Mujer': COLORS.rose };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = sexColors[g] || COLORS.indigo;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-ing-sexo', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    // ── Serie Histórica by Etnia ──────────────────────────────────
    function renderIngEtniaSerie() {
        const data = (DATA.ingresosSexoEtnia || []).filter(r => r.tipoGrupo === 'etnia');
        if (!data.length) return;
        const byGrupo = groupBy(data, 'grupo');
        const years = uniqueSorted(data.map(r => r.anio));
        const etniaColors = { 'Indígena': COLORS.amber, 'Afroecuatoriano': COLORS.rose, 'Montuvio': COLORS.emerald, 'Mestizo': COLORS.cyan, 'Blanco': COLORS.indigo, 'Otro': COLORS.purple };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = etniaColors[g] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-ing-etnia', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    // ── Serie Histórica by Educación ──────────────────────────────
    function renderIngEducacionSerie() {
        const data = DATA.ingresosEducacion;
        if (!data || !data.length) return;
        const byNivel = groupBy(data, 'nivelEducativo');
        const years = uniqueSorted(data.map(r => r.anio));
        const educColors = { 'Superior': COLORS.indigo, 'Menos que superior': COLORS.amber };
        const datasets = Object.entries(byNivel).map(([nivel, rows]) => {
            const c = educColors[nivel] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: nivel, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-ing-educacion', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    // ── Serie Histórica by Edad ───────────────────────────────────
    function renderIngEdadSerie() {
        const data = DATA.ingresosEdad;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'grupoEtario');
        const years = uniqueSorted(data.map(r => r.anio));
        const ageColors = { 'Niños (0-17)': COLORS.rose, 'Jóvenes (18-29)': COLORS.amber, 'Adultos (30-64)': COLORS.indigo, 'Adultos mayores (65+)': COLORS.purple };
        const datasets = Object.entries(byGrupo).map(([grupo, rows]) => {
            const c = ageColors[grupo] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: grupo, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-ing-edad', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    // ── Serie Histórica by Región ─────────────────────────────────
    function renderIngRegionSerie() {
        const data = DATA.ingresosRegion;
        if (!data || !data.length) return;
        const byRegion = groupBy(data, 'region');
        const years = uniqueSorted(data.map(r => r.anio));
        const regionColors = { 'Costa': COLORS.cyan, 'Sierra': COLORS.indigo, 'Oriente': COLORS.amber };
        const datasets = Object.entries(byRegion).map(([region, rows]) => {
            const c = regionColors[region] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: region, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-ing-region', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    // ── Bar charts: Último Año ────────────────────────────────────
    function renderIngBarArea() {
        const data = DATA.ingresosArea;
        if (!data || !data.length) return;
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.valor - a.valor);
        document.getElementById('ing-bar-area-title').textContent = 'Ingreso per Cápita por Nivel (' + latestYear + ')';
        makeChart('chart-ing-bar-area', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.nivel), datasets: [{
                    label: 'Ingreso per cápita', data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderIngBarEtnia() {
        const data = (DATA.ingresosSexoEtnia || []).filter(r => r.tipoGrupo === 'etnia');
        if (!data.length) { showNoData('chart-ing-bar-etnia'); return; }
        clearNoData('chart-ing-bar-etnia');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.valor - a.valor);
        document.getElementById('ing-bar-etnia-title').textContent = 'Ingreso per Cápita por Etnia (' + latestYear + ')';
        makeChart('chart-ing-bar-etnia', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.grupo), datasets: [{
                    label: 'Ingreso per cápita', data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, indexAxis: 'y', plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.x.toFixed(2) } } }, scales: { x: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderIngBarSexo() {
        const data = (DATA.ingresosSexoEtnia || []).filter(r => r.tipoGrupo === 'sexo');
        if (!data.length) { showNoData('chart-ing-bar-sexo'); return; }
        clearNoData('chart-ing-bar-sexo');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('ing-bar-sexo-title').textContent = 'Ingreso per Cápita por Sexo (' + latestYear + ')';
        makeChart('chart-ing-bar-sexo', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.grupo), datasets: [{
                    label: 'Ingreso per cápita', data: latest.map(r => +r.valor),
                    backgroundColor: [COLORS.cyan.border + '99', COLORS.purple.border + '99'],
                    borderColor: [COLORS.cyan.border, COLORS.purple.border], borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderIngBarEducacion() {
        const data = DATA.ingresosEducacion;
        if (!data || !data.length) { showNoData('chart-ing-bar-educacion'); return; }
        clearNoData('chart-ing-bar-educacion');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('ing-bar-educ-title').textContent = 'Ingreso per Cápita por Educación (' + latestYear + ')';
        makeChart('chart-ing-bar-educacion', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.nivelEducativo), datasets: [{
                    label: 'Ingreso per cápita', data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderIngBarEdad() {
        const data = DATA.ingresosEdad;
        if (!data || !data.length) { showNoData('chart-ing-bar-edad'); return; }
        clearNoData('chart-ing-bar-edad');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('ing-bar-edad-title').textContent = 'Ingreso per Cápita por Grupo Etario (' + latestYear + ')';
        makeChart('chart-ing-bar-edad', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.grupoEtario), datasets: [{
                    label: 'Ingreso per cápita', data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderIngBarRegion() {
        const data = DATA.ingresosRegion;
        if (!data || !data.length) { showNoData('chart-ing-bar-region'); return; }
        clearNoData('chart-ing-bar-region');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.valor - a.valor);
        document.getElementById('ing-bar-region-title').textContent = 'Ingreso per Cápita por Región (' + latestYear + ')';
        makeChart('chart-ing-bar-region', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.region), datasets: [{
                    label: 'Ingreso per cápita', data: latest.map(r => +r.valor),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    // ── Provincial table ──────────────────────────────────────────
    function setupIngProvTable() {
        const data = DATA.ingresosProvincial;
        if (!data || !data.length) return;
        const years = uniqueSorted(data.map(r => r.anio));
        const sel = document.getElementById('ing-prov-year');
        if (!sel.options.length) {
            years.forEach(y => {
                const opt = document.createElement('option');
                opt.value = y; opt.textContent = y;
                sel.appendChild(opt);
            });
            sel.value = years[years.length - 1];
            sel.addEventListener('change', renderIngProvTable);
        }
        renderIngProvTable();
    }

    function renderIngProvTable() {
        const year = +document.getElementById('ing-prov-year').value;
        const data = (DATA.ingresosProvincial || []).filter(r => r.anio === year);
        const tbody = document.querySelector('#ing-prov-table tbody');
        document.getElementById('ing-prov-table-title').textContent = 'Ingreso per Cápita Provincial — ' + year;

        const rows = data.map(r => ({ prov: r.provincia, val: +r.valor }))
            .sort((a, b) => b.val - a.val);
        const maxVal = Math.max(...rows.map(r => r.val));

        tbody.innerHTML = rows.map(r => `
      <tr>
        <td>${r.prov}</td>
        <td>
          $${r.val.toFixed(2)}
          <span class="prov-bar" style="width:${(r.val / maxVal * 80)}px"></span>
        </td>
      </tr>
    `).join('');
    }

    // ── Descomposición del Ingreso ───────────────────────────────
    function renderDecomposicion() {
        renderDecompChart('chart-decomp-nacional', DATA.giniDecomposition, null);
        const cuartiles = DATA.giniDecompositionCuartiles;
        if (cuartiles && cuartiles.length) {
            for (let q = 1; q <= 4; q++) {
                renderDecompChart('chart-decomp-q' + q, cuartiles, q);
            }
        }
    }

    function renderDecompChart(canvasId, data, quartile) {
        if (!data || !data.length) return;
        const filtered = quartile ? data.filter(r => r.q === quartile) : data;
        if (!filtered.length) return;
        const years = filtered.map(r => r.t);
        const laboral = filtered.map(r => r.slaboral != null ? +r.slaboral : null);
        const rentas = filtered.map(r => r.srentas != null ? +r.srentas : null);
        const remesas = filtered.map(r => r.sremesas != null ? +r.sremesas : null);
        const bono = filtered.map(r => r.sbono != null ? +r.sbono : null);

        makeChart(canvasId, {
            type: 'bar',
            data: {
                labels: years,
                datasets: [
                    { label: 'Ingreso laboral', data: laboral, backgroundColor: COLORS.cyan.border + 'cc', borderColor: COLORS.cyan.border, borderWidth: 1 },
                    { label: 'Rentas', data: rentas, backgroundColor: COLORS.amber.border + 'cc', borderColor: COLORS.amber.border, borderWidth: 1 },
                    { label: 'Remesas', data: remesas, backgroundColor: COLORS.indigo.border + 'cc', borderColor: COLORS.indigo.border, borderWidth: 1 },
                    { label: 'BDH', data: bono, backgroundColor: COLORS.emerald.border + 'cc', borderColor: COLORS.emerald.border, borderWidth: 1 },
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: {
                    x: { stacked: true },
                    y: { stacked: true, max: 100, ticks: { callback: v => v + '%' } }
                },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    // ── Ingreso Laboral inner tabs and rendering ────────────────
    let inglabInnerInit = false;

    function initInglabInnerTabs() {
        if (inglabInnerInit) return;
        const bar = document.getElementById('inglab-inner-tabs');
        if (!bar) return;
        bar.querySelectorAll('.sub-tab').forEach(btn => {
            btn.addEventListener('click', () => {
                bar.querySelectorAll('.sub-tab').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                document.querySelectorAll('.inglab-panel').forEach(p => {
                    p.style.display = 'none';
                    p.classList.remove('active');
                });
                const panel = document.getElementById('inglab-panel-' + btn.dataset.inner);
                if (panel) { panel.style.display = ''; panel.classList.add('active'); }
                renderInglabInner();
            });
        });
        inglabInnerInit = true;
    }

    function renderInglabInner() {
        const activeBtn = document.querySelector('#inglab-inner-tabs .sub-tab.active');
        const innerId = activeBtn ? activeBtn.dataset.inner : 'ultimo-ano';
        if (innerId === 'ultimo-ano') {
            renderInglabBarArea();
            renderInglabBarEtnia();
            renderInglabBarSexo();
            renderInglabBarEducacion();
            renderInglabBarEdad();
            renderInglabBarRegion();
            setupInglabProvTable();
        } else {
            renderInglabSeries();
            renderInglabAreaSerie();
            renderInglabSexoSerie();
            renderInglabEtniaSerie();
            renderInglabEducacionSerie();
            renderInglabEdadSerie();
            renderInglabRegionSerie();
        }
    }

    // ── Series: nominal + real + salario básico ───────────────────
    function renderInglabSeries() {
        const data = DATA.inglabSeries;
        if (!data || !data.length) return;
        const nom = data.filter(r => r.tipo === 'Nominal');
        const real = data.filter(r => r.tipo === 'Real (precios 2000)');
        const sbu = data.filter(r => r.tipo === 'Salario básico');
        const years = uniqueSorted([...nom, ...real, ...sbu].map(r => r.anio));
        const nomMap = {}; nom.forEach(r => nomMap[r.anio] = r.valor);
        const realMap = {}; real.forEach(r => realMap[r.anio] = r.valor);
        const sbuMap = {}; sbu.forEach(r => sbuMap[r.anio] = r.valor);
        makeChart('chart-inglab-series', {
            type: 'line',
            data: {
                labels: years, datasets: [
                    { label: 'Nominal', data: years.map(y => nomMap[y] ?? null), borderColor: COLORS.cyan.border, backgroundColor: COLORS.cyan.bg, fill: false, spanGaps: true },
                    { label: 'Real (precios 2000)', data: years.map(y => realMap[y] ?? null), borderColor: COLORS.amber.border, backgroundColor: COLORS.amber.bg, fill: false, spanGaps: true },
                    { label: 'Salario básico', data: years.map(y => sbuMap[y] ?? null), borderColor: COLORS.emerald.border, backgroundColor: COLORS.emerald.bg, fill: false, spanGaps: true, borderDash: [6, 3] }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } }
            }
        });
    }

    function renderInglabAreaSerie() {
        const data = DATA.inglabArea;
        if (!data || !data.length) return;
        const byNivel = groupBy(data, 'nivel');
        const years = uniqueSorted(data.map(r => r.anio));
        const nivelColors = { 'Nacional': COLORS.cyan, 'Urbano': COLORS.indigo, 'Rural': COLORS.amber };
        const datasets = Object.entries(byNivel).map(([nivel, rows]) => {
            const c = nivelColors[nivel] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: nivel, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-inglab-area', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    function renderInglabSexoSerie() {
        const data = (DATA.inglabSexoEtnia || []).filter(r => r.tipoGrupo === 'sexo');
        if (!data.length) return;
        const byGrupo = groupBy(data, 'grupo');
        const years = uniqueSorted(data.map(r => r.anio));
        const sexColors = { 'Hombre': COLORS.cyan, 'Mujer': COLORS.rose };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = sexColors[g] || COLORS.indigo;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-inglab-sexo', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    function renderInglabEtniaSerie() {
        const data = (DATA.inglabSexoEtnia || []).filter(r => r.tipoGrupo === 'etnia');
        if (!data.length) return;
        const byGrupo = groupBy(data, 'grupo');
        const years = uniqueSorted(data.map(r => r.anio));
        const etniaColors = { 'Indígena': COLORS.amber, 'Afroecuatoriano': COLORS.rose, 'Montuvio': COLORS.emerald, 'Mestizo': COLORS.cyan, 'Blanco': COLORS.indigo, 'Otro': COLORS.purple };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = etniaColors[g] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-inglab-etnia', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    function renderInglabEducacionSerie() {
        const data = DATA.inglabEducacion;
        if (!data || !data.length) return;
        const byNivel = groupBy(data, 'nivelEducativo');
        const years = uniqueSorted(data.map(r => r.anio));
        const educColors = { 'Superior': COLORS.indigo, 'Menos que superior': COLORS.amber };
        const datasets = Object.entries(byNivel).map(([nivel, rows]) => {
            const c = educColors[nivel] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: nivel, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-inglab-educacion', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    function renderInglabEdadSerie() {
        const data = DATA.inglabEdad;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'grupoEtario');
        const years = uniqueSorted(data.map(r => r.anio));
        const ageColors = { 'Niños (0-17)': COLORS.rose, 'Jóvenes (18-29)': COLORS.amber, 'Adultos (30-64)': COLORS.indigo, 'Adultos mayores (65+)': COLORS.purple };
        const datasets = Object.entries(byGrupo).map(([grupo, rows]) => {
            const c = ageColors[grupo] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: grupo, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-inglab-edad', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    function renderInglabRegionSerie() {
        const data = DATA.inglabRegion;
        if (!data || !data.length) return;
        const byRegion = groupBy(data, 'region');
        const years = uniqueSorted(data.map(r => r.anio));
        const regionColors = { 'Costa': COLORS.cyan, 'Sierra': COLORS.indigo, 'Oriente': COLORS.amber };
        const datasets = Object.entries(byRegion).map(([region, rows]) => {
            const c = regionColors[region] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.valor);
            return { label: region, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-inglab-region', {
            type: 'line', data: { labels: years, datasets },
            options: { responsive: true, maintainAspectRatio: false, scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v } } }, plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } } } }
        });
    }

    // ── Bar charts: Último Año (Ingreso Laboral) ──────────────────
    function renderInglabBarArea() {
        const data = DATA.inglabArea;
        if (!data || !data.length) return;
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.valor - a.valor);
        document.getElementById('inglab-bar-area-title').textContent = 'Ingreso Laboral por Nivel (' + latestYear + ')';
        makeChart('chart-inglab-bar-area', {
            type: 'bar',
            data: { labels: latest.map(r => r.nivel), datasets: [{ label: 'Ingreso laboral', data: latest.map(r => +r.valor), backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'), borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderInglabBarEtnia() {
        const data = (DATA.inglabSexoEtnia || []).filter(r => r.tipoGrupo === 'etnia');
        if (!data.length) { showNoData('chart-inglab-bar-etnia'); return; }
        clearNoData('chart-inglab-bar-etnia');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.valor - a.valor);
        document.getElementById('inglab-bar-etnia-title').textContent = 'Ingreso Laboral por Etnia (' + latestYear + ')';
        makeChart('chart-inglab-bar-etnia', {
            type: 'bar',
            data: { labels: latest.map(r => r.grupo), datasets: [{ label: 'Ingreso laboral', data: latest.map(r => +r.valor), backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'), borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6 }] },
            options: { responsive: true, maintainAspectRatio: false, indexAxis: 'y', plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.x.toFixed(2) } } }, scales: { x: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderInglabBarSexo() {
        const data = (DATA.inglabSexoEtnia || []).filter(r => r.tipoGrupo === 'sexo');
        if (!data.length) { showNoData('chart-inglab-bar-sexo'); return; }
        clearNoData('chart-inglab-bar-sexo');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('inglab-bar-sexo-title').textContent = 'Ingreso Laboral por Sexo (' + latestYear + ')';
        makeChart('chart-inglab-bar-sexo', {
            type: 'bar',
            data: { labels: latest.map(r => r.grupo), datasets: [{ label: 'Ingreso laboral', data: latest.map(r => +r.valor), backgroundColor: [COLORS.cyan.border + '99', COLORS.purple.border + '99'], borderColor: [COLORS.cyan.border, COLORS.purple.border], borderWidth: 1, borderRadius: 6 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderInglabBarEducacion() {
        const data = DATA.inglabEducacion;
        if (!data || !data.length) { showNoData('chart-inglab-bar-educacion'); return; }
        clearNoData('chart-inglab-bar-educacion');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('inglab-bar-educ-title').textContent = 'Ingreso Laboral por Educación (' + latestYear + ')';
        makeChart('chart-inglab-bar-educacion', {
            type: 'bar',
            data: { labels: latest.map(r => r.nivelEducativo), datasets: [{ label: 'Ingreso laboral', data: latest.map(r => +r.valor), backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'), borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderInglabBarEdad() {
        const data = DATA.inglabEdad;
        if (!data || !data.length) { showNoData('chart-inglab-bar-edad'); return; }
        clearNoData('chart-inglab-bar-edad');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        document.getElementById('inglab-bar-edad-title').textContent = 'Ingreso Laboral por Grupo Etario (' + latestYear + ')';
        makeChart('chart-inglab-bar-edad', {
            type: 'bar',
            data: { labels: latest.map(r => r.grupoEtario), datasets: [{ label: 'Ingreso laboral', data: latest.map(r => +r.valor), backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'), borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    function renderInglabBarRegion() {
        const data = DATA.inglabRegion;
        if (!data || !data.length) { showNoData('chart-inglab-bar-region'); return; }
        clearNoData('chart-inglab-bar-region');
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.valor - a.valor);
        document.getElementById('inglab-bar-region-title').textContent = 'Ingreso Laboral por Región (' + latestYear + ')';
        makeChart('chart-inglab-bar-region', {
            type: 'bar',
            data: { labels: latest.map(r => r.region), datasets: [{ label: 'Ingreso laboral', data: latest.map(r => +r.valor), backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'), borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6 }] },
            options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.y.toFixed(2) } } }, scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v } } } }
        });
    }

    // ── Provincial table (Ingreso Laboral) ─────────────────────────
    function setupInglabProvTable() {
        const data = DATA.inglabProvincial;
        if (!data || !data.length) return;
        const years = uniqueSorted(data.map(r => r.anio));
        const sel = document.getElementById('inglab-prov-year');
        if (!sel.options.length) {
            years.forEach(y => {
                const opt = document.createElement('option');
                opt.value = y; opt.textContent = y;
                sel.appendChild(opt);
            });
            sel.value = years[years.length - 1];
            sel.addEventListener('change', renderInglabProvTable);
        }
        renderInglabProvTable();
    }

    function renderInglabProvTable() {
        const year = +document.getElementById('inglab-prov-year').value;
        const data = (DATA.inglabProvincial || []).filter(r => r.anio === year);
        const tbody = document.querySelector('#inglab-prov-table tbody');
        document.getElementById('inglab-prov-table-title').textContent = 'Ingreso Laboral Provincial — ' + year;

        const rows = data.map(r => ({ prov: r.provincia, val: +r.valor }))
            .sort((a, b) => b.val - a.val);
        const maxVal = Math.max(...rows.map(r => r.val));

        tbody.innerHTML = rows.map(r => `
      <tr>
        <td>${r.prov}</td>
        <td>
          $${r.val.toFixed(2)}
          <span class="prov-bar" style="width:${(r.val / maxVal * 80)}px"></span>
        </td>
      </tr>
    `).join('');
    }

    /* ============================================================
       PAGE: EMPLEO
       ============================================================ */
    function renderEmpleo() {
        const activeTab = document.querySelector('#empleo-tabs .sub-tab.active');
        const tabId = activeTab ? activeTab.dataset.subtab : 'empleo-main';

        if (tabId === 'empleo-main') {
            renderEmpleoSeries();
            renderEmpleoBarCharts();
            renderEmpleoSigTable();
        } else if (tabId === 'empleo-informalidad') {
            renderInformalidad();
        } else if (tabId === 'empleo-pobreza-laboral') {
            renderPobrezaLaboralPage();
        }
    }

    // Employment bar charts — último año disaggregations
    function renderEmpleoBarCharts() {
        const data = DATA.empleoDemografico;
        if (!data || !data.length) return;
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);

        function barChart(canvasId, tipoCat) {
            const rows = latest.filter(r => r.tipoCategoria === tipoCat && r.empleoAdecuado != null);
            if (!rows.length) return;
            rows.sort((a, b) => b.empleoAdecuado - a.empleoAdecuado);
            makeChart(canvasId, {
                type: 'bar',
                data: {
                    labels: rows.map(r => r.categoria),
                    datasets: [{
                        label: 'Empleo adecuado (' + latestYear + ')',
                        data: rows.map(r => +r.empleoAdecuado),
                        backgroundColor: rows.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                        borderColor: rows.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border),
                        borderWidth: 1, borderRadius: 6,
                    }]
                },
                options: {
                    responsive: true, maintainAspectRatio: false,
                    indexAxis: 'y',
                    scales: { x: { beginAtZero: true, ticks: { callback: v => v.toFixed(0) + '%' } } },
                    plugins: {
                        legend: { display: false },
                        tooltip: { callbacks: { label: ctx => ctx.parsed.x.toFixed(1) + '%' } }
                    }
                }
            });
        }
        barChart('chart-empleo-bar-area', 'area');
        barChart('chart-empleo-bar-etnia', 'etnia');
        barChart('chart-empleo-bar-sexo', 'sexo');
        barChart('chart-empleo-bar-educacion', 'educacion');
        barChart('chart-empleo-bar-edad', 'edad');
    }

    // Employment time series
    function renderEmpleoSeries() {
        const data = DATA.empleoSeries.filter(r => r.indicador !== 'Empleo no adecuado');
        const byIndicador = groupBy(data, 'indicador');
        const years = uniqueSorted(data.map(r => r.anio));
        const empleoColors = {
            'Empleo adecuado': COLORS.cyan,
            'Desempleo': COLORS.red
        };

        const datasets = Object.entries(byIndicador).map(([ind, rows]) => {
            const c = empleoColors[ind] || COLORS.indigo;
            const map = {};
            rows.forEach(r => map[r.anio] = r.valor);
            return {
                label: ind,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-empleo-series', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });
    }
    // IESS afiliados chart
    function renderIESS() {
        const data = DATA.iessAfiliados;
        if (!data || !data.length) return;
        const years = data.map(r => r.anio);
        const values = data.map(r => r.afiliados);
        makeChart('chart-iess', {
            type: 'line',
            data: {
                labels: years, datasets: [{
                    label: 'Afiliados al IESS',
                    data: values,
                    borderColor: COLORS.emerald.border,
                    backgroundColor: COLORS.emerald.bg,
                    fill: true,
                    tension: 0.3,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: false, ticks: { callback: v => (v / 1e6).toFixed(1) + 'M' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.parsed.y.toLocaleString() + ' afiliados' } } }
            }
        });
    }

    // Employment by demographics - latest year
    function renderEmpleoDemo() {
        const dimension = document.getElementById('empleo-dimension').value;
        const data = DATA.empleoDemografico.filter(r =>
            r.tipoCategoria === dimension && r.empleoAdecuado != null
        );

        if (!data.length) {
            makeChart('chart-empleo-demo', { type: 'bar', data: { labels: ['Sin datos'], datasets: [{ data: [0] }] } });
            return;
        }

        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);
        latest.sort((a, b) => b.empleoAdecuado - a.empleoAdecuado);

        makeChart('chart-empleo-demo', {
            type: 'bar',
            data: {
                labels: latest.map(r => r.categoria),
                datasets: [{
                    label: 'Empleo adecuado (' + latestYear + ')',
                    data: latest.map(r => +r.empleoAdecuado),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border),
                    borderWidth: 1,
                    borderRadius: 6,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                scales: { x: { beginAtZero: true, ticks: { callback: v => v.toFixed(0) + '%' } } },
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: ctx => ctx.parsed.x.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Employment growth by sector
    let empleoSectorYearsInit = false;
    function initEmpleoSectorPeriods() {
        if (empleoSectorYearsInit) return;
        const periods = DATA.crecimientoEmpleoPeriodos ? Object.keys(DATA.crecimientoEmpleoPeriodos) : [];
        const sel = document.getElementById('empleo-sector-period');
        periods.forEach(p => {
            const label = p.replace('_', ' – ');
            sel.appendChild(Object.assign(document.createElement('option'), { value: p, textContent: label }));
        });
        if (periods.length) sel.value = periods[periods.length - 1];
        sel.addEventListener('change', renderEmpleoSector);
        empleoSectorYearsInit = true;
    }

    function renderEmpleoSector() {
        initEmpleoSectorPeriods();
        const period = document.getElementById('empleo-sector-period').value;
        const rows = DATA.crecimientoEmpleoPeriodos && DATA.crecimientoEmpleoPeriodos[period];
        if (!rows || !rows.length) {
            makeChart('chart-empleo-sector', { type: 'bar', data: { labels: [], datasets: [] } });
            return;
        }
        const sorted = [...rows].sort((a, b) => (b.uniCrecimiento || 0) - (a.uniCrecimiento || 0));
        const labels = sorted.map(r => r.rama1);
        makeChart('chart-empleo-sector', {
            type: 'bar',
            data: {
                labels,
                datasets: [
                    {
                        label: 'Universitarios (%)',
                        data: sorted.map(r => r.uniCrecimiento != null ? +r.uniCrecimiento.toFixed(1) : null),
                        backgroundColor: COLORS.indigo.border + '99',
                        borderColor: COLORS.indigo.border,
                        borderWidth: 1, borderRadius: 4,
                    },
                    {
                        label: 'No universitarios (%)',
                        data: sorted.map(r => r.nouniCrecimiento != null ? +r.nouniCrecimiento.toFixed(1) : null),
                        backgroundColor: COLORS.amber.border + '99',
                        borderColor: COLORS.amber.border,
                        borderWidth: 1, borderRadius: 4,
                    }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                plugins: {
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8 } },
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.x != null ? ctx.parsed.x.toFixed(1) + '%' : '—') } }
                }
            }
        });
    }

    // Employment significance table
    function renderEmpleoSigTable() {
        const data = DATA.variacionEmpleoSignificancia;
        data.sort((a, b) => b.anio - a.anio);

        const tbody = document.querySelector('#empleo-sig-table tbody');
        tbody.innerHTML = data.map(r => {
            const sigClass = r.significativo && r.significativo.startsWith('Sí') ? 'sig-yes' :
                r.significativo === 'No' ? 'sig-no' : 'sig-maybe';
            return `
                <tr>
                    <td>${r.anio}</td>
                    <td>${r.indicador}</td>
                    <td>${r.valor != null ? r.valor.toFixed(2) : '—'}</td>
                    <td>${r.valorAnterior != null ? r.valorAnterior.toFixed(2) : '—'}</td>
                    <td style="color:${r.variacionPp < 0 ? '#ef4444' : '#10b981'}">${r.variacionPp != null ? (r.variacionPp > 0 ? '+' : '') + r.variacionPp.toFixed(2) : '—'}</td>
                    <td><span class="${sigClass}">${r.significativo || '—'}</span></td>
                </tr>
            `;
        }).join('');
    }


    /* ============================================================
       PAGE: INFORMALIDAD (Empleo sub-tab)
       ============================================================ */
    function renderInformalidad() {
        renderInformalidadComponentes();
        renderInformalidadCondiciones();
        renderInformalidadArea();
        renderInformalidadSexo();
        renderInformalidadEdad();
        renderInformalidadEtnia();
        renderInformalidadEducacion();
        renderInformalidadTablaRama();
        renderInformalidadTablaProvincia();
    }

    function renderInformalidadComponentes() {
        const data = DATA.informalidadComponentes;
        if (!data || !data.length) return;
        const years = data.map(r => r.anio);
        const series = {
            'No IESS': { key: 'compNoIess', color: COLORS.red },
            'No adecuado': { key: 'compNoAdec', color: COLORS.amber },
            'No remunerado': { key: 'compNoRemun', color: COLORS.purple },
            'No RUC': { key: 'compNoRuc', color: COLORS.indigo },
            'Informalidad': { key: 'informal2', color: COLORS.cyan },
        };
        const datasets = Object.entries(series).map(([label, s]) => ({
            label,
            data: data.map(r => {
                const v = r[s.key];
                if (v == null) return null;
                return +v;
            }),
            borderColor: s.color.border,
            backgroundColor: s.color.bg,
            fill: false,
            spanGaps: true,
            borderWidth: label === 'Informalidad' ? 3.5 : 2,
        }));
        makeChart('chart-informalidad-componentes', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) + '%' : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    function renderInformalidadCondiciones() {
        const data = DATA.informalidadCondiciones;
        if (!data || !data.length) return;
        const years = data.map(r => r.anio);
        const condColors = [COLORS.cyan, COLORS.amber, COLORS.red, COLORS.purple];
        const datasets = [1, 2, 3, 4].map((n, i) => ({
            label: n + ' condición' + (n > 1 ? 'es' : ''),
            data: data.map(r => r['cond' + n] != null ? +r['cond' + n] : null),
            borderColor: condColors[i].border,
            backgroundColor: condColors[i].bg,
            fill: false, spanGaps: true,
        }));
        makeChart('chart-informalidad-condiciones', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) + '%' : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    function renderInformalidadArea() {
        const data = DATA.informalidadComponentes;
        if (!data || !data.length) return;
        const filtered = data.filter(r => r.informal2 != null);
        const years = filtered.map(r => r.anio);
        const datasets = [
            { label: 'Nacional', data: filtered.map(r => r.informal2 != null ? +r.informal2 : null), borderColor: COLORS.cyan.border, backgroundColor: COLORS.cyan.bg, fill: false, spanGaps: true },
        ];
        const urban = data.filter(r => r.informal1 != null);
        if (urban.length) {
            const urbanYears = urban.map(r => r.anio);
            const urbanMap = {}; urban.forEach(r => urbanMap[r.anio] = +r.informal1);
            datasets.push({ label: 'Urbano', data: years.map(y => urbanMap[y] ?? null), borderColor: COLORS.indigo.border, backgroundColor: COLORS.indigo.bg, fill: false, spanGaps: true });
        }
        makeChart('chart-informalidad-area', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) + '%' : '—') } } }
            }
        });
    }

    function renderInformalidadSexo() {
        const data = DATA.informalidadGenero;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'sexo');
        const years = uniqueSorted(data.map(r => r.anio));
        const sexColors = { 'hombre': COLORS.cyan, 'mujer': COLORS.rose };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = sexColors[g] || COLORS.indigo;
            const map = {}; rows.forEach(r => map[r.anio] = r.informal2 != null ? +(r.informal2 * 100).toFixed(1) : null);
            return { label: g.charAt(0).toUpperCase() + g.slice(1), data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-informalidad-sexo', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 50, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderInformalidadEdad() {
        const data = DATA.informalidadEdad;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'ageCat');
        const years = uniqueSorted(data.map(r => r.anio));
        const ageColors = { '18-29': COLORS.cyan, '30-64': COLORS.indigo, '65+': COLORS.amber };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = ageColors[g] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.informal2 != null ? +(r.informal2 * 100).toFixed(1) : null);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-informalidad-edad', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 50, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderInformalidadEtnia() {
        const data = DATA.informalidadEtnia;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'etniaArm');
        const years = uniqueSorted(data.map(r => r.anio));
        const etColors = { 'Indígena': COLORS.emerald, 'Negro/Afro': COLORS.indigo, 'Blanco/Mestizo': COLORS.amber };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = etColors[g] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.informal2 != null ? +(r.informal2 * 100).toFixed(1) : null);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-informalidad-etnia', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 50, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderInformalidadEducacion() {
        const data = DATA.informalidadEducacion;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'educUniv');
        const years = uniqueSorted(data.map(r => r.anio));
        const edColors = { 'No universitaria': COLORS.red, 'Universitaria': COLORS.indigo };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = edColors[g] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.informal2 != null ? +(r.informal2 * 100).toFixed(1) : null);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-informalidad-educacion', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderInformalidadTablaRama() {
        const data = DATA.informalidadRama;
        if (!data || !data.length) return;
        const years = ['2001', '2005', '2010', '2015', '2020', '2025'];
        const tbody = document.querySelector('#informalidad-rama-table tbody');
        tbody.innerHTML = data.map(r => {
            return '<tr><td>' + r.rama + '</td>' + years.map(y => {
                const v = r[y];
                return '<td style="text-align:center">' + (v != null ? v.toFixed(1) : '—') + '</td>';
            }).join('') + '</tr>';
        }).join('');
    }

    function renderInformalidadTablaProvincia() {
        const data = DATA.informalidadProvincia;
        if (!data || !data.length) return;
        const years = ['2001', '2005', '2010', '2015', '2020', '2025'];
        const tbody = document.querySelector('#informalidad-provincia-table tbody');
        tbody.innerHTML = data.map(r => {
            return '<tr><td>' + r.provincia + '</td>' + years.map(y => {
                const v = r[y];
                return '<td style="text-align:center">' + (v != null ? v.toFixed(1) : '—') + '</td>';
            }).join('') + '</tr>';
        }).join('');
    }

    /* ============================================================
       PAGE: POBREZA LABORAL (Empleo sub-tab)
       ============================================================ */
    function renderPobrezaLaboralPage() {
        renderPobrezaLaboralEvol();
        renderPobrezaLaboralSexo();
        renderPobrezaLaboralArea();
        renderPobrezaLaboralEduc();
        renderPobrezaLaboralEdad();
    }

    function renderPobrezaLaboralEvol() {
        const data = DATA.pobrezaLaboral;
        if (!data || !data.length) return;
        const years = data.map(r => r.anio);
        makeChart('chart-pobreza-laboral', {
            type: 'line',
            data: {
                labels: years, datasets: [{
                    label: 'Pobreza laboral (%)',
                    data: data.map(r => r.tasaPobrezaPct != null ? +r.tasaPobrezaPct : null),
                    borderColor: COLORS.red.border, backgroundColor: COLORS.red.bg, fill: true, spanGaps: true,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderPobrezaLaboralSexo() {
        const data = DATA.pobrezaLaboralSexo;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'sexo');
        const years = uniqueSorted(data.map(r => r.anio));
        const sexColors = { 'hombre': COLORS.cyan, 'mujer': COLORS.rose };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = sexColors[g] || COLORS.indigo;
            const map = {}; rows.forEach(r => map[r.anio] = r.tasaPobrezaPct);
            return { label: g.charAt(0).toUpperCase() + g.slice(1), data: years.map(y => map[y] != null ? +map[y] : null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-pobreza-laboral-sexo', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderPobrezaLaboralArea() {
        const data = DATA.pobrezaLaboralArea;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'area');
        const years = uniqueSorted(data.map(r => r.anio));
        const areaColors = { 'urbana': COLORS.indigo, 'rural': COLORS.amber };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = areaColors[g] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.tasaPobrezaPct);
            return { label: g.charAt(0).toUpperCase() + g.slice(1), data: years.map(y => map[y] != null ? +map[y] : null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-pobreza-laboral-area', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderPobrezaLaboralEduc() {
        const data = DATA.pobrezaLaboralEduc;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'educacionSuperior');
        const years = uniqueSorted(data.map(r => r.anio));
        const edColors = { 'Sin educacion superior': COLORS.red, 'Con educacion superior': COLORS.indigo };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = edColors[g] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.tasaPobrezaPct);
            return { label: g, data: years.map(y => map[y] != null ? +map[y] : null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-pobreza-laboral-educ', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    function renderPobrezaLaboralEdad() {
        const data = DATA.pobrezaLaboralEdad;
        if (!data || !data.length) return;
        const byGrupo = groupBy(data, 'ageCat');
        const years = uniqueSorted(data.map(r => r.anio));
        const ageColors = { '18-29': COLORS.cyan, '30-64': COLORS.indigo, '65+': COLORS.amber };
        const datasets = Object.entries(byGrupo).map(([g, rows]) => {
            const c = ageColors[g] || COLORS.purple;
            const map = {}; rows.forEach(r => map[r.anio] = r.tasaPobrezaPct);
            return { label: g, data: years.map(y => map[y] != null ? +map[y] : null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-pobreza-laboral-edad', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    /* ============================================================
       PAGE: DISTRIBUCIÓN DEL CRECIMIENTO
       ============================================================ */
    let crecimientoRendered = false;

    function renderCrecimiento() {
        renderGIC();
        if (crecimientoRendered) return;
        renderCrecEmpleo();
        crecimientoRendered = true;
    }

    // Growth Incidence Curve — pre-computed from xlsx files
    let gicInitialized = false;
    function initGIC() {
        if (gicInitialized) return;
        const data = DATA.gicCurves;
        if (!data || !data.length) return;

        const areaSel = document.getElementById('gic-area');
        const startSel = document.getElementById('gic-year-start');
        const endSel = document.getElementById('gic-year-end');

        function updateYearOptions() {
            const area = areaSel.value;
            const filtered = data.filter(r => r.area === area);
            const startYears = uniqueSorted([...new Set(filtered.map(r => r.anioInicio))]);
            const prevStart = startSel.value;
            const prevEnd = endSel.value;
            startSel.innerHTML = '';
            startYears.forEach(y => startSel.appendChild(Object.assign(document.createElement('option'), { value: y, textContent: y })));
            startSel.value = startYears.includes(+prevStart) ? prevStart : startYears[0];
            updateEndOptions();
        }

        function updateEndOptions() {
            const area = areaSel.value;
            const startYear = +startSel.value;
            const endYears = uniqueSorted([...new Set(data.filter(r => r.area === area && r.anioInicio === startYear).map(r => r.anioFin))]);
            const prevEnd = endSel.value;
            endSel.innerHTML = '';
            endYears.forEach(y => endSel.appendChild(Object.assign(document.createElement('option'), { value: y, textContent: y })));
            endSel.value = endYears.includes(+prevEnd) ? prevEnd : endYears[endYears.length - 1];
        }

        areaSel.addEventListener('change', () => { updateYearOptions(); renderGIC(); });
        startSel.addEventListener('change', () => { updateEndOptions(); renderGIC(); });
        endSel.addEventListener('change', renderGIC);

        updateYearOptions();
        gicInitialized = true;
    }

    function renderGIC() {
        initGIC();
        const data = DATA.gicCurves;
        if (!data || !data.length) {
            makeChart('chart-gic', { type: 'line', data: { labels: [], datasets: [] } });
            return;
        }

        const area = document.getElementById('gic-area').value;
        const startYear = +document.getElementById('gic-year-start').value;
        const endYear = +document.getElementById('gic-year-end').value;

        const points = data.filter(r => r.area === area && r.anioInicio === startYear && r.anioFin === endYear)
            .sort((a, b) => a.pctl - b.pctl);

        if (!points.length) {
            makeChart('chart-gic', { type: 'line', data: { labels: ['Sin datos para esta combinación'], datasets: [{ data: [0] }] } });
            return;
        }

        makeChart('chart-gic', {
            type: 'line',
            data: {
                labels: points.map(r => 'P' + r.pctl),
                datasets: [{
                    label: 'Crecimiento anualizado (%)',
                    data: points.map(r => r.growth),
                    borderColor: COLORS.indigo.border,
                    backgroundColor: COLORS.indigo.bg,
                    fill: false,
                    tension: 0.3,
                    pointRadius: 2,
                    pointHoverRadius: 5,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: {
                    x: { title: { display: true, text: 'Percentil de ingreso' } },
                    y: { title: { display: true, text: 'Crecimiento anualizado (%)' }, ticks: { callback: v => v.toFixed(1) + '%' } }
                },
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(2) + '%' } }
                }
            }
        });
    }

    // Income growth by demographics
    function renderCrecDemo() {
        const data = DATA.crecimientoDemografico;

        if (!data || !data.length) {
            makeChart('chart-crec-demo', { type: 'bar', data: { labels: [], datasets: [] } });
            return;
        }

        // Use dimension + categoria for labels, ingreso for values
        const labels = data.map(r => {
            const parts = [];
            if (r.dimension) parts.push(r.dimension);
            if (r.categoria) parts.push(r.categoria);
            return parts.join(': ');
        });

        makeChart('chart-crec-demo', {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Ingreso promedio ($)',
                    data: data.map(r => r.ingreso != null ? +r.ingreso : 0),
                    backgroundColor: data.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: data.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border),
                    borderWidth: 1,
                    borderRadius: 6,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.x.toFixed(0) } }
                }
            }
        });
    }

    // Employment growth by sector (Crecimiento page) — period-based
    let crecEmpleoPeriodInit = false;
    function initCrecEmpleoPeriods() {
        if (crecEmpleoPeriodInit) return;
        const periods = DATA.crecimientoEmpleoPeriodos ? Object.keys(DATA.crecimientoEmpleoPeriodos) : [];
        const sel = document.getElementById('crec-empleo-sector-period');
        periods.forEach(p => {
            const label = p.replace('_', ' – ');
            sel.appendChild(Object.assign(document.createElement('option'), { value: p, textContent: label }));
        });
        if (periods.length) sel.value = periods[periods.length - 1];
        sel.addEventListener('change', renderCrecEmpleo);
        crecEmpleoPeriodInit = true;
    }

    function renderCrecEmpleo() {
        initCrecEmpleoPeriods();
        const period = document.getElementById('crec-empleo-sector-period').value;
        const rows = DATA.crecimientoEmpleoPeriodos && DATA.crecimientoEmpleoPeriodos[period];
        if (!rows || !rows.length) {
            makeChart('chart-crec-empleo', { type: 'bar', data: { labels: [], datasets: [] } });
            return;
        }
        const sorted = [...rows].sort((a, b) => (b.uniCrecimiento || 0) - (a.uniCrecimiento || 0));
        const labels = sorted.map(r => r.rama1);
        makeChart('chart-crec-empleo', {
            type: 'bar',
            data: {
                labels,
                datasets: [
                    {
                        label: 'Universitarios (%)',
                        data: sorted.map(r => r.uniCrecimiento != null ? +r.uniCrecimiento.toFixed(1) : null),
                        backgroundColor: COLORS.indigo.border + '99',
                        borderColor: COLORS.indigo.border,
                        borderWidth: 1, borderRadius: 4,
                    },
                    {
                        label: 'No universitarios (%)',
                        data: sorted.map(r => r.nouniCrecimiento != null ? +r.nouniCrecimiento.toFixed(1) : null),
                        backgroundColor: COLORS.amber.border + '99',
                        borderColor: COLORS.amber.border,
                        borderWidth: 1, borderRadius: 4,
                    }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                plugins: {
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8 } },
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.x != null ? ctx.parsed.x.toFixed(1) + '%' : '—') } }
                }
            }
        });
    }

    /* ============================================================
       PAGE: DESIGUALDAD (unified with sub-tabs)
       ============================================================ */
    let desigualdadRendered = false;
    let selectedCountries = ['Ecuador'];

    function renderDesigualdad() {
        const activeTab = document.querySelector('#desigualdad-tabs .sub-tab.active');
        const tabId = activeTab ? activeTab.dataset.subtab : 'indicadores';

        if (tabId === 'indicadores') {
            renderGiniFull();
            renderGiniLAC();
        } else if (tabId === 'palma') {
            renderPalmaALC();
        } else if (tabId === 'concentracion') {
            initConcentracionInnerTabs();
            renderConcentracionInner();
        } else if (tabId === 'oportunidades') {
            // static table — nothing to render dynamically
        }
        desigualdadRendered = true;
    }

    // Concentración inner tabs (WID / SRI toggle)
    let concInnerInit = false;
    function initConcentracionInnerTabs() {
        if (concInnerInit) return;
        const bar = document.getElementById('concentracion-inner-tabs');
        if (!bar) return;
        bar.querySelectorAll('.sub-tab').forEach(btn => {
            btn.addEventListener('click', () => {
                bar.querySelectorAll('.sub-tab').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                document.querySelectorAll('.concentracion-panel').forEach(p => {
                    p.style.display = 'none';
                    p.classList.remove('active');
                });
                const panel = document.getElementById('conc-panel-' + btn.dataset.inner);
                if (panel) { panel.style.display = ''; panel.classList.add('active'); }
                renderConcentracionInner();
            });
        });
        concInnerInit = true;
    }
    function renderConcentracionInner() {
        const active = document.querySelector('#concentracion-inner-tabs .sub-tab.active');
        const which = active ? active.dataset.inner : 'wid';
        if (which === 'wid') {
            renderPopulationPercentiles();
            renderWIDChart('chart-wid-income-ec', DATA.widIngresoPercentiles, 'participacionEnElIngresoNacional(%)');
            renderWIDChart('chart-wid-wealth-ec', DATA.widRiquezaPercentiles, 'participacionEnLaRiquezaNacional(%)');
            if (!document.getElementById('country-selector').children.length) initLatamFilters();
            renderLatamChart();
        } else {
            renderSRIConcentracion();
            renderSRICapital();
            renderTransitionMatrix();
        }
    }

    // Gini mini chart (moved from Inicio to Desigualdad)
    function renderGiniHome() {
        const giniData = DATA.giniPanel.filter(r => r.categoria === 'Ecuador' && r.valor != null);
        const giniYears = uniqueSorted(giniData.map(r => r.ano));
        const giniMap = {};
        giniData.forEach(r => giniMap[r.ano] = r.valor);

        makeChart('chart-gini-home', {
            type: 'line',
            data: {
                labels: giniYears,
                datasets: [{
                    label: 'Gini',
                    data: giniYears.map(y => giniMap[y]),
                    borderColor: COLORS.indigo.border,
                    backgroundColor: COLORS.indigo.bg,
                    fill: true
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { min: 0.3, max: 1.0 } }
            }
        });
    }

    // Gini before/after taxes
    function renderGiniTax() {
        const data = DATA.giniTaxImpact.filter(r => r.gini != null);
        const byCat = groupBy(data, 'categoria');
        const years = uniqueSorted(data.map(r => r.anio));
        const taxColors = {
            'Gini antes de impuestos': COLORS.red,
            'Gini después de IR': COLORS.amber,
            'Gini después de IR + IVA': COLORS.indigo,
            'Gini después de todos los impuestos': COLORS.emerald
        };
        const datasets = Object.entries(byCat).map(([cat, rows]) => {
            const c = taxColors[cat] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.gini);
            return { label: cat, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-gini-tax', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 0.3, max: 0.6, title: { display: true, text: 'Coeficiente de Gini' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(3) : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    // Gini national/urban/rural (no LAC)
    function renderGiniFull() {
        const data = DATA.giniPanel.filter(r => r.valor != null && r.categoria !== 'LAC');
        const byCat = groupBy(data, 'categoria');
        const years = uniqueSorted(data.map(r => r.ano));
        const catColors = { 'Ecuador': COLORS.cyan, 'Ecuador (Urbano)': COLORS.indigo, 'Ecuador (Rural)': COLORS.amber };
        const datasets = Object.entries(byCat).map(([cat, rows]) => {
            const c = catColors[cat] || COLORS.red;
            const map = {}; rows.forEach(r => map[r.ano] = r.valor);
            return { label: cat, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-gini-full', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 0.3, max: 1.0, title: { display: true, text: 'Coeficiente de Gini' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(3) : '—') } } }
            }
        });
    }

    // Gini LAC comparison
    let giniLacCountries = ['Ecuador', 'Colombia', 'Peru', 'Chile', 'Brazil'];
    function renderGiniLAC() {
        const container = document.getElementById('gini-country-selector');
        if (!container.children.length) {
            const countries = [...new Set(DATA.giniLacComparison.map(r => r.pais))].sort();
            countries.forEach(c => {
                const chip = document.createElement('span');
                chip.className = 'country-chip' + (giniLacCountries.includes(c) ? ' selected' : '');
                chip.textContent = c; chip.dataset.country = c;
                chip.addEventListener('click', () => {
                    chip.classList.toggle('selected');
                    if (chip.classList.contains('selected')) giniLacCountries.push(c);
                    else giniLacCountries = giniLacCountries.filter(x => x !== c);
                    renderGiniLACChart();
                });
                container.appendChild(chip);
            });
        }
        renderGiniLACChart();
    }

    function renderGiniLACChart() {
        const filtered = DATA.giniLacComparison.filter(r => giniLacCountries.includes(r.pais) && r.gini != null);
        const byCountry = groupBy(filtered, 'pais');
        const years = uniqueSorted(filtered.map(r => r.ano));
        const datasets = Object.entries(byCountry).map(([country, rows]) => {
            const c = COUNTRY_COLORS[country] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.ano] = r.gini);
            const isEc = country === 'Ecuador';
            return { label: country, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true, borderWidth: isEc ? 3.5 : 2, order: isEc ? 0 : 1 };
        });
        makeChart('chart-gini-lac', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 0.2, max: 0.7, title: { display: true, text: 'Gini' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(3) : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    // Population in percentiles (info cards)
    function renderPopulationPercentiles() {
        const container = document.getElementById('population-percentiles');
        const data = DATA.poblacionPercentiles;
        if (!data || !data.length) { container.innerHTML = ''; return; }
        container.innerHTML = data.map(r => `
            <div class="card scorecard">
                <span class="sc-icon">👥</span>
                <div class="sc-value">${(r.poblacion / 1e6).toFixed(1)}M</div>
                <div class="sc-label">${r.percentil}</div>
                <div class="sc-year">${r.anio}</div>
            </div>`).join('');
    }

    // Palma ALC comparison
    let palmaCountriesInit = false;
    let selectedPalmaCountries = ['Ecuador', 'ALC'];
    function renderPalmaALC() {
        const data = DATA.palmaAlc;
        if (!data || !data.length) return;
        const countries = [...new Set(data.map(r => r.pais))].sort();
        const container = document.getElementById('palma-country-selector');
        if (!palmaCountriesInit && container) {
            container.innerHTML = countries.map(c =>
                `<label class="country-chip"><input type="checkbox" value="${c}" ${selectedPalmaCountries.includes(c) ? 'checked' : ''}> ${c}</label>`
            ).join('');
            container.addEventListener('change', () => {
                selectedPalmaCountries = [...container.querySelectorAll('input:checked')].map(i => i.value);
                renderPalmaALCChart();
            });
            palmaCountriesInit = true;
        }
        renderPalmaALCChart();
    }
    function renderPalmaALCChart() {
        const data = DATA.palmaAlc.filter(r => selectedPalmaCountries.includes(r.pais));
        const byCountry = groupBy(data, 'pais');
        const years = uniqueSorted(data.map(r => r.ano));
        const palmaColors = { 'Ecuador': COLORS.indigo, 'ALC': COLORS.amber, 'Brasil': COLORS.emerald, 'Colombia': COLORS.red, 'Perú': COLORS.purple };
        const datasets = Object.entries(byCountry).map(([country, rows]) => {
            const c = palmaColors[country] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.ano] = +r.valor);
            return { label: country, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true, tension: 0.3 };
        });
        makeChart('chart-palma-alc', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                scales: { y: { title: { display: true, text: 'Índice de Palma' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8 } }
                }
            }
        });
    }

    // SRI income by percentile (kept but not rendered in dashboard)
    function renderSRIIncome() {
        const data = DATA.sriPercentilesIngreso.filter(r => r.ingresoMensualNominal != null);
        const byPerc = groupBy(data, 'percentil');
        const years = uniqueSorted(data.map(r => r.anio));
        const percColors = { 'P50 (Mediana)': COLORS.emerald, 'P90': COLORS.amber, 'P99': COLORS.red, 'P99.9': COLORS.purple };
        const datasets = Object.entries(byPerc).map(([perc, rows]) => {
            const c = percColors[perc] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = r.ingresoMensualNominal);
            return { label: perc, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart('chart-sri-income', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: false, ticks: { callback: v => '$' + v.toLocaleString() }, title: { display: true, text: 'USD mensual' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toLocaleString() } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    // WID charts (shared between Concentración tab and old page)
    function renderWIDChart(canvasId, rawData, valueKey) {
        if (!rawData || !rawData.length) { makeChart(canvasId, { type: 'line', data: { labels: [], datasets: [] } }); return; }
        const data = rawData.filter(r => r[valueKey] != null);
        const byPerc = groupBy(data, 'percentil');
        const years = uniqueSorted(data.map(r => r.ano));
        const percColors = { 'Bottom 50%': COLORS.emerald, 'Top 10%': COLORS.amber, 'Top 1%': COLORS.red, 'Top 0.1%': COLORS.purple };
        const datasets = Object.entries(byPerc).map(([perc, rows]) => {
            const c = percColors[perc] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.ano] = r[valueKey]);
            return { label: perc, data: years.map(y => map[y] != null ? +map[y] : null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart(canvasId, {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    // América Latina filters + chart
    function initLatamFilters() {
        const container = document.getElementById('country-selector');
        COUNTRY_LIST.forEach(c => {
            const chip = document.createElement('span');
            chip.className = 'country-chip' + (selectedCountries.includes(c) ? ' selected' : '');
            chip.textContent = c; chip.dataset.country = c;
            chip.addEventListener('click', () => {
                chip.classList.toggle('selected');
                if (chip.classList.contains('selected')) selectedCountries.push(c);
                else selectedCountries = selectedCountries.filter(x => x !== c);
                renderLatamChart();
            });
            container.appendChild(chip);
        });
        document.getElementById('latam-var').addEventListener('change', renderLatamChart);
        document.getElementById('latam-percentile').addEventListener('change', renderLatamChart);
    }

    function renderLatamChart() {
        const variable = document.getElementById('latam-var').value;
        const percentile = document.getElementById('latam-percentile').value;
        const rawData = variable === 'income' ? DATA.widIngresoPercentilesALC : DATA.widRiquezaPercentilesALC;
        const valueKey = variable === 'income' ? 'participacionEnElIngresoNacional(%)' : 'participacionEnLaRiquezaNacional(%)';
        const varLabel = variable === 'income' ? 'Ingreso' : 'Riqueza';
        document.getElementById('latam-chart-title').textContent = `Participación del ${percentile} en el ${varLabel} Nacional`;
        const filtered = rawData.filter(r => r.percentil === percentile && selectedCountries.includes(r.pais) && r[valueKey] != null);
        const byCountry = groupBy(filtered, 'pais');
        const years = uniqueSorted(filtered.map(r => r.ano)).filter(y => y >= 1980);
        const datasets = Object.entries(byCountry).map(([country, rows]) => {
            const c = COUNTRY_COLORS[country] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.ano] = r[valueKey]);
            const isEc = country === 'Ecuador';
            return { label: country, data: years.map(y => map[y] != null ? +map[y] : null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true, borderWidth: isEc ? 3.5 : 2, order: isEc ? 0 : 1 };
        });
        makeChart('chart-latam', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: '%' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) + '%' : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    /* ============================================================
       PAGE: CONCENTRACIÓN SRI (Desigualdad sub-tab)
       ============================================================ */
    function renderSRIConcentracion() {
        const data = DATA.sriConcentracion && DATA.sriConcentracion.concentracionPretax;
        if (!data || !data.length) return;
        const years = data.map(r => r.ano || r.Año);
        const series = [
            { label: 'Top 0.1%', key: '0.1% más rico', color: COLORS.purple },
            { label: 'Top 1%', key: '1% más rico', color: COLORS.red },
            { label: 'Top 10%', key: '10% más rico', color: COLORS.amber },
            { label: 'Clase media (P50-P90)', key: 'Clase media (P50-P90)', color: COLORS.indigo },
            { label: '50% más pobre', key: '50% más pobre', color: COLORS.emerald },
        ];
        const datasets = series.map(s => ({
            label: s.label,
            data: data.map(r => {
                const v = r[s.key];
                return v != null ? +(v * 100).toFixed(1) : null;
            }),
            borderColor: s.color.border, backgroundColor: s.color.bg, fill: false, spanGaps: true,
        }));
        makeChart('chart-sri-concentracion', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: '% del ingreso total' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) + '%' : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    function renderSRICapital() {
        const data = DATA.sriCapital;
        if (!data || !data.length) return;
        const years = data.map(r => r.anio || r.ano);
        const keys = Object.keys(data[0]).filter(k => k !== 'ano' && k !== 'Año' && k !== 'Total');
        const targetKeys = ['Top 0.1%', 'Top 1%', 'Top 10%', 'Clase media (P50-P90)', '50% más pobre'];
        const capColors = [COLORS.purple, COLORS.red, COLORS.amber, COLORS.cyan, COLORS.emerald];
        const datasets = targetKeys.filter(k => data[0][k] !== undefined).map((k, i) => ({
            label: k,
            data: data.map(r => {
                const v = r[k];
                return v != null ? +Number(v).toFixed(1) : null;
            }),
            borderColor: capColors[i % capColors.length].border,
            backgroundColor: capColors[i % capColors.length].bg,
            fill: false, spanGaps: true,
        }));
        makeChart('chart-sri-capital', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: '% del ingreso del capital' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) + '%' : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    function renderGiniSRI() {
        const data = DATA.sriConcentracion && DATA.sriConcentracion.giniSri;
        if (!data || !data.length) return;
        const years = data.map(r => r.ano || r.Año);
        makeChart('chart-gini-sri', {
            type: 'line',
            data: {
                labels: years, datasets: [
                    { label: 'Antes de impuestos', data: data.map(r => r['Antes de impuestos'] || r.antesDeImpuestos), borderColor: COLORS.red.border, backgroundColor: COLORS.red.bg, fill: false },
                    { label: 'Después de impuestos', data: data.map(r => r['Después de impuestos'] || r.despuesDeImpuestos), borderColor: COLORS.emerald.border, backgroundColor: COLORS.emerald.bg, fill: false }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 0.4, max: 0.65, title: { display: true, text: 'Coeficiente de Gini' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(3) : '—') } } }
            }
        });
    }

    function renderTransitionMatrix() {
        const data = DATA.matrizTransicion;
        if (!data || !data.length) return;
        const tbody = document.querySelector('#transition-matrix-table tbody');
        tbody.innerHTML = data.map(r => {
            const decil = r['Decil 2010/Decil 2024'] || r.decil2010Decil2024 || Object.values(r)[0];
            const vals = [];
            for (let d = 1; d <= 10; d++) {
                const v = r[String(d)] || r[d];
                vals.push(v != null ? +(v * 100).toFixed(1) : '—');
            }
            const maxVal = Math.max(...vals.filter(v => typeof v === 'number'));
            return '<tr><td><strong>' + decil + '</strong></td>' + vals.map(v => {
                const intensity = typeof v === 'number' ? Math.min(v / maxVal, 1) : 0;
                const bg = intensity > 0.5 ? `rgba(6,182,212,${intensity * 0.4})` : intensity > 0.2 ? `rgba(99,102,241,${intensity * 0.3})` : '';
                return `<td style="text-align:center;${bg ? 'background:' + bg : ''}">${typeof v === 'number' ? v.toFixed(1) + '%' : v}</td>`;
            }).join('') + '</tr>';
        }).join('');
    }

    /* ============================================================
       PAGE: VIOLENCIA Y MORTALIDAD (Desigualdad sub-tab)
       ============================================================ */
    function renderViolencia() {
        renderMortalidadSeries('chart-mortalidad-jovenes', DATA.mortalidadJovenes, 'nivelEducativoJovenes', 1);
        renderMortalidadSeries('chart-mortalidad-adultos', DATA.mortalidadAdultos, 'nivelEducativoAdultos', 1);
        renderMortalidadSeries('chart-homicidios-jovenes', DATA.homicidiosJovenes, 'nivelEducativoJovenes', 1);
        renderMortalidadSeries('chart-homicidios-adultos', DATA.homicidiosAdultos, 'nivelEducativoAdultos', 1);
        renderMortalidadSeries('chart-suicidios-jovenes', DATA.suicidiosJovenes, 'nivelEducativoJovenes', 1);
        renderMortalidadSeries('chart-suicidios-adultos', DATA.suicidiosAdultos, 'nivelEducativoAdultos', 1);
    }

    function renderMortalidadSeries(canvasId, rawData, groupKey, scaleFactor) {
        if (!rawData || !rawData.length) { makeChart(canvasId, { type: 'line', data: { labels: [], datasets: [] } }); return; }
        const data = rawData.filter(r => r.tasa != null);
        const byGroup = groupBy(data, groupKey);
        const years = uniqueSorted(data.map(r => r.anio));
        const eduColors = {
            'Secundaria completa': COLORS.indigo,
            'Secundaria incompleta': COLORS.red,
            'Superior': COLORS.indigo,
            'No superior': COLORS.red,
        };
        const datasets = Object.entries(byGroup).map(([g, rows]) => {
            const c = eduColors[g] || COLORS.cyan;
            const map = {}; rows.forEach(r => map[r.anio] = +r.tasa);
            return { label: g, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: false, spanGaps: true };
        });
        makeChart(canvasId, {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, title: { display: true, text: 'Tasa' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) : '—') } },
                }
            }
        });
    }

    /* ============================================================
       PAGE: VIOLENCIA Y MORTALIDAD (standalone section)
       ============================================================ */
    function renderViolenciaPage() {
        const activeTab = document.querySelector('#violencia-tabs .sub-tab.active');
        const tabId = activeTab ? activeTab.dataset.subtab : 'violencia-educacion';
        if (tabId === 'violencia-educacion') {
            renderViolencia();
        } else if (tabId === 'violencia-nna') {
            renderHomicidiosNNA();
        }
    }

    function renderHomicidiosNNA() {
        renderHomicidiosEtnia('chart-homicidios-nna', DATA.homicidiosNna, 'Homicidios NNA');
        renderHomicidiosEtnia('chart-homicidios-jovenes-etnia', DATA.homicidiosJovenesEtnia, 'Homicidios Jóvenes');
    }

    function renderHomicidiosEtnia(canvasId, rawData, title) {
        if (!rawData || !rawData.length) { makeChart(canvasId, { type: 'line', data: { labels: [], datasets: [] } }); return; }
        const years = rawData.map(r => r.anio);
        const datasets = [
            { label: 'Afrodescendientes', data: rawData.map(r => r.tasa_afro), borderColor: COLORS.red.border, backgroundColor: COLORS.red.bg, fill: false, borderWidth: 2.5 },
            { label: 'Otras etnias', data: rawData.map(r => r.tasa_otras), borderColor: COLORS.cyan.border, backgroundColor: COLORS.cyan.bg, fill: false, borderWidth: 2.5 },
            { label: 'Total', data: rawData.map(r => r.tasa_total), borderColor: COLORS.amber.border, backgroundColor: COLORS.amber.bg, fill: false, borderDash: [5, 3], borderWidth: 2 },
        ];
        makeChart(canvasId, {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, title: { display: true, text: 'Tasa por 100.000 hab.' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) : '—') } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    /* ============================================================
       INIT
       ============================================================ */
    renderInicio();

})();
