const app = document.getElementById('app');
const statusText = document.getElementById('statusText');
const modeTag = document.getElementById('modeTag');
const installBtn = document.getElementById('installBtn');
const closeBtn = document.getElementById('closeBtn');
const illegalIcon = document.getElementById('illegalIcon');
const illegalWindow = document.getElementById('illegalWindow');
const windowCloseBtn = document.getElementById('windowCloseBtn');
const startBtn = document.getElementById('startBtn');
const taskIllegalBtn = document.getElementById('taskIllegalBtn');
const clock = document.getElementById('clock');
const query = new URLSearchParams(window.location.search);
const queryResourceName = query.get('res');

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : (queryResourceName || 'nw_laptop');

let open = false;
let mode = 'nui';

function setStatus(message) {
    statusText.textContent = message;
}

function bindPress(element, handler) {
    if (!element) return;

    const wrapped = (event) => {
        event.preventDefault();
        handler();
    };

    element.addEventListener('click', wrapped);
    element.addEventListener('mousedown', wrapped);
    element.addEventListener('pointerdown', wrapped);
    element.addEventListener('touchstart', wrapped, { passive: false });
}

function setClock() {
    const now = new Date();
    const value = now.toLocaleTimeString('da-DK', {
        hour: '2-digit',
        minute: '2-digit'
    });
    clock.textContent = value;
}

function setMode(nextMode) {
    mode = nextMode === 'dui' ? 'dui' : 'nui';
    modeTag.textContent = mode.toUpperCase();
}

function setVisible(state) {
    open = state;
    app.classList.toggle('hidden', !state);
    document.body.classList.toggle('ui-open', state);
}

function setIllegalWindow(state) {
    illegalWindow.classList.toggle('hidden', !state);
}

async function send(action, payload = {}) {
    try {
        const response = await fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        return await response.json();
    } catch (error) {
        return { ok: false, message: `UI callback failed (${resourceName})` };
    }
}

installBtn.addEventListener('click', async () => {
    if (!open) return;

    installBtn.disabled = true;
    setStatus('Installing app from SIM card...');

    const result = await send('installApp', {});
    setStatus(result?.message || (result?.ok ? 'Install complete.' : 'Install failed.'));

    installBtn.disabled = false;
});

const openIllegalApps = () => {
    if (!open) return;
    setIllegalWindow(true);
};

const closeIllegalApps = () => {
    setIllegalWindow(false);
};

bindPress(illegalIcon, openIllegalApps);
bindPress(startBtn, openIllegalApps);
bindPress(taskIllegalBtn, openIllegalApps);
bindPress(windowCloseBtn, closeIllegalApps);

closeBtn.addEventListener('click', async () => {
    if (!open) return;
    await send('close', {});
    setVisible(false);
});

window.addEventListener('keydown', async (event) => {
    if (!open) return;

    if (event.key === 'Escape') {
        await send('close', {});
        setVisible(false);
        setIllegalWindow(false);
    }
});

window.addEventListener('message', (event) => {
    let data = event.data;

    if (typeof data === 'string') {
        try {
            data = JSON.parse(data);
        } catch (_) {
            return;
        }
    }

    if (!data || typeof data !== 'object') return;

    if (data.action === 'open') {
        setMode(data.mode);
        setStatus('Ready to install app from SIM card.');
        setVisible(true);
        setIllegalWindow(false);
    }

    if (data.action === 'close') {
        setVisible(false);
        setIllegalWindow(false);
    }
});

setVisible(false);
setMode('nui');
setIllegalWindow(false);
setClock();
setInterval(setClock, 1000);

if (query.get('dui') === '1') {
    setMode('dui');
    setStatus('Ready to install app from SIM card.');
    setVisible(true);
    setIllegalWindow(false);
}
