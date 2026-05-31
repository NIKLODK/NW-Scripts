const loginBtn = document.getElementById("loginBtn");
const modal = document.getElementById("loginModal");
const closeModal = document.getElementById("closeModal");
const logoutBtn = document.getElementById("logoutBtn");
const appNotice = document.getElementById("appNotice");
const applicationsGrid = document.getElementById("applicationsGrid");
const statusCard = document.getElementById("serverStatus");
const statusLabel = statusCard ? statusCard.querySelector(".status-label") : null;
const statusPlayers = document.getElementById("serverPlayers");
const statusJoinBtn = document.getElementById("serverJoinBtn");
const statusEndpoint = statusCard ? statusCard.getAttribute("data-endpoint") : null;

const state = {
  loggedIn: false,
  role: "guest",
};

const storedRole = localStorage.getItem("stavex_role");
if (storedRole) {
  state.loggedIn = true;
  state.role = storedRole;
}

function updateUI() {
  if (!appNotice || !applicationsGrid) {
    return;
  }

  if (!state.loggedIn) {
    appNotice.textContent = "Log ind for at se ansøgninger.";
    appNotice.classList.remove("success");
    applicationsGrid.hidden = true;
    return;
  }

  appNotice.textContent =
    state.role === "whitelisted"
      ? "Du er logget ind som whitelisted. Alle ansøgninger er synlige."
      : "Du er logget ind. Kun whitelist og unban ansøgninger vises.";
  appNotice.classList.add("success");
  applicationsGrid.hidden = false;

  document.querySelectorAll(".app-card").forEach((card) => {
    const visibility = card.getAttribute("data-visibility");
    if (visibility === "whitelist" && state.role !== "whitelisted") {
      card.style.display = "none";
    } else {
      card.style.display = "flex";
    }
  });
}

function openModal() {
  if (modal) {
    modal.setAttribute("aria-hidden", "false");
  }
}

function closeModalFn() {
  if (modal) {
    modal.setAttribute("aria-hidden", "true");
  }
}

if (loginBtn) {
  loginBtn.addEventListener("click", openModal);
}

if (closeModal) {
  closeModal.addEventListener("click", closeModalFn);
}

if (modal) {
  modal.addEventListener("click", (event) => {
    if (event.target === modal) {
      closeModalFn();
    }
  });
}

if (modal) {
  modal.querySelectorAll("[data-role]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const role = btn.getAttribute("data-role");
      state.loggedIn = true;
      state.role = role;
      localStorage.setItem("stavex_role", role);
      closeModalFn();
      updateUI();
    });
  });
}

if (logoutBtn) {
  logoutBtn.addEventListener("click", () => {
    state.loggedIn = false;
    state.role = "guest";
    localStorage.removeItem("stavex_role");
    closeModalFn();
    updateUI();
  });
}

updateUI();

async function loadServerStatus() {
  if (!statusCard || !statusLabel || !statusEndpoint) {
    return;
  }

  statusLabel.textContent = "Henter status...";
  statusCard.classList.remove("is-online", "is-offline");

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 4000);
    const response = await fetch(statusEndpoint, {
      cache: "no-store",
      signal: controller.signal,
    });
    clearTimeout(timeoutId);
    if (!response.ok) {
      throw new Error("Bad status response");
    }

    const data = await response.json();
    if (!data.configured) {
      statusLabel.textContent = "Server status ikke sat op endnu";
      statusCard.classList.add("is-offline");
      if (statusPlayers) {
        statusPlayers.textContent = "-";
      }
      return;
    }

    if (data.online) {
      statusLabel.textContent = "Online";
      statusCard.classList.add("is-online");
      if (statusPlayers) {
        const players = Number.isFinite(Number(data.players)) ? Number(data.players) : null;
        const maxPlayers = Number.isFinite(Number(data.maxPlayers)) ? Number(data.maxPlayers) : null;
        if (players === null) {
          statusPlayers.textContent = "Spillere ukendt";
        } else if (maxPlayers) {
          statusPlayers.textContent = `${players} spillere online / ${maxPlayers} slots`;
        } else {
          statusPlayers.textContent = `${players} spillere online`;
        }
      }
      if (statusJoinBtn && data.joinUrl) {
        statusJoinBtn.href = data.joinUrl;
      }
      return;
    }

    statusLabel.textContent = "Offline";
    statusCard.classList.add("is-offline");
    if (statusPlayers) {
      statusPlayers.textContent = "0 spillere online";
    }
    if (statusJoinBtn && data.joinUrl) {
      statusJoinBtn.href = data.joinUrl;
    }
  } catch (error) {
    statusLabel.textContent = "Offline";
    statusCard.classList.add("is-offline");
    if (statusPlayers) {
      statusPlayers.textContent = "0 spillere online";
    }
  }
}

if (statusCard) {
  loadServerStatus();
  setInterval(loadServerStatus, 30000);
}

const sectionRoutes = new Set(["hjem", "staff"]);

function resolveSectionSlug() {
  const hash = window.location.hash.replace("#", "");
  if (sectionRoutes.has(hash)) {
    return hash;
  }

  const path = window.location.pathname.replace(/\/+$/, "");
  const slug = path.split("/").pop() || "hjem";
  if (!sectionRoutes.has(slug)) {
    return null;
  }

  return slug;
}

function scrollToSectionFromLocation() {
  const slug = resolveSectionSlug();
  if (!slug) {
    return;
  }

  const target = document.getElementById(slug);
  if (target) {
    requestAnimationFrame(() => {
      target.scrollIntoView({ behavior: "auto", block: "start" });
    });
  }
}

document.querySelectorAll('a[href="/"], a[href="/hjem"], a[href="/staff"]').forEach((link) => {
  link.addEventListener("click", (event) => {
    const href = link.getAttribute("href");
    if (!href) {
      return;
    }

    const slug = href.replace(/^\/+/, "").replace(/\/+$/, "") || "hjem";
    if (!sectionRoutes.has(slug)) {
      return;
    }

    event.preventDefault();
    history.pushState({}, "", slug === "hjem" ? "/" : `/${slug}`);
    scrollToSectionFromLocation();
  });
});

window.addEventListener("popstate", scrollToSectionFromLocation);
window.addEventListener("hashchange", scrollToSectionFromLocation);
scrollToSectionFromLocation();
