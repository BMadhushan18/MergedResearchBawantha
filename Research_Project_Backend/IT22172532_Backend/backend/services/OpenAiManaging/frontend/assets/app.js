const apiBaseEl = document.getElementById('apiBase');
const apiKeyEl = document.getElementById('apiKey');
const modelEl = document.getElementById('model');
const tempEl = document.getElementById('temperature');
const promptEl = document.getElementById('prompt');
const sendBtn = document.getElementById('sendBtn');
const statusEl = document.getElementById('status');
const responseEl = document.getElementById('response');

function setStatus(text) {
  statusEl.textContent = text;
}

function setResponse(text) {
  responseEl.textContent = text || '';
}

async function send() {
  const url = (apiBaseEl.value || '').trim();
  const prompt = (promptEl.value || '').trim();
  const model = modelEl.value;
  const apiKey = (apiKeyEl.value || '').trim();
  const temperature = Number(tempEl.value || 0) || 0;

  if (!url) {
    setStatus('Please enter API URL.');
    return;
  }
  if (!prompt) {
    setStatus('Please type a message first.');
    return;
  }

  const body = {
    prompt,
    model,
    temperature,
  };
  // Optional: if backend doesn't have env var, send key.
  if (apiKey) body.api_key = apiKey;

  setStatus('Sending...');
  setResponse('');
  sendBtn.disabled = true;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    const text = await res.text();
    let data;
    try { data = JSON.parse(text); } catch { data = null; }

    if (!res.ok) {
      const detail = data?.detail || text || `HTTP ${res.status}`;
      setStatus(`Error: ${detail}`);
      return;
    }

    // Expected: { ok: true, model, text }
    const modelOut = data?.model || model;
    const messageOut = data?.text ?? JSON.stringify(data, null, 2);

    setStatus(`OK (${modelOut})`);
    setResponse(messageOut);
  } catch (err) {
    setStatus(`Network error: ${err?.message || err}`);
  } finally {
    sendBtn.disabled = false;
  }
}

sendBtn.addEventListener('click', send);

promptEl.addEventListener('keydown', (e) => {
  // Ctrl+Enter to send
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
    e.preventDefault();
    send();
  }
});
