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
            if (pageId === 'desigualdad') renderDesigualdad();
            if (pageId === 'concentracion') renderConcentracion();
            if (pageId === 'latam') renderLatam();
        });
    });

    menuToggle.addEventListener('click', () => sidebar.classList.toggle('open'));

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
            .sort((a, b) => b['Año'] - a['Año']);
        const latestGini = giniEc.length ? giniEc[0] : null;

        // Latest NBI
        const nbiData = DATA.pobrezaPanel.filter(r => r.Indicador === 'NBI' && r.Nivel === 'Nacional' && r.Valor != null)
            .sort((a, b) => b['Año'] - a['Año']);
        const latestNBI = nbiData.length ? nbiData[0] : null;

        const cards = [
            { icon: '<img src="/Users/vero/Downloads/poverty.svg" width="30">', label: 'Pobreza', value: pobrezaVal ? pobrezaVal.valor.toFixed(1) + '%' : '—', year: pobrezaVal ? pobrezaVal.anio : '' },
            { icon: '⚠️', label: 'Pobreza Extrema', value: extremaVal ? extremaVal.valor.toFixed(1) + '%' : '—', year: extremaVal ? extremaVal.anio : '' },
            { icon: '🏘️', label: 'NBI', value: latestNBI ? latestNBI.Valor.toFixed(1) + '%' : '—', year: latestNBI ? latestNBI['Año'] : '' },
            { icon: '📊', label: 'Gini (Ecuador)', value: latestGini ? latestGini.valor.toFixed(3) : '—', year: latestGini ? latestGini['Año'] : '' },
        ];

        scContainer.innerHTML = cards.map(c => `
      <div class="card scorecard">
        <span class="sc-icon">${c.icon}</span>
        <div class="sc-value">${c.value}</div>
        <div class="sc-label">${c.label}</div>
        <div class="sc-year">${c.year}</div>
      </div>
    `).join('');

        // Historical series chart
        const seriesData = DATA.seriesHistoricas;
        const byIndicator = groupBy(seriesData, 'indicador');
        const years = uniqueSorted(seriesData.map(r => r.anio));

        const datasets = [];
        const colorMap = { 'Pobreza': COLORS.cyan, 'Pobreza extrema': COLORS.red };
        Object.entries(byIndicator).forEach(([ind, rows]) => {
            const c = colorMap[ind] || COLORS.indigo;
            const rowMap = {};
            rows.forEach(r => rowMap[r.anio] = r.valor);
            datasets.push({
                label: ind,
                data: years.map(y => rowMap[y] != null ? +rowMap[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: true,
            });
        });

        makeChart('chart-series-hist', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                scales: {
                    y: { beginAtZero: true, ticks: { callback: v => v + '%' } }
                },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });

        // Mini Gini chart
        const giniData = DATA.giniPanel.filter(r => r.categoria === 'Ecuador' && r.valor != null);
        const giniYears = uniqueSorted(giniData.map(r => r['Año']));
        const giniMap = {};
        giniData.forEach(r => giniMap[r['Año']] = r.valor);

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
        renderPobrezaNivel();
        renderPobrezaEtnia();
        renderPobrezaSexo();
        setupProvTable();
        pobrezaRendered = true;
    }

    function getSelectedPovIndicator() {
        return document.getElementById('pov-indicator').value;
    }

    // Nivel chart
    function renderPobrezaNivel() {
        const indicator = getSelectedPovIndicator();
        const filtered = DATA.pobrezaPanel.filter(r => r.Indicador === indicator && r.Valor != null);
        const byNivel = groupBy(filtered, 'Nivel');
        const years = uniqueSorted(filtered.map(r => r['Año']));
        const nivelColors = { 'Nacional': COLORS.cyan, 'Urbano': COLORS.indigo, 'Rural': COLORS.amber };

        const datasets = Object.entries(byNivel).map(([nivel, rows]) => {
            const c = nivelColors[nivel] || COLORS.purple;
            const map = {};
            rows.forEach(r => map[r['Año']] = r.Valor);
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
        const data = DATA.pobrezaSexoEtnia.filter(r => r.tipo_grupo === 'etnia' && r.indicador === mapInd && r.valor != null);
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
        const data = DATA.pobrezaSexoEtnia.filter(r => r.tipo_grupo === 'sexo' && r.indicador === mapInd && r.valor != null);
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

    // Bind indicator filter
    document.getElementById('pov-indicator').addEventListener('change', () => {
        renderPobrezaNivel();
        renderPobrezaEtnia();
        renderPobrezaSexo();
    });

    /* ============================================================
       PAGE: DESIGUALDAD (GINI)
       ============================================================ */
    function renderDesigualdad() {
        const data = DATA.giniPanel.filter(r => r.valor != null);
        const byCat = groupBy(data, 'categoria');
        const years = uniqueSorted(data.map(r => r['Año']));
        const catColors = {
            'Ecuador': COLORS.cyan,
            'Ecuador (Urbano)': COLORS.indigo,
            'Ecuador (Rural)': COLORS.amber,
            'LAC': COLORS.purple
        };

        const datasets = Object.entries(byCat).map(([cat, rows]) => {
            const c = catColors[cat] || COLORS.red;
            const map = {};
            rows.forEach(r => map[r['Año']] = r.valor);
            return {
                label: cat,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
                spanGaps: true,
            };
        });

        makeChart('chart-gini-full', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                scales: { y: { min: 0.3, max: 0.7, title: { display: true, text: 'Coeficiente de Gini' } } },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(3) : '—') } }
                }
            }
        });
    }

    /* ============================================================
       PAGE: CONCENTRACIÓN (WID Ecuador)
       ============================================================ */
    function renderConcentracion() {
        renderWIDChart('chart-wid-income-ec', DATA.widIngresoEc, 'Participación en el ingreso nacional (%)');
        renderWIDChart('chart-wid-wealth-ec', DATA.widRiquezaEc, 'Participación en la riqueza nacional (%)');
    }

    function renderWIDChart(canvasId, rawData, valueKey) {
        const data = rawData.filter(r => r[valueKey] != null);
        const byPerc = groupBy(data, 'Percentil');
        const years = uniqueSorted(data.map(r => r['Año']));
        const percColors = {
            'Bottom 50%': COLORS.emerald,
            'Top 10%': COLORS.amber,
            'Top 1%': COLORS.red,
            'Top 0.1%': COLORS.purple
        };

        const datasets = Object.entries(byPerc).map(([perc, rows]) => {
            const c = percColors[perc] || COLORS.cyan;
            const map = {};
            rows.forEach(r => map[r['Año']] = r[valueKey]);
            return {
                label: perc,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
                spanGaps: true,
            };
        });

        makeChart(canvasId, {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                scales: {
                    y: { beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: '%' } }
                },
                plugins: {
                    tooltip: { callbacks: { label: ctx => ctx.dataset.label + ': ' + ctx.parsed.y.toFixed(1) + '%' } }
                }
            }
        });
    }

    /* ============================================================
       PAGE: AMÉRICA LATINA
       ============================================================ */
    let selectedCountries = ['Ecuador'];

    function initLatamFilters() {
        const container = document.getElementById('country-selector');
        COUNTRY_LIST.forEach(c => {
            const chip = document.createElement('span');
            chip.className = 'country-chip' + (selectedCountries.includes(c) ? ' selected' : '');
            chip.textContent = c;
            chip.dataset.country = c;
            chip.addEventListener('click', () => {
                chip.classList.toggle('selected');
                if (chip.classList.contains('selected')) {
                    selectedCountries.push(c);
                } else {
                    selectedCountries = selectedCountries.filter(x => x !== c);
                }
                renderLatamChart();
            });
            container.appendChild(chip);
        });

        document.getElementById('latam-var').addEventListener('change', renderLatamChart);
        document.getElementById('latam-percentile').addEventListener('change', renderLatamChart);
    }

    function renderLatam() {
        if (!document.getElementById('country-selector').children.length) {
            initLatamFilters();
        }
        renderLatamChart();
    }

    function renderLatamChart() {
        const variable = document.getElementById('latam-var').value;
        const percentile = document.getElementById('latam-percentile').value;
        const rawData = variable === 'income' ? DATA.widIngresoALC : DATA.widRiquezaALC;
        const valueKey = variable === 'income'
            ? 'Participación en el ingreso nacional (%)'
            : 'Participación en la riqueza nacional (%)';

        const varLabel = variable === 'income' ? 'Ingreso' : 'Riqueza';
        document.getElementById('latam-chart-title').textContent =
            `Participación del ${percentile} en el ${varLabel} Nacional`;

        const filtered = rawData.filter(r => r.Percentil === percentile && selectedCountries.includes(r['País']) && r[valueKey] != null);
        const byCountry = groupBy(filtered, 'País');
        const allYears = uniqueSorted(filtered.map(r => r['Año']));

        // Use only years >= 1980 for readability
        const years = allYears.filter(y => y >= 1980);

        const datasets = Object.entries(byCountry).map(([country, rows]) => {
            const c = COUNTRY_COLORS[country] || COLORS.cyan;
            const map = {};
            rows.forEach(r => map[r['Año']] = r[valueKey]);
            const isEcuador = country === 'Ecuador';
            return {
                label: country,
                data: years.map(y => map[y] != null ? +map[y] : null),
                borderColor: c.border,
                backgroundColor: c.bg,
                fill: false,
                spanGaps: true,
                borderWidth: isEcuador ? 3.5 : 2,
                order: isEcuador ? 0 : 1,
            };
        });

        makeChart('chart-latam', {
            type: 'line',
            data: { labels: years, datasets },
            options: {
                responsive: true, maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                scales: {
                    y: { beginAtZero: true, ticks: { callback: v => v + '%' }, title: { display: true, text: '%' } }
                },
                plugins: {
                    tooltip: {
                        callbacks: { label: ctx => ctx.dataset.label + ': ' + (ctx.parsed.y != null ? ctx.parsed.y.toFixed(1) + '%' : '—') }
                    },
                    legend: {
                        position: 'bottom',
                        labels: { boxWidth: 12, padding: 10, font: { size: 11 } }
                    }
                }
            }
        });
    }

    /* ============================================================
       INIT
       ============================================================ */
    renderInicio();

})();
