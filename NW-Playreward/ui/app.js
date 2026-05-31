const uiRoot = document.getElementById('reward-ui');
const onlineTimeEl = document.getElementById('online-time');
const nextRewardEl = document.getElementById('next-reward');
const nextProgressEl = document.getElementById('next-progress');
const countdownEl = document.getElementById('countdown');

const state = {
    visible: false,
    payload: null
};

function pad(value) {
    return String(value).padStart(2, '0');
}

function formatDuration(totalSeconds) {
    const safe = Math.max(0, Math.floor(Number(totalSeconds) || 0));
    const hours = Math.floor(safe / 3600);
    const minutes = Math.floor((safe % 3600) / 60);
    const seconds = safe % 60;

    return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}

function currentEpoch() {
    return Math.floor(Date.now() / 1000);
}

function getLiveOnlineSeconds(payload) {
    if (!payload) {
        return 0;
    }

    const syncedAt = Number(payload.syncEpoch) || currentEpoch();
    const elapsed = Math.max(0, currentEpoch() - syncedAt);
    const base = Number(payload.baseOnlineSeconds) || 0;

    return base + elapsed;
}

function findNextMilestone(payload) {
    const milestones = Array.isArray(payload?.milestones) ? payload.milestones : [];

    for (const milestone of milestones) {
        if (milestone && milestone.claimed !== true) {
            return milestone;
        }
    }

    return null;
}

function render() {
    if (!state.visible || !state.payload) {
        uiRoot.classList.add('hidden');
        return;
    }

    uiRoot.classList.remove('hidden');

    const onlineSeconds = getLiveOnlineSeconds(state.payload);
    const nextMilestone = findNextMilestone(state.payload);

    onlineTimeEl.textContent = `Online: ${formatDuration(onlineSeconds)}`;

    if (!nextMilestone) {
        countdownEl.textContent = '00:00:00';
        nextRewardEl.textContent = 'Kom tilbage i morgen';
        nextProgressEl.style.width = '100%';
        return;
    }

    const targetSeconds = Number(nextMilestone.targetSeconds) || 0;
    const remaining = Math.max(0, targetSeconds - onlineSeconds);
    const progress = targetSeconds > 0
        ? Math.min(100, Math.floor((onlineSeconds / targetSeconds) * 100))
        : 0;

    countdownEl.textContent = formatDuration(remaining);
    nextRewardEl.textContent = nextMilestone.rewardText || 'Reward er ikke sat i config.';
    nextProgressEl.style.width = `${progress}%`;
}

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message !== 'object') {
        return;
    }

    if (message.action === 'visibility') {
        state.visible = message.visible === true;
        render();
        return;
    }

    if (message.action === 'update') {
        state.payload = message.data || null;
        render();
    }
});

setInterval(() => {
    if (state.visible && state.payload) {
        render();
    }
}, 1000);