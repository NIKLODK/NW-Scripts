const interactiveSelector = [
    '.nav a',
    '.staff-tabs a',
    '.rules-nav a',
    '.button',
    '.steam-pill',
    '.test-pill',
    '.steam-login',
].join(', ');

const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const interactiveNodes = [...document.querySelectorAll(interactiveSelector)];
let audioContext = null;
let audioEnabled = false;
let hoverTick = 0;

function ensureAudio() {
    if (!window.AudioContext && !window.webkitAudioContext) {
        return null;
    }

    if (!audioContext) {
        const AudioCtor = window.AudioContext || window.webkitAudioContext;
        audioContext = new AudioCtor();
    }

    if (audioContext.state === 'suspended') {
        audioContext.resume();
    }

    audioEnabled = true;
    return audioContext;
}

function playPop({ frequency = 520, duration = 0.06, gain = 0.02, type = 'triangle' } = {}) {
    if (prefersReducedMotion.matches) {
        return;
    }

    const ctx = ensureAudio();
    if (!ctx || ctx.state !== 'running') {
        return;
    }

    const oscillator = ctx.createOscillator();
    const gainNode = ctx.createGain();
    const filter = ctx.createBiquadFilter();
    const now = ctx.currentTime;

    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, now);
    oscillator.frequency.exponentialRampToValueAtTime(Math.max(120, frequency * 0.65), now + duration);

    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(1800, now);

    gainNode.gain.setValueAtTime(0.0001, now);
    gainNode.gain.exponentialRampToValueAtTime(gain, now + 0.01);
    gainNode.gain.exponentialRampToValueAtTime(0.0001, now + duration);

    oscillator.connect(filter);
    filter.connect(gainNode);
    gainNode.connect(ctx.destination);

    oscillator.start(now);
    oscillator.stop(now + duration + 0.015);
}

function addRipple(node, event) {
    const rect = node.getBoundingClientRect();
    const ripple = document.createElement('span');
    const size = Math.max(rect.width, rect.height) * 1.1;

    ripple.className = 'ui-ripple';
    ripple.style.width = `${size}px`;
    ripple.style.height = `${size}px`;
    ripple.style.left = `${event.clientX - rect.left}px`;
    ripple.style.top = `${event.clientY - rect.top}px`;

    node.appendChild(ripple);
    ripple.addEventListener('animationend', () => ripple.remove(), { once: true });
}

function bindInteractiveNode(node) {
    node.addEventListener('pointerenter', () => {
        if (!audioEnabled) {
            return;
        }

        const now = performance.now();
        if (now - hoverTick < 55) {
            return;
        }

        hoverTick = now;
        playPop({ frequency: 680, duration: 0.04, gain: 0.012 });
    });

    node.addEventListener('pointerdown', (event) => {
        ensureAudio();
        node.classList.add('is-pressed');
        addRipple(node, event);
        playPop({ frequency: 420, duration: 0.08, gain: 0.026, type: 'sine' });
    });

    const release = () => node.classList.remove('is-pressed');
    node.addEventListener('pointerup', release);
    node.addEventListener('pointerleave', release);
    node.addEventListener('blur', release);
}

interactiveNodes.forEach(bindInteractiveNode);

window.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
        ensureAudio();
    }
}, { passive: true });

const parallaxRoot = document.querySelector('[data-parallax-root]');
const parallaxLayers = [...document.querySelectorAll('[data-parallax-layer]')];

if (parallaxRoot && parallaxLayers.length && !prefersReducedMotion.matches) {
    parallaxRoot.addEventListener('pointermove', (event) => {
        const rect = parallaxRoot.getBoundingClientRect();
        const px = (event.clientX - rect.left) / rect.width - 0.5;
        const py = (event.clientY - rect.top) / rect.height - 0.5;

        parallaxLayers.forEach((layer) => {
            const depth = Number(layer.dataset.parallaxLayer || '0');
            const moveX = px * 28 * depth;
            const moveY = py * 22 * depth;
            layer.style.transform = `translate3d(${moveX}px, ${moveY}px, 0)`;
        });
    });

    parallaxRoot.addEventListener('pointerleave', () => {
        parallaxLayers.forEach((layer) => {
            layer.style.transform = 'translate3d(0, 0, 0)';
        });
    });
}
