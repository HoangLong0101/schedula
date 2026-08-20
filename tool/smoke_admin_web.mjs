import {writeFile} from 'node:fs/promises';

const endpoint = process.argv[2] ?? 'http://127.0.0.1:9223';
const targetUrl = process.argv[3] ?? 'https://schedula-admin-543b1.web.app/';
const screenshotPath = process.argv[4];

const tabs = await (await fetch(`${endpoint}/json/list`)).json();
const socket = new WebSocket(tabs[0].webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.onopen = resolve;
  socket.onerror = reject;
});

let sequence = 0;
const pending = new Map();
const errors = [];
socket.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const request = pending.get(message.id);
    if (!request) return;
    pending.delete(message.id);
    message.error ? request.reject(message.error) : request.resolve(message.result);
    return;
  }

  if (message.method === 'Runtime.exceptionThrown') {
    errors.push(message.params.exceptionDetails.text);
  } else if (message.method === 'Log.entryAdded' && message.params.entry.level === 'error') {
    errors.push(message.params.entry.text);
  }
};

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++sequence;
    pending.set(id, {resolve, reject});
    socket.send(JSON.stringify({id, method, params}));
  });
}

await send('Runtime.enable');
await send('Log.enable');
await send('Page.enable');
await send('Page.navigate', {url: targetUrl});
await new Promise((resolve) => setTimeout(resolve, 20_000));

const evaluation = await send('Runtime.evaluate', {
  expression: `({
    title: document.title,
    ready: document.readyState,
    flutterPane: Boolean(document.querySelector('flt-glass-pane')),
    sceneHosts: document.querySelectorAll('flt-scene-host').length,
    canvases: document.querySelectorAll('canvas').length,
    bodyChildren: document.body.children.length,
    bodyText: document.body.innerText.slice(0, 500),
  })`,
  returnByValue: true,
});

const state = evaluation.result.value;
if (screenshotPath) {
  const screenshot = await send('Page.captureScreenshot', {format: 'png'});
  await writeFile(screenshotPath, Buffer.from(screenshot.data, 'base64'));
}
console.log(JSON.stringify({state, errors}, null, 2));
socket.close();
if (!state.flutterPane || errors.length > 0) process.exitCode = 1;
