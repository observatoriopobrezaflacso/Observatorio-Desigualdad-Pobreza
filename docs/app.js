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
            if (pageId === 'empleo') renderEmpleo();
            if (pageId === 'salarios') renderSalarios();
            if (pageId === 'crecimiento') renderCrecimiento();
            if (pageId === 'desigualdad') renderDesigualdad();
            if (pageId === 'tributacion') renderTributacion();
        });
    });

    menuToggle.addEventListener('click', () => sidebar.classList.toggle('open'));

    /* ---------- Sub-tab Toggles ---------- */
    document.querySelectorAll('.sub-tabs').forEach(tabBar => {
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
                if (parent.id === 'page-desigualdad') renderDesigualdad();
            });
        });
    });

    /* ============================================================
       PAGE: INICIO
       ============================================================ */
    function renderInicio() {
        // Scorecards
        const scContainer = document.getElementById('scorecards');
        const scData = DATA.scorecards;
        const pobrezaVal = scData.find(r => r.indicador === 'Pobreza');
        const extremaVal = scData.find(r => r.indicador === 'Pobreza extrema');

        // Also get latest Gini from giniPanel
        const giniEc = DATA.giniPanel
            .filter(r => r.categoria === 'Ecuador' && r.valor != null)
            .sort((a, b) => b.ano - a.ano);
        const latestGini = giniEc.length ? giniEc[0] : null;

        // Latest NBI — pobrezaTableau contains NBI data
        const nbiData = DATA.pobrezaTableau.filter(r => r.indicador === 'NBI' && r.nivel === 'Nacional' && r.valor != null)
            .sort((a, b) => b.ano - a.ano);
        const latestNBI = nbiData.length ? nbiData[0] : null;

        // Multidimensional poverty
        const multiVal = DATA.pobrezaMultidimensionalScorecard
            ? DATA.pobrezaMultidimensionalScorecard.find(r => r.indicador === 'Pobreza Multidimensional')
            : null;

        // Employment scorecards
        const empNoAdecuado = DATA.empleoScorecard ? DATA.empleoScorecard.find(r => r.indicador === 'Empleo no adecuado') : null;
        const desempleo = DATA.empleoScorecard ? DATA.empleoScorecard.find(r => r.indicador === 'Desempleo') : null;

        // Top 1% income share
        const top1Data = DATA.widIngresoPercentiles
            .filter(r => r.percentil === 'Top 1%' && r['participacionEnElIngresoNacional(%)'] != null)
            .sort((a, b) => b.ano - a.ano);
        const latestTop1 = top1Data.length ? top1Data[0] : null;

        const cards = [
            { icon: '📉', label: 'Pobreza', value: pobrezaVal ? pobrezaVal.valor.toFixed(1) + '%' : '—', year: pobrezaVal ? pobrezaVal.anio : '' },
            { icon: '⚠️', label: 'Pobreza Extrema', value: extremaVal ? extremaVal.valor.toFixed(1) + '%' : '—', year: extremaVal ? extremaVal.anio : '' },
            { icon: '🏘️', label: 'NBI', value: latestNBI ? latestNBI.valor.toFixed(1) + '%' : '—', year: latestNBI ? latestNBI.ano : '' },
            { icon: '🔶', label: 'Multidimensional', value: multiVal ? multiVal.valor.toFixed(1) + '%' : '—', year: multiVal ? multiVal.anio : '' },
            { icon: '💼', label: 'Empleo no adecuado', value: empNoAdecuado ? empNoAdecuado.valor.toFixed(1) + '%' : '—', year: empNoAdecuado ? empNoAdecuado.anio : '' },
            { icon: '📊', label: 'Desempleo', value: desempleo ? desempleo.valor.toFixed(1) + '%' : '—', year: desempleo ? desempleo.anio : '' },
            { icon: '📈', label: 'Gini (Ecuador)', value: latestGini ? latestGini.valor.toFixed(3) : '—', year: latestGini ? latestGini.ano : '' },
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

        // Mini Gini chart
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
                scales: { y: { min: 0.3, max: 0.9 } }
            }
        });
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
            setupSigTable();
        } else {
            renderPobrezaHistCombined();
            renderPobrezaHistMulti();
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
    function renderPobrezaEtnia() {
        const indicator = getSelectedPovIndicator();
        const mapInd = indicator === 'Pobreza' ? 'Pobreza' : indicator === 'Pobreza Extrema' ? 'Pobreza extrema' : indicator;
        const data = DATA.pobrezaSexoEtnia.filter(r => r.tipoGrupo === 'etnia' && r.indicador === mapInd && r.valor != null);
        if (!data.length) {
            makeChart('chart-pov-etnia', { type: 'bar', data: { labels: ['Sin datos'], datasets: [{ data: [0] }] } });
            return;
        }
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
        // Build national-level year-over-year from pobrezaTableau (Nacional)
        const indicators = ['Pobreza', 'Pobreza Extrema'];
        const rows = [];
        indicators.forEach(ind => {
            const national = DATA.pobrezaTableau
                .filter(r => r.indicador === ind && r.nivel === 'Nacional' && r.valor != null)
                .sort((a, b) => a.ano - b.ano);
            for (let i = 1; i < national.length; i++) {
                const prev = national[i - 1];
                const curr = national[i];
                const varPp = curr.valor - prev.valor;
                const varPct = prev.valor !== 0 ? (varPp / prev.valor) * 100 : null;
                rows.push({ anio: curr.ano, indicador: ind, valor: curr.valor, valorAnt: prev.valor, varPp, varPct });
            }
        });
        rows.sort((a, b) => b.anio - a.anio || a.indicador.localeCompare(b.indicador));

        const tbody = document.querySelector('#sig-table tbody');
        tbody.innerHTML = rows.map(r => `
            <tr>
                <td>${r.anio}</td>
                <td>${r.indicador}</td>
                <td>${r.valor.toFixed(2)}</td>
                <td>${r.valorAnt.toFixed(2)}</td>
                <td style="color:${r.varPp < 0 ? '#10b981' : '#ef4444'}">${(r.varPp > 0 ? '+' : '') + r.varPp.toFixed(2)}</td>
                <td style="color:${r.varPct != null && r.varPct < 0 ? '#10b981' : '#ef4444'}">${r.varPct != null ? (r.varPct > 0 ? '+' : '') + r.varPct.toFixed(1) + '%' : '—'}</td>
            </tr>
        `).join('');
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
        if (!latestYear) { makeChart('chart-pov-bar-sexo', { type: 'bar', data: { labels: [], datasets: [] } }); return; }
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
        if (!latestYear) { makeChart('chart-pov-bar-educacion', { type: 'bar', data: { labels: [], datasets: [] } }); return; }
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
        if (!latestYear) { makeChart('chart-pov-bar-edad', { type: 'bar', data: { labels: [], datasets: [] } }); return; }
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
        if (!latestYear) { makeChart('chart-pov-bar-region', { type: 'bar', data: { labels: [], datasets: [] } }); return; }
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

    function renderPobrezaHistMulti() {
        const pob = DATA.seriesHistoricas.filter(r => r.indicador === 'Pobreza' && r.valor != null);
        const multi = DATA.pobrezaMultidimensionalSeries.filter(r => r.indicador === 'Pobreza Multidimensional' && r.valor != null);
        const years = uniqueSorted([...pob, ...multi].map(r => r.anio));
        const pobMap = {}; pob.forEach(r => pobMap[r.anio] = r.valor);
        const multiMap = {}; multi.forEach(r => multiMap[r.anio] = r.valor);
        makeChart('chart-pov-hist-multi', {
            type: 'line',
            data: {
                labels: years, datasets: [
                    { label: 'Pobreza por ingreso', data: years.map(y => pobMap[y] ?? null), borderColor: COLORS.cyan.border, backgroundColor: COLORS.cyan.bg, fill: false, spanGaps: true },
                    { label: 'Pobreza Multidimensional', data: years.map(y => multiMap[y] ?? null), borderColor: COLORS.amber.border, backgroundColor: COLORS.amber.bg, fill: false, spanGaps: true }
                ]
            },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' } } },
                plugins: { tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    /* ============================================================
       PAGE: EMPLEO
       ============================================================ */
    let empleoRendered = false;

    function renderEmpleo() {
        if (empleoRendered) return;
        renderEmpleoSeries();
        renderIESS();
        renderEmpleoDemo();
        renderEmpleoSector();
        renderEmpleoSigTable();
        empleoRendered = true;
    }

    // Employment time series
    function renderEmpleoSeries() {
        const data = DATA.empleoSeries;
        const byIndicador = groupBy(data, 'indicador');
        const years = uniqueSorted(data.map(r => r.anio));
        const empleoColors = {
            'Empleo adecuado': COLORS.cyan,
            'Empleo no adecuado': COLORS.amber,
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
    function renderEmpleoSector() {
        const periodo = document.getElementById('empleo-periodo').value;
        const [startYear, endYear] = periodo.split('-').map(Number);
        const rawData = DATA.crecimientoEmpleoSector;

        // Group by sector
        const bySector = groupBy(rawData, 'sector');
        const results = [];
        Object.entries(bySector).forEach(([sector, rows]) => {
            const startRow = rows.find(r => r.anio === startYear);
            const endRow = rows.find(r => r.anio === endYear);
            if (startRow && endRow && startRow.empleoMiles && endRow.empleoMiles) {
                const growth = ((endRow.empleoMiles - startRow.empleoMiles) / startRow.empleoMiles) * 100;
                results.push({ sector, valor: growth });
            }
        });
        results.sort((a, b) => b.valor - a.valor);

        // Take top 10 sectors
        const top10 = results.slice(0, 10);

        makeChart('chart-empleo-sector', {
            type: 'bar',
            data: {
                labels: top10.map(r => r.sector),
                datasets: [{
                    label: 'Crecimiento del empleo (%)',
                    data: top10.map(r => +r.valor),
                    backgroundColor: top10.map(r => r.valor > 0 ? COLORS.cyan.border + '99' : COLORS.red.border + '99'),
                    borderColor: top10.map(r => r.valor > 0 ? COLORS.cyan.border : COLORS.red.border),
                    borderWidth: 1,
                    borderRadius: 6,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: ctx => ctx.parsed.x.toFixed(1) + '%' } }
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

    // Bind filters
    document.getElementById('empleo-dimension').addEventListener('change', renderEmpleoDemo);
    document.getElementById('empleo-periodo').addEventListener('change', renderEmpleoSector);

    /* ============================================================
       PAGE: SALARIOS Y BRECHAS
       ============================================================ */
    let salariosRendered = false;

    function renderSalarios() {
        if (salariosRendered) return;
        renderSalariosSeries();
        renderBrechas();
        renderBrechasTrend();
        salariosRendered = true;
    }

    // Wage evolution over time
    function renderSalariosSeries() {
        const data = DATA.salariosSeries;
        const byTipo = groupBy(data, 'tipo');
        const years = uniqueSorted(data.map(r => r.anio));

        const datasets = Object.entries(byTipo).map(([tipo, rows]) => {
            const c = COLORS.indigo;
            const map = {};
            rows.forEach(r => map[r.anio] = r.valor);
            return {
                label: tipo,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-salarios-series', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => '$' + v.toFixed(0) } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } }
                }
            }
        });
    }

    // Wage gaps by dimension - latest year
    function renderBrechas() {
        const tipo = document.getElementById('brecha-tipo').value;
        const sheetMap = {
            'educacion': 'educacion',
            'genero': 'genero',
            'etnia': 'etnia',
            'edad': 'edad',
            'estado_civil': 'generoCivil'
        };
        const sheetName = sheetMap[tipo];

        if (!DATA.brechasSalariales || !DATA.brechasSalariales[sheetName]) {
            makeChart('chart-brechas', { type: 'bar', data: { labels: ['Sin datos'], datasets: [{ data: [0] }] } });
            return;
        }

        const data = DATA.brechasSalariales[sheetName];
        const years = uniqueSorted(data.map(r => r.anio));
        const latestYear = years[years.length - 1];
        const latest = data.filter(r => r.anio === latestYear);

        // Get category field name
        const categoryField = tipo === 'educacion' ? 'nivelEducativo' :
            tipo === 'genero' ? 'sexo' :
                tipo === 'etnia' ? 'etnia' :
                    tipo === 'edad' ? 'grupoEdad' :
                        tipo === 'estado_civil' ? 'grupo' : 'sexo';

        makeChart('chart-brechas', {
            type: 'bar',
            data: {
                labels: latest.map(r => r[categoryField]),
                datasets: [{
                    label: 'Salario promedio ($)',
                    data: latest.map(r => +r.salarioPromedio),
                    backgroundColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: latest.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border),
                    borderWidth: 1,
                    borderRadius: 6,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: ctx => '$' + ctx.parsed.x.toFixed(2) } }
                }
            }
        });
    }

    // Wage trends by category over time
    function renderBrechasTrend() {
        const tipo = document.getElementById('brecha-tipo').value;
        const sheetMap = {
            'educacion': 'educacion',
            'genero': 'genero',
            'etnia': 'etnia',
            'edad': 'edad',
            'estado_civil': 'generoCivil'
        };
        const sheetName = sheetMap[tipo];

        if (!DATA.brechasSalariales || !DATA.brechasSalariales[sheetName]) {
            makeChart('chart-brechas-trend', { type: 'line', data: { labels: [], datasets: [] } });
            return;
        }

        const data = DATA.brechasSalariales[sheetName];
        const years = uniqueSorted(data.map(r => r.anio));

        // Get category field name
        const categoryField = tipo === 'educacion' ? 'nivelEducativo' :
            tipo === 'genero' ? 'sexo' :
                tipo === 'etnia' ? 'etnia' :
                    tipo === 'edad' ? 'grupoEdad' :
                        tipo === 'estado_civil' ? 'grupo' : 'sexo';

        // Group by category
        const byCategory = {};
        data.forEach(r => {
            const key = r[categoryField];
            if (!byCategory[key]) byCategory[key] = [];
            byCategory[key].push(r);
        });

        const datasets = Object.entries(byCategory).map(([category, rows], i) => {
            const c = COLOR_ARR[i % COLOR_ARR.length];
            const map = {};
            rows.forEach(r => map[r.anio] = r.salarioPromedio);
            return {
                label: category,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
            };
        });

        makeChart('chart-brechas-trend', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { ticks: { callback: v => '$' + v.toFixed(0) } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2) } }
                }
            }
        });
    }

    // Bind filter
    document.getElementById('brecha-tipo').addEventListener('change', () => {
        renderBrechas();
        renderBrechasTrend();
    });

    /* ============================================================
       PAGE: DISTRIBUCIÓN DEL CRECIMIENTO
       ============================================================ */
    let crecimientoRendered = false;

    function renderCrecimiento() {
        renderGIC();
        if (crecimientoRendered) return;
        renderCrecDemo();
        renderCrecEmpleo();
        crecimientoRendered = true;
    }

    // Growth Incidence Curve — by deciles with user-chosen years
    let gicYearsInitialized = false;
    function initGICYears() {
        if (gicYearsInitialized) return;
        const data = DATA.decilesIngresoAnual;
        if (!data || !data.length) return;
        const years = uniqueSorted(data.map(r => r.anio));
        const startSel = document.getElementById('gic-year-start');
        const endSel = document.getElementById('gic-year-end');
        years.forEach(y => {
            startSel.appendChild(Object.assign(document.createElement('option'), { value: y, textContent: y }));
            endSel.appendChild(Object.assign(document.createElement('option'), { value: y, textContent: y }));
        });
        startSel.value = years[0];
        endSel.value = years[years.length - 1];
        startSel.addEventListener('change', renderGIC);
        endSel.addEventListener('change', renderGIC);
        gicYearsInitialized = true;
    }

    function renderGIC() {
        initGICYears();
        const data = DATA.decilesIngresoAnual;
        if (!data || !data.length) {
            makeChart('chart-gic', { type: 'bar', data: { labels: [], datasets: [] } });
            return;
        }

        const startYear = +document.getElementById('gic-year-start').value;
        const endYear = +document.getElementById('gic-year-end').value;
        if (startYear >= endYear) {
            makeChart('chart-gic', { type: 'bar', data: { labels: ['Seleccione años distintos'], datasets: [{ data: [0] }] } });
            return;
        }

        const nYears = endYear - startYear;
        const startData = data.filter(r => r.anio === startYear);
        const endData = data.filter(r => r.anio === endYear);

        // Build GIC by matching deciles
        const gicPoints = [];
        for (let d = 1; d <= 10; d++) {
            const s = startData.find(r => r.decil === d);
            const e = endData.find(r => r.decil === d);
            if (s && e && s.ingresoPromedio > 0) {
                const growth = (Math.pow(e.ingresoPromedio / s.ingresoPromedio, 1 / nYears) - 1) * 100;
                gicPoints.push({ decil: d, growth });
            }
        }

        makeChart('chart-gic', {
            type: 'bar',
            data: {
                labels: gicPoints.map(r => 'Decil ' + r.decil),
                datasets: [{
                    label: 'Crecimiento anualizado (%)',
                    data: gicPoints.map(r => r.growth),
                    backgroundColor: gicPoints.map(r => r.growth >= 0 ? COLORS.cyan.border + '99' : COLORS.red.border + '99'),
                    borderColor: gicPoints.map(r => r.growth >= 0 ? COLORS.cyan.border : COLORS.red.border),
                    borderWidth: 1,
                    borderRadius: 6,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: {
                    x: { title: { display: true, text: 'Decil de ingreso' } },
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

    // Employment growth by sector
    function renderCrecEmpleo() {
        const periodo = document.getElementById('crec-empleo-periodo').value;
        const [startYear, endYear] = periodo.split('-').map(Number);
        const rawData = DATA.crecimientoEmpleoSector;

        // Group by sector
        const bySector = groupBy(rawData, 'sector');
        const results = [];
        Object.entries(bySector).forEach(([sector, rows]) => {
            const startRow = rows.find(r => r.anio === startYear);
            const endRow = rows.find(r => r.anio === endYear);
            if (startRow && endRow && startRow.empleoMiles && endRow.empleoMiles) {
                const growth = ((endRow.empleoMiles - startRow.empleoMiles) / startRow.empleoMiles) * 100;
                results.push({ sector, valor: growth });
            }
        });
        results.sort((a, b) => b.valor - a.valor);

        // Take top 10 sectors
        const top10 = results.slice(0, 10);

        makeChart('chart-crec-empleo', {
            type: 'bar',
            data: {
                labels: top10.map(r => r.sector),
                datasets: [{
                    label: 'Crecimiento del empleo (%)',
                    data: top10.map(r => +r.valor),
                    backgroundColor: top10.map(r => r.valor > 0 ? COLORS.cyan.border + '99' : COLORS.red.border + '99'),
                    borderColor: top10.map(r => r.valor > 0 ? COLORS.cyan.border : COLORS.red.border),
                    borderWidth: 1,
                    borderRadius: 6,
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                indexAxis: 'y',
                plugins: {
                    legend: { display: false },
                    tooltip: { callbacks: { label: ctx => ctx.parsed.x.toFixed(1) + '%' } }
                }
            }
        });
    }

    // Bind filters
    document.getElementById('crec-empleo-periodo').addEventListener('change', renderCrecEmpleo);

    /* ============================================================
       PAGE: DESIGUALDAD (unified with sub-tabs)
       ============================================================ */
    let desigualdadRendered = false;
    let selectedCountries = ['Ecuador'];

    function renderDesigualdad() {
        const activeTab = document.querySelector('#desigualdad-tabs .sub-tab.active');
        const tabId = activeTab ? activeTab.dataset.subtab : 'indicadores';

        if (tabId === 'indicadores') {
            renderGiniTax();
            renderGiniFull();
            renderGiniLAC();
        } else {
            renderPopulationPercentiles();
            renderSRIIncome();
            renderWIDChart('chart-wid-income-ec', DATA.widIngresoPercentiles, 'participacionEnElIngresoNacional(%)');
            renderWIDChart('chart-wid-wealth-ec', DATA.widRiquezaPercentiles, 'participacionEnLaRiquezaNacional(%)');
            if (!document.getElementById('country-selector').children.length) initLatamFilters();
            renderLatamChart();
        }
        desigualdadRendered = true;
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
                scales: { y: { min: 0.3, max: 0.7, title: { display: true, text: 'Coeficiente de Gini' } } },
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

    // SRI income by percentile
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
       PAGE: TRIBUTACIÓN
       ============================================================ */
    let tributacionRendered = false;

    function renderTributacion() {
        if (tributacionRendered) return;
        renderTaxComposition();
        renderTaxBurden();
        tributacionRendered = true;
    }

    function renderTaxComposition() {
        const data = DATA.tributacionGraficos.grafico16Composicion;
        if (!data || !data.length) return;
        const byType = groupBy(data, 'tipoImpuesto');
        const years = uniqueSorted(data.map(r => r.anio));
        const taxTypeColors = [COLORS.cyan, COLORS.amber, COLORS.red, COLORS.emerald, COLORS.indigo, COLORS.purple];
        let i = 0;
        const datasets = Object.entries(byType).map(([tipo, rows]) => {
            const c = taxTypeColors[i++ % taxTypeColors.length];
            const map = {}; rows.forEach(r => map[r.anio] = r.porcentajePib);
            return { label: tipo, data: years.map(y => map[y] ?? null), borderColor: c.border, backgroundColor: c.bg, fill: true, spanGaps: true };
        });
        makeChart('chart-tax-composition', {
            type: 'line', data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { stacked: true, beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: '% del PIB' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(2) + '%' } },
                    legend: { position: 'bottom', labels: { boxWidth: 12, padding: 8, font: { size: 11 } } }
                }
            }
        });
    }

    function renderTaxBurden() {
        const data = DATA.tributacionGraficos.grafico17Carga;
        if (!data || !data.length) return;
        const years = uniqueSorted(data.map(r => r.anio));
        const yearSelect = document.getElementById('tax-burden-year');
        if (!yearSelect.children.length) {
            years.forEach(y => { const o = document.createElement('option'); o.value = y; o.textContent = y; yearSelect.appendChild(o); });
            yearSelect.value = years[years.length - 1];
            yearSelect.addEventListener('change', renderTaxBurdenChart);
        }
        renderTaxBurdenChart();
    }

    function renderTaxBurdenChart() {
        const year = +document.getElementById('tax-burden-year').value;
        const data = DATA.tributacionGraficos.grafico17Carga.filter(r => r.anio === year);
        data.sort((a, b) => a.decil - b.decil);
        makeChart('chart-tax-burden', {
            type: 'bar',
            data: {
                labels: data.map(r => 'Decil ' + r.decil), datasets: [{
                    label: 'Carga tributaria (%)', data: data.map(r => +r.cargaTributariaPct),
                    backgroundColor: data.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border + '99'),
                    borderColor: data.map((_, i) => COLOR_ARR[i % COLOR_ARR.length].border), borderWidth: 1, borderRadius: 6
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: { y: { beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: 'Carga tributaria (%)' } } },
                plugins: { legend: { display: false }, tooltip: { callbacks: { label: ctx => ctx.parsed.y.toFixed(1) + '%' } } }
            }
        });
    }

    /* ============================================================
       INIT
       ============================================================ */
    renderInicio();

})();
