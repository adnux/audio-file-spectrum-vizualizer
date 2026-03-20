/* Audio Spectrum Visualizer — frontend logic */

const dropZone    = document.getElementById('dropZone');
const fileInput   = document.getElementById('fileInput');
const fileListEl  = document.getElementById('fileList');
const fileItems   = document.getElementById('fileItems');
const analyzeBtn  = document.getElementById('analyzeBtn');
const clearBtn    = document.getElementById('clearBtn');
const progressEl  = document.getElementById('progress');
const progressMsg = document.getElementById('progressMsg');
const resultsEl   = document.getElementById('results');
const chartEl     = document.getElementById('chart');
const logScaleCb  = document.getElementById('logScale');
const smoothingCb = document.getElementById('smoothing');
const maxFreqIn   = document.getElementById('maxFreq');

let selectedFiles = [];   // File objects
let lastResults   = null; // most recent analysis results

// ── File selection ──────────────────────────────────────────────────────────

fileInput.addEventListener('change', () => addFiles([...fileInput.files]));

dropZone.addEventListener('click', () => fileInput.click());
dropZone.addEventListener('dragover', e => { e.preventDefault(); dropZone.classList.add('dragover'); });
dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));
dropZone.addEventListener('drop', e => {
  e.preventDefault();
  dropZone.classList.remove('dragover');
  addFiles([...e.dataTransfer.files].filter(f => f.type.startsWith('audio/') || /\.(mp3|wav|flac|ogg|aac|m4a|opus|wma|alac)$/i.test(f.name)));
});

function addFiles(files) {
  const existing = new Set(selectedFiles.map(f => f.name + f.size));
  files.forEach(f => { if (!existing.has(f.name + f.size)) selectedFiles.push(f); });
  renderFileList();
}

function removeFile(idx) {
  selectedFiles.splice(idx, 1);
  renderFileList();
}

function renderFileList() {
  fileItems.innerHTML = '';
  selectedFiles.forEach((f, i) => {
    const li = document.createElement('li');
    li.innerHTML = `
      <span class="name" title="${esc(f.name)}">🎵 ${esc(f.name)}</span>
      <span class="size">${fmtSize(f.size)}</span>
      <button class="remove" title="Remove" onclick="removeFile(${i})">✕</button>`;
    fileItems.appendChild(li);
  });
  fileListEl.querySelector('h2').textContent = 'Selected files';
  fileListEl.classList.toggle('hidden', selectedFiles.length === 0);
  analyzeBtn.disabled = selectedFiles.length === 0;
}

function renderAnalyzedList(results) {
  fileItems.innerHTML = '';
  results.forEach(r => {
    const li = document.createElement('li');
    const info = r.error
      ? `<span class="badge error">Error</span>`
      : `<span class="badge">${r.codec?.toUpperCase() || '?'}</span>
         <span class="size">${r.sampleRate ? r.sampleRate / 1000 + ' kHz' : ''}</span>
         <span class="size">${r.channels === 2 ? 'Stereo' : r.channels === 1 ? 'Mono' : ''}</span>
         <span class="size">${r.duration ? fmtDuration(r.duration) : ''}</span>`;
    li.innerHTML = `<span class="name" title="${esc(r.filename)}">🎵 ${esc(r.filename)}</span>${info}`;
    fileItems.appendChild(li);
  });
  fileListEl.querySelector('h2').textContent = 'Analyzed files';
  fileListEl.classList.remove('hidden');
}

clearBtn.addEventListener('click', () => {
  selectedFiles = [];
  lastResults = null;
  renderFileList();
  resultsEl.classList.add('hidden');
  fileInput.value = '';
});

// ── Analysis ────────────────────────────────────────────────────────────────

analyzeBtn.addEventListener('click', analyze);

async function analyze() {
  if (!selectedFiles.length) return;

  analyzeBtn.disabled = true;
  resultsEl.classList.add('hidden');
  progressMsg.textContent = `Analyzing ${selectedFiles.length} file(s)…`;
  progressEl.classList.remove('hidden');

  const form = new FormData();
  selectedFiles.forEach(f => form.append('files', f, f.name));

  try {
    const res = await fetch('/api/analyze', { method: 'POST', body: form });
    if (!res.ok) throw new Error(`Server error: ${res.status}`);
    lastResults = await res.json();
    renderChart(lastResults);
    renderAnalyzedList(lastResults);
  } catch (err) {
    showError(err.message);
  } finally {
    progressEl.classList.add('hidden');
    analyzeBtn.disabled = false;
  }
}

// ── Chart rendering ─────────────────────────────────────────────────────────

logScaleCb.addEventListener('change', () => lastResults && renderChart(lastResults));
smoothingCb.addEventListener('change', () => lastResults && renderChart(lastResults));
maxFreqIn.addEventListener('change', () => lastResults && renderChart(lastResults));

const PALETTE = [
  '#6c63ff','#00d4aa','#ff6b6b','#ffd166','#06d6a0',
  '#118ab2','#ef476f','#f78c6b','#a8dadc','#e9c46a'
];

function renderChart(results) {
  const maxFreq  = Math.max(100, parseInt(maxFreqIn.value, 10) || 20000);
  const useLog   = logScaleCb.checked;
  const smooth   = smoothingCb.checked;

  const traces = [];
  const errors = [];

  results.forEach((r, i) => {
    if (r.error) { errors.push(`${r.filename}: ${r.error}`); return; }
    if (!r.spectrum || !r.spectrum.length) return;

    let bins = r.spectrum.filter(b => b.frequency > 0 && b.frequency <= maxFreq);
    if (smooth) bins = gaussianSmooth(bins, 5);

    traces.push({
      x: bins.map(b => b.frequency),
      y: bins.map(b => b.magnitude),
      type: 'scatter',
      mode: 'lines',
      name: r.filename,
      line: { color: PALETTE[i % PALETTE.length], width: 1.5 },
      hovertemplate: '<b>%{fullData.name}</b><br>%{x:.1f} Hz<br>%{y:.1f} dBFS<extra></extra>'
    });
  });

  if (traces.length === 0 && errors.length === 0) { showError('No spectrum data returned.'); return; }

  const layout = {
    paper_bgcolor: '#1a1d27',
    plot_bgcolor:  '#1a1d27',
    font:  { color: '#e8eaf0', family: "'Segoe UI', system-ui, sans-serif", size: 12 },
    xaxis: {
      title: 'Frequency (Hz)',
      type:  useLog ? 'log' : 'linear',
      gridcolor: '#2e3250',
      zerolinecolor: '#2e3250',
      tickformat: useLog ? undefined : ',d',
      range: useLog ? [Math.log10(10), Math.log10(maxFreq)] : [0, maxFreq],
    },
    yaxis: {
      title: 'Magnitude (dBFS)',
      gridcolor: '#2e3250',
      zerolinecolor: '#2e3250',
      range: [-120, 0],
    },
    legend: { bgcolor: 'rgba(0,0,0,0)', bordercolor: '#2e3250', borderwidth: 1 },
    margin: { l: 60, r: 40, t: 20, b: 60 },
    hovermode: 'x unified',
    autosize: true,
  };

  Plotly.react(chartEl, traces, layout, { responsive: true, displayModeBar: true });
  resultsEl.classList.remove('hidden');

  if (errors.length) {
    errors.forEach(msg => {
      const div = document.createElement('div');
      div.className = 'error-badge';
      div.textContent = '⚠ ' + msg;
      resultsEl.appendChild(div);
    });
  }
}

function gaussianSmooth(bins, radius) {
  const out = bins.map(b => ({ ...b }));
  for (let i = 0; i < bins.length; i++) {
    let sum = 0, weight = 0;
    for (let j = Math.max(0, i - radius); j <= Math.min(bins.length - 1, i + radius); j++) {
      const w = Math.exp(-0.5 * ((i - j) / (radius / 2)) ** 2);
      sum += bins[j].magnitude * w;
      weight += w;
    }
    out[i].magnitude = sum / weight;
  }
  return out;
}

// ── Utilities ───────────────────────────────────────────────────────────────

function showError(msg) {
  progressEl.classList.add('hidden');
  const div = document.createElement('div');
  div.className = 'error-badge';
  div.textContent = '⚠ ' + msg;
  chartEl.replaceChildren(div);
  resultsEl.classList.remove('hidden');
}

function fmtSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

function fmtDuration(secs) {
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
}

function esc(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
