const DEFAULT_UI_CONFIG = {
    serverName: "Stavex RP",
    website: "stavexrp.xyz",
    discord: "discord.gg/stavex",
    backgrounds: [
        "https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=2200&q=80",
        "https://images.unsplash.com/photo-1511882150382-421056c89033?auto=format&fit=crop&w=2200&q=80",
        "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1b?auto=format&fit=crop&w=2200&q=80",
        "https://images.unsplash.com/photo-1507608616759-54f48f0af0ee?auto=format&fit=crop&w=2200&q=80"
    ],
    tips: [
        "Velkommen! Vi gor klar til at loade serveren.",
        "Tip: Brug /report hvis du har brug for hjaelp.",
        "Tip: Hold oje med Discord for drift-beskeder."
    ],
    tipRotateMs: 7000
};

const UI_CONFIG = {
    ...DEFAULT_UI_CONFIG,
    ...(window.NW_CONFIG || {})
};

if (!Array.isArray(UI_CONFIG.backgrounds)) {
    UI_CONFIG.backgrounds = [...DEFAULT_UI_CONFIG.backgrounds];
}

if (!Array.isArray(UI_CONFIG.tips) || UI_CONFIG.tips.length === 0) {
    UI_CONFIG.tips = [...DEFAULT_UI_CONFIG.tips];
}

if (typeof UI_CONFIG.tipRotateMs !== "number" || UI_CONFIG.tipRotateMs < 1500) {
    UI_CONFIG.tipRotateMs = DEFAULT_UI_CONFIG.tipRotateMs;
}

const dom = {
    serverName: document.getElementById("server-name"),
    stageText: document.getElementById("stage-text"),
    progressText: document.getElementById("progress-text"),
    progressBar: document.getElementById("progress-bar"),
    phaseName: document.getElementById("phase-name"),
    tipLine: document.getElementById("tip-line"),
    clock: document.getElementById("clock"),
    slideA: document.getElementById("bg-slide-a"),
    slideB: document.getElementById("bg-slide-b"),
    websiteLink: document.getElementById("website-link"),
    websiteText: document.getElementById("website-text"),
    discordLink: document.getElementById("discord-link"),
    discordText: document.getElementById("discord-text")
};

const state = {
    visualProgress: 0,
    targetProgress: 0,
    initCount: 0,
    dataFileCount: 0,
    activeSlide: "a",
    tipIndex: 0,
    currentLoadItem: ""
};

function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
}

function formatPercent(value) {
    return `${Math.round(value)}%`;
}

function normalizeMessage(line) {
    if (!line || typeof line !== "string") {
        return "";
    }

    return line.replace(/\^./g, "").replace(/[\r\n]+/g, " ").trim();
}

function cleanItemName(text) {
    const cleaned = normalizeMessage(text)
        .replace(/^[@/\\]+/, "")
        .replace(/["'`,;]+/g, "")
        .trim();

    if (!cleaned) {
        return "";
    }

    if (cleaned.length > 80) {
        return cleaned.slice(0, 80);
    }

    return cleaned;
}

function parseLoadItemFromLine(line) {
    const cleaned = normalizeMessage(line);
    if (!cleaned) {
        return "";
    }

    const patterns = [
        /(?:starting|started|stopping|stopped|loading|loaded)\s+resource\s+([a-zA-Z0-9_.-]+)/i,
        /@([a-zA-Z0-9_.-]+)\//,
        /(?:script|resource|file)\s*[:=-]?\s*([a-zA-Z0-9_./@-]+\.(?:lua|js|ts|json|meta))/i,
        /\b([a-zA-Z0-9_.-]+\.(?:lua|js|ts|json|meta))\b/
    ];

    for (const pattern of patterns) {
        const match = cleaned.match(pattern);
        if (match && match[1]) {
            return cleanItemName(match[1]);
        }
    }

    return "";
}

function parseLoadItemFromPayload(payload) {
    if (!payload || typeof payload !== "object") {
        return "";
    }

    const directKeys = [
        "resourceName",
        "resource",
        "scriptName",
        "script",
        "fileName",
        "file",
        "name",
        "module"
    ];

    for (const key of directKeys) {
        if (typeof payload[key] === "string") {
            const asItem = parseLoadItemFromLine(payload[key]) || cleanItemName(payload[key]);
            if (asItem && !/^(init|start|end|load)/i.test(asItem)) {
                return asItem;
            }
        }
    }

    if (typeof payload.message === "string") {
        return parseLoadItemFromLine(payload.message);
    }

    return "";
}

function setCurrentLoadItem(item) {
    const nextItem = cleanItemName(item);
    if (nextItem) {
        state.currentLoadItem = nextItem;
    }
}

function setProgress(nextProgress, phaseName, stageText) {
    state.targetProgress = clamp(Math.max(state.targetProgress, nextProgress), 0, 100);

    if (phaseName) {
        dom.phaseName.textContent = phaseName;
    }

    if (stageText) {
        dom.stageText.textContent = stageText;
    }
}

function setTipLine(line) {
    if (!line || typeof line !== "string") {
        return;
    }

    dom.tipLine.textContent = line;
}

function showNextTip() {
    if (!UI_CONFIG.tips.length) {
        return;
    }

    const tip = UI_CONFIG.tips[state.tipIndex % UI_CONFIG.tips.length];
    setTipLine(tip);
    state.tipIndex += 1;
}

function startTipsRotation() {
    showNextTip();
    setInterval(showNextTip, UI_CONFIG.tipRotateMs);
}

function updateClock() {
    const now = new Date();
    dom.clock.textContent = now.toLocaleTimeString("da-DK", { hour12: false });
}

function startClock() {
    updateClock();
    setInterval(updateClock, 1000);
}

function applySlideImage(element, imageUrl) {
    element.style.backgroundImage = `url("${imageUrl}")`;
}

function startBackgroundSlideshow() {
    if (!UI_CONFIG.backgrounds.length) {
        return;
    }

    let bgIndex = 0;
    applySlideImage(dom.slideA, UI_CONFIG.backgrounds[0]);

    setInterval(() => {
        bgIndex = (bgIndex + 1) % UI_CONFIG.backgrounds.length;
        const nextUrl = UI_CONFIG.backgrounds[bgIndex];

        if (state.activeSlide === "a") {
            applySlideImage(dom.slideB, nextUrl);
            dom.slideB.classList.add("is-active");
            dom.slideA.classList.remove("is-active");
            state.activeSlide = "b";
            return;
        }

        applySlideImage(dom.slideA, nextUrl);
        dom.slideA.classList.add("is-active");
        dom.slideB.classList.remove("is-active");
        state.activeSlide = "a";
    }, 8000);
}

function smoothProgress() {
    if (state.visualProgress < state.targetProgress) {
        const distance = state.targetProgress - state.visualProgress;
        state.visualProgress += Math.max(0.15, distance * 0.08);
        state.visualProgress = clamp(state.visualProgress, 0, state.targetProgress);
    }

    dom.progressBar.style.width = `${state.visualProgress.toFixed(2)}%`;
    dom.progressText.textContent = formatPercent(state.visualProgress);

    requestAnimationFrame(smoothProgress);
}

function startFallbackProgress() {
    setInterval(() => {
        if (state.targetProgress < 90) {
            setProgress(state.targetProgress + 0.35);
        }
    }, 450);
}

function withProtocol(url) {
    if (!url) {
        return "#";
    }

    if (/^https?:\/\//i.test(url)) {
        return url;
    }

    return `https://${url}`;
}

function handleLogLine(line) {
    const cleaned = normalizeMessage(line);
    if (!cleaned) {
        return;
    }

    const item = parseLoadItemFromLine(cleaned);
    if (item) {
        setCurrentLoadItem(item);

        if (dom.phaseName.textContent === "Indlæser scripts") {
            dom.stageText.textContent = `Indlæser ${state.currentLoadItem}...`;
        }
    }
}

function handleFiveMEvent(payload) {
    const eventName = payload.eventName || payload.type;
    const payloadItem = parseLoadItemFromPayload(payload);
    if (payloadItem) {
        setCurrentLoadItem(payloadItem);
    }

    switch (eventName) {
        case "startInitFunctionOrder": {
            state.initCount = Number(payload.count) || 1;
            setProgress(5, "Initialisering", "Initialiserer server scripts...");
            break;
        }
        case "initFunctionInvoking": {
            const idx = (Number(payload.idx) || 0) + 1;
            const pct = 5 + (idx / Math.max(state.initCount, 1)) * 45;
            const loadingText = state.currentLoadItem
                ? `Indlæser ${state.currentLoadItem}...`
                : "Indlæser server scripts...";
            setProgress(pct, "Indlæser scripts", loadingText);
            break;
        }
        case "startDataFileEntries": {
            state.dataFileCount = Number(payload.count) || 1;
            setProgress(52, "Indlæser assets", "Scanner datafiler...");
            break;
        }
        case "onDataFileEntry": {
            const idx = (Number(payload.idx) || 0) + 1;
            const pct = 52 + (idx / Math.max(state.dataFileCount, 1)) * 28;
            const loadingText = state.currentLoadItem
                ? `Behandler ${state.currentLoadItem}...`
                : "Behandler datafiler...";
            setProgress(pct, "Indlæser assets", loadingText);
            break;
        }
        case "performMapLoadFunction": {
            setProgress(86, "Map load", "Map data bygges og synkroniseres...");
            break;
        }
        case "endDataFileEntries": {
            setProgress(92, "Validering", "Kontrollerer sidste komponenter...");
            break;
        }
        case "loadProgress": {
            if (typeof payload.loadFraction === "number") {
                const loadPct = clamp(payload.loadFraction * 100, 0, 100);
                const phase = loadPct >= 99 ? "Klar" : "Synkroniserer";
                const status = loadPct >= 99 ? "Du joiner nu serveren..." : "Bygger netvaerkssession...";
                setProgress(loadPct, phase, status);
            }
            break;
        }
        case "onLogLine": {
            handleLogLine(payload.message);
            break;
        }
        default: {
            if (typeof payload.message === "string") {
                handleLogLine(payload.message);
            }
        }
    }
}

function bootstrap() {
    dom.serverName.textContent = UI_CONFIG.serverName;
    dom.websiteText.textContent = UI_CONFIG.website;
    dom.websiteLink.href = withProtocol(UI_CONFIG.website);
    dom.discordText.textContent = UI_CONFIG.discord;
    dom.discordLink.href = withProtocol(UI_CONFIG.discord);

    startClock();
    startBackgroundSlideshow();
    startTipsRotation();
    smoothProgress();
    startFallbackProgress();

    window.addEventListener("message", (event) => {
        if (!event || !event.data || typeof event.data !== "object") {
            return;
        }

        handleFiveMEvent(event.data);
    });
}

bootstrap();