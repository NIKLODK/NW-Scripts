let myIdentifier = ""; 
let unlockedSkills = [];
let missionState = null;
let skillPoints = 0;
let skillTooltipEl = null;
let skillTreeDragInitialized = false;
let isGangOwner = false;
let gangRanks = [];
let latestMembers = [];

function getNuiAssetPath(path) {
    try {
        return `https://cfx-nui-${GetParentResourceName()}/${path}`;
    } catch (e) {
        return `./${path}`;
    }
}

function applyLogoPath() {
    const logo = document.querySelector('.sidebar-logo');
    if (!logo) return;

    const localPath = 'images/stavex.png';
    logo.src = getNuiAssetPath(localPath);
    logo.onerror = () => {
        logo.onerror = null;
        logo.src = localPath;
    };
}

function initInviteInput() {
    const inviteInput = document.getElementById('invite-player-id');
    if (!inviteInput || inviteInput.dataset.boundInvite === '1') return;

    inviteInput.dataset.boundInvite = '1';
    inviteInput.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault();
            invitePlayer();
        }
    });
}

function initRankInput() {
    const rankInput = document.getElementById('new-rank-name');
    if (!rankInput || rankInput.dataset.boundRankInput === '1') return;

    rankInput.dataset.boundRankInput = '1';
    rankInput.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            event.preventDefault();
            createRank();
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    applyLogoPath();
    initInviteInput();
    initRankInput();
});

const skillTreePan = {
    x: 0,
    y: 0,
    minX: -170,
    maxX: 170,
    minY: -130,
    maxY: 130,
    isDragging: false,
    hasMoved: false,
    startX: 0,
    startY: 0,
    startPanX: 0,
    startPanY: 0
};

const MISSION_POOL = [
    { id: 201, title: "BUTIKSRØVERI", desc: "Fuldfør et butiksrøveri via NW-Storerobbery.", rewardText: "Belønning gives ved fuldførelse." },
    { id: 202, title: "SKRALDERUTE", desc: "Fuldfør en skraldemand route via Trasherjob.", rewardText: "Belønning gives ved fuldførelse." },
    { id: 99, title: "HVIDVASK MISSION", desc: "Fuldfør en hvidvask via NW-Laundering.", rewardText: "Beløb afhænger af sorte penge." }
];
let missionCatalog = [...MISSION_POOL];

const MISSION_INTERVAL_SECONDS = 15 * 60;
const MISSION_CYCLE_COOLDOWN_SECONDS = 60 * 60;
const DEFAULT_MISSION_STATE = {
    completedMissionIds: [],
    activeMissionId: 0,
    nextMissionAt: 0,
    cycleCooldownUntil: 0
};

const skillData = {
    start: { title: "START PUNKT", desc: "Din bandes fundament. Herfra starter alle teknologier.", req: null, cost: 1 },
    zones: { title: "BANDE ZONER", desc: "Giver jer mulighed for at overtage territorier på kortet.", req: "start", cost: 5 },

    members_1: { title: "MEDLEMMER I", desc: "Øger bandepladser med +5.", req: "start", cost: 1 },
    members_2: { title: "MEDLEMMER II", desc: "Øger bandepladser med +10.", req: "members_1", cost: 5 },
    members_3: { title: "MEDLEMMER III", desc: "Øger bandepladser med +15.", req: "members_2", cost: 10 },
    members_4: { title: "MEDLEMMER IV", desc: "Øger bandepladser med +20.", req: "members_3", cost: 20 },
    members_5: { title: "MEDLEMMER V", desc: "Øger bandepladser med +25 (op til 30).", req: "members_4", cost: 30 },

    eup_1: { title: "EUP I", desc: "Låser 1 EUP slot op.", req: "start", cost: 2 },
    eup_2: { title: "EUP II", desc: "Låser 2 EUP slots op.", req: "eup_1", cost: 3 },
    eup_3: { title: "EUP III", desc: "Låser 3 EUP slots op.", req: "eup_2", cost: 5 },
    eup_4: { title: "EUP IV", desc: "Låser 4 EUP slots op.", req: "eup_3", cost: 5 },
    eup_5: { title: "EUP V", desc: "Låser 5 EUP slots op.", req: "eup_4", cost: 10 }
};

const SKILL_GRAPH = [
    { id: 'start', x: 50, y: 90, label: 'START', short: 'CORE' },
    { id: 'zones', x: 50, y: 64, label: 'ZONER', short: 'ZN', req: 'start' },

    { id: 'members_1', x: 22, y: 82, label: 'MEDLEM I', short: 'M1', req: 'start' },
    { id: 'members_2', x: 14, y: 66, label: 'MEDLEM II', short: 'M2', req: 'members_1' },
    { id: 'members_3', x: 8, y: 50, label: 'MEDLEM III', short: 'M3', req: 'members_2' },
    { id: 'members_4', x: 14, y: 34, label: 'MEDLEM IV', short: 'M4', req: 'members_3' },
    { id: 'members_5', x: 22, y: 18, label: 'MEDLEM V', short: 'M5', req: 'members_4' },

    { id: 'eup_1', x: 78, y: 82, label: 'EUP I', short: 'E1', req: 'start' },
    { id: 'eup_2', x: 86, y: 66, label: 'EUP II', short: 'E2', req: 'eup_1' },
    { id: 'eup_3', x: 92, y: 50, label: 'EUP III', short: 'E3', req: 'eup_2' },
    { id: 'eup_4', x: 86, y: 34, label: 'EUP IV', short: 'E4', req: 'eup_3' },
    { id: 'eup_5', x: 78, y: 18, label: 'EUP V', short: 'E5', req: 'eup_4' }
];

function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
}

function applySkillTreePan() {
    const nodesWrap = document.getElementById('skill-nodes');
    const linesSvg = document.getElementById('skill-lines');
    if (!nodesWrap || !linesSvg) return;

    const transform = `translate(${skillTreePan.x}px, ${skillTreePan.y}px)`;
    nodesWrap.style.transform = transform;
    linesSvg.style.transform = transform;
}

function initSkillTreeDrag(canvas) {
    if (!canvas || skillTreeDragInitialized) return;
    skillTreeDragInitialized = true;

    canvas.addEventListener('mousedown', (event) => {
        if (event.button !== 0) return;
        skillTreePan.isDragging = true;
        skillTreePan.hasMoved = false;
        skillTreePan.startX = event.clientX;
        skillTreePan.startY = event.clientY;
        skillTreePan.startPanX = skillTreePan.x;
        skillTreePan.startPanY = skillTreePan.y;
        canvas.classList.add('dragging');
    });

    window.addEventListener('mousemove', (event) => {
        if (!skillTreePan.isDragging) return;
        const dx = event.clientX - skillTreePan.startX;
        const dy = event.clientY - skillTreePan.startY;

        if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
            skillTreePan.hasMoved = true;
        }

        skillTreePan.x = clamp(skillTreePan.startPanX + dx, skillTreePan.minX, skillTreePan.maxX);
        skillTreePan.y = clamp(skillTreePan.startPanY + dy, skillTreePan.minY, skillTreePan.maxY);
        hideSkillTooltip();
        applySkillTreePan();
    });

    window.addEventListener('mouseup', () => {
        if (!skillTreePan.isDragging) return;
        skillTreePan.isDragging = false;
        canvas.classList.remove('dragging');

        if (skillTreePan.hasMoved) {
            setTimeout(() => {
                skillTreePan.hasMoved = false;
            }, 0);
        }
    });
}

function ensureSkillTooltip() {
    if (skillTooltipEl) return skillTooltipEl;
    const el = document.createElement('div');
    el.id = 'skill-tooltip';
    el.className = 'skill-tooltip';
    document.body.appendChild(el);
    skillTooltipEl = el;
    return skillTooltipEl;
}

function positionSkillTooltip(x, y) {
    if (!skillTooltipEl) return;
    const pad = 14;
    const rect = skillTooltipEl.getBoundingClientRect();

    let left = x + 18;
    let top = y + 18;

    if (left + rect.width > window.innerWidth - pad) {
        left = x - rect.width - 18;
    }
    if (top + rect.height > window.innerHeight - pad) {
        top = y - rect.height - 18;
    }
    if (left < pad) left = pad;
    if (top < pad) top = pad;

    skillTooltipEl.style.left = left + 'px';
    skillTooltipEl.style.top = top + 'px';
}

function showSkillTooltip(id, x, y) {
    const skill = skillData[id];
    if (!skill) return;
    const tooltip = ensureSkillTooltip();
    tooltip.innerHTML = `<span class="skill-tooltip-title">${skill.title}</span>${skill.desc}`;
    positionSkillTooltip(x, y);
    tooltip.classList.add('show');
}

function hideSkillTooltip() {
    if (!skillTooltipEl) return;
    skillTooltipEl.classList.remove('show');
}

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === "open") {
        document.body.style.display = "block";
        myIdentifier = data.myIdentifier;
        const sidebar = document.getElementById('tablet-sidebar');
        
        if (data.hasGang && data.gangData) {
            isGangOwner = !!data.isOwner;
            sidebar.style.display = "flex";
            document.getElementById('ui-gang-name').innerText = data.gangData.name;
            document.getElementById('ui-gang-level').innerText = data.gangData.level;

            skillPoints = Number(data.gangData.skill_points) || 0;
            const spEl = document.getElementById('skill-points');
            if (spEl) spEl.innerText = skillPoints;

            unlockedSkills = [];
            if (data.gangData.unlocked_skills) {
                if (Array.isArray(data.gangData.unlocked_skills)) {
                    unlockedSkills = data.gangData.unlocked_skills;
                } else if (typeof data.gangData.unlocked_skills === 'string') {
                    try {
                        const parsed = JSON.parse(data.gangData.unlocked_skills);
                        if (Array.isArray(parsed)) unlockedSkills = parsed;
                    } catch (e) {}
                }
            }
            if (!unlockedSkills.includes('start')) {
                unlockedSkills.push('start');
            }
            renderSkillTree();
                        
            const deleteBtn = document.getElementById('delete-gang-btn');
            if (deleteBtn) {
                if (data.isOwner) {
                    deleteBtn.innerText = "SLET BANDE";
                    deleteBtn.onclick = openDeleteModal;
                    deleteBtn.classList.remove('leave-style'); 
                } else {
                    deleteBtn.innerText = "FORLAD BANDE";
                    deleteBtn.onclick = leaveGang;
                    deleteBtn.classList.add('leave-style'); 
                }
            }

            if (data.members) updateMemberUI(data.members);
            fetchGangRanks();
            showPage('home');
        } else {
            isGangOwner = false;
            gangRanks = [];
            renderRankAdmin();
            sidebar.style.display = "none";
            showPage('start-screen');
        }
        applySavedSettings();
        fetchMissionState();
    } 
    else if (data.action === "close") {
        document.body.style.display = "none";
        closeModal(); 
        closeSkillInfo();
    }
    else if (data.type === "updateMembers") {
        updateMemberUI(data.members);
    }
});

// --- NAVIGATION ---
function showPage(pageId) {
    hideSkillTooltip();
    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    
    const targetPage = document.getElementById(pageId);
    if (targetPage) targetPage.classList.add('active');

    const activeBtn = document.getElementById('nav-' + pageId);
    if (activeBtn) activeBtn.classList.add('active');

    if (pageId === 'members') {
        fetch(`https://${GetParentResourceName()}/getMembers`, { method: 'POST', body: JSON.stringify({}) });
    }
    if (pageId === 'home') {
        fetchGangRanks();
    }
    if (pageId === 'missions') {
        fetchMissionState();
    }
}

// --- MEDLEMS LOGIK ---
function updateMemberUI(members) {
    const tableBody = document.getElementById('member-list-body');
    const onlineCount = document.getElementById('online-count');
    let onlineAmount = 0;
    
    if (!tableBody) return;
    tableBody.innerHTML = ''; 
    latestMembers = Array.isArray(members) ? members : [];

    if (!members || members.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="4" style="text-align:center;">Ingen medlemmer fundet</td></tr>';
        return;
    }

    const rankNames = Array.isArray(gangRanks) && gangRanks.length > 0
        ? gangRanks.map(rank => typeof rank === 'string' ? rank : rank.name).filter(Boolean)
        : ['Ejer', 'Medlem'];

    members.forEach(member => {
        if(member.online) onlineAmount++;
        const isMe = (member.identifier === myIdentifier);

        let actionButtons = '<small style="display:block; padding:10px; color:gray; text-align:center;">Ingen adgang</small>';
        if (isGangOwner && !isMe && member.rank !== 'Ejer') {
            const currentIndex = rankNames.indexOf(member.rank);
            const fallbackIndex = rankNames.length - 1;
            const rankIndex = currentIndex >= 0 ? currentIndex : fallbackIndex;
            const canPromote = rankIndex > 0 && rankNames[rankIndex - 1] !== 'Ejer';
            const canDegrade = rankIndex >= 0 && rankIndex < rankNames.length - 1;

            actionButtons = `
                <button onclick="changeRank('${member.identifier}', 'up')" ${canPromote ? '' : 'disabled'}>Promover</button>
                <button onclick="changeRank('${member.identifier}', 'down')" ${canDegrade ? '' : 'disabled'}>Degrader</button>
                <button class="kick-option" onclick="kickMember('${member.identifier}')">Smid ud</button>
            `;
        } else if (isMe) {
            actionButtons = '<small style="display:block; padding:10px; color:gray; text-align:center;">Dig selv</small>';
        }

        const row = `
            <tr>
                <td>${member.name} ${isMe ? '<span style="color:var(--accent); font-size:10px;">(DIG)</span>' : ''}</td>
                <td><span class="rank-badge">${member.rank}</span></td>
                <td><span class="status-dot ${member.online ? 'status-online' : 'status-offline'}"></span> ${member.online ? 'Online' : 'Offline'}</td>
                <td style="text-align: right;">
                    <div class="action-container">
                        <button class="dots-btn" onclick="toggleActionMenu(event, '${member.identifier}')">⋮</button>
                        <div id="dropdown-${member.identifier}" class="action-dropdown">${actionButtons}</div>
                    </div>
                </td>
            </tr>`;
        tableBody.innerHTML += row;
    });
    if (onlineCount) onlineCount.innerText = onlineAmount;
}

function toggleActionMenu(event, id) {
    event.stopPropagation();
    document.querySelectorAll('.action-dropdown').forEach(menu => {
        if (menu.id !== `dropdown-${id}`) menu.classList.remove('show');
    });
    const currentMenu = document.getElementById(`dropdown-${id}`);
    if (currentMenu) currentMenu.classList.toggle('show');
}

window.onclick = function(event) {
    if (!event.target.matches('.dots-btn')) {
        document.querySelectorAll('.action-dropdown').forEach(m => m.classList.remove('show'));
    }
}

function kickMember(identifier) {
    fetch(`https://${GetParentResourceName()}/kickMember`, { method: 'POST', body: JSON.stringify({ identifier: identifier }) });
}

function normalizeRanks(ranks) {
    if (!Array.isArray(ranks)) return [];

    const toBool = (value) => {
        if (typeof value === 'boolean') return value;
        if (typeof value === 'number') return value > 0;
        if (typeof value === 'string') {
            const normalized = value.trim().toLowerCase();
            if (normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on') return true;
            if (normalized === '0' || normalized === 'false' || normalized === 'no' || normalized === 'off' || normalized === '') return false;
        }
        return !!value;
    };

    return ranks.map((rank, idx) => {
        if (typeof rank === 'string') {
            return {
                name: rank,
                order: idx + 1,
                canInvite: rank === 'Ejer',
                canStartMission: rank === 'Ejer',
                locked: rank === 'Ejer'
            };
        }
        return {
            name: String(rank.name || ''),
            order: Number(rank.order ?? rank.rank_order) || (idx + 1),
            canInvite: toBool(rank.canInvite ?? rank.can_invite),
            canStartMission: toBool(rank.canStartMission ?? rank.can_start_mission),
            locked: !!rank.locked || rank.name === 'Ejer'
        };
    }).filter(rank => rank.name.length > 0);
}

function escapeForOnclick(value) {
    return String(value || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function syncRankState(resp, refreshMembers) {
    if (resp && Array.isArray(resp.ranks)) {
        gangRanks = normalizeRanks(resp.ranks);
    }
    renderRankAdmin();
    const membersPage = document.getElementById('members');
    if (membersPage && membersPage.classList.contains('active') && latestMembers.length > 0) {
        updateMemberUI(latestMembers);
    }
    if (refreshMembers) {
        fetch(`https://${GetParentResourceName()}/getMembers`, { method: 'POST', body: JSON.stringify({}) });
    }
}

function renderRankAdmin() {
    const rankList = document.getElementById('rank-list');
    const rankInput = document.getElementById('new-rank-name');
    const rankNote = document.getElementById('rank-admin-note');
    const rankButton = document.querySelector('.rank-create-btn');

    if (rankInput) rankInput.disabled = !isGangOwner;
    if (rankButton) rankButton.disabled = !isGangOwner;
    if (rankNote) rankNote.innerText = isGangOwner
        ? 'Administrer ranks, permissions og rækkefølge'
        : 'Kun ejeren kan administrere ranks';

    if (!rankList) return;
    const ranks = normalizeRanks(gangRanks);
    if (ranks.length === 0) {
        rankList.innerHTML = '<span class="rank-pill">Ingen ranks</span>';
        return;
    }

    rankList.innerHTML = ranks.map((rank, idx) => {
        const rankNameEscaped = escapeForOnclick(rank.name);
        const rankNameText = escapeHtml(rank.name);
        const canMoveUp = isGangOwner && !rank.locked && idx > 1;
        const canMoveDown = isGangOwner && !rank.locked && idx < (ranks.length - 1);
        const canEditPermissions = isGangOwner && !rank.locked;
        const canDelete = isGangOwner && !rank.locked;

        return `
            <div class="rank-row">
                <div class="rank-row-main">
                    <span class="rank-pill ${rank.locked ? 'rank-pill-owner' : ''}">${rankNameText}</span>
                </div>
                <div class="rank-row-perms">
                    <label class="perm-toggle">
                        <input type="checkbox" ${rank.canInvite ? 'checked' : ''} ${canEditPermissions ? '' : 'disabled'}
                            onchange="setRankPermission('${rankNameEscaped}', 'invite', this.checked)">
                        <span>Invite</span>
                    </label>
                    <label class="perm-toggle">
                        <input type="checkbox" ${rank.canStartMission ? 'checked' : ''} ${canEditPermissions ? '' : 'disabled'}
                            onchange="setRankPermission('${rankNameEscaped}', 'mission', this.checked)">
                        <span>Mission</span>
                    </label>
                </div>
                <div class="rank-row-actions">
                    <button class="rank-action-btn" ${canMoveUp ? '' : 'disabled'} onclick="moveRank('${rankNameEscaped}', 'up')">↑</button>
                    <button class="rank-action-btn" ${canMoveDown ? '' : 'disabled'} onclick="moveRank('${rankNameEscaped}', 'down')">↓</button>
                    <button class="rank-delete-btn" ${canDelete ? '' : 'disabled'} onclick="deleteRank('${rankNameEscaped}')">Slet</button>
                </div>
            </div>
        `;
    }).join('');
}

function fetchGangRanks() {
    return fetch(`https://${GetParentResourceName()}/getRanks`, {
        method: 'POST',
        body: JSON.stringify({})
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.success) {
                syncRankState(resp, false);
            } else if (!Array.isArray(gangRanks)) {
                gangRanks = [];
                renderRankAdmin();
            }
            return resp;
        })
        .catch(() => {
            renderRankAdmin();
            return { success: false };
        });
}

function createRank() {
    if (!isGangOwner) return;
    const input = document.getElementById('new-rank-name');
    if (!input) return;

    const rankName = String(input.value || '').trim();
    if (rankName.length < 2) return;

    fetch(`https://${GetParentResourceName()}/createRank`, {
        method: 'POST',
        body: JSON.stringify({ rankName: rankName })
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.success) {
                input.value = '';
                syncRankState(resp, true);
            }
        })
        .catch(() => {});
}

function deleteRank(rankName) {
    if (!isGangOwner) return;
    fetch(`https://${GetParentResourceName()}/deleteRank`, {
        method: 'POST',
        body: JSON.stringify({ rankName: rankName })
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.success) {
                syncRankState(resp, true);
            }
        })
        .catch(() => {});
}

function moveRank(rankName, direction) {
    if (!isGangOwner) return;
    fetch(`https://${GetParentResourceName()}/moveRank`, {
        method: 'POST',
        body: JSON.stringify({ rankName: rankName, direction: direction })
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.success) {
                syncRankState(resp, false);
            }
        })
        .catch(() => {});
}

function setRankPermission(rankName, permission, allowed) {
    if (!isGangOwner) return;

    const localRanks = normalizeRanks(gangRanks);
    const target = localRanks.find(rank => rank.name === String(rankName));
    if (target) {
        if (permission === 'invite') target.canInvite = !!allowed;
        if (permission === 'mission') target.canStartMission = !!allowed;
        gangRanks = localRanks;
        renderRankAdmin();
    }

    fetch(`https://${GetParentResourceName()}/setRankPermission`, {
        method: 'POST',
        body: JSON.stringify({ rankName: rankName, permission: permission, allowed: !!allowed })
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.success) {
                syncRankState(resp, false);
                return;
            }
            fetchGangRanks();
        })
        .catch(() => {
            fetchGangRanks();
        });
}

function changeRank(identifier, direction) {
    if (!isGangOwner) return;
    fetch(`https://${GetParentResourceName()}/changeRank`, {
        method: 'POST',
        body: JSON.stringify({ identifier: identifier, direction: direction })
    }).catch(() => {});
}

// --- SKILL TREE LOGIK ---
function openSkillInfo(id) {
    const skill = skillData[id];
    const modal = document.getElementById('skill-info-modal');
    const buyBtn = document.getElementById('buy-confirm-btn');
    if (!skill || !modal || !buyBtn) return;
    hideSkillTooltip();
    
    document.getElementById('info-title').innerText = skill.title;
    document.getElementById('info-desc').innerText = skill.desc;
    modal.style.display = 'flex';

    if (unlockedSkills.includes(id)) {
        buyBtn.innerText = "ALLEREDE KØBT";
        buyBtn.disabled = true;
        buyBtn.style.opacity = "0.5";
    } else if (skill.req && !unlockedSkills.includes(skill.req)) {
        buyBtn.innerText = "KRÆVER " + skillData[skill.req].title;
        buyBtn.disabled = true;
        buyBtn.style.opacity = "0.5";
    } else if ((skill.cost || 0) > 0 && skillPoints < skill.cost) {
        buyBtn.innerText = `MANGLER POINT (${skill.cost})`;
        buyBtn.disabled = true;
        buyBtn.style.opacity = "0.5";
    } else {
        buyBtn.innerText = `KØB (${skill.cost || 1} POINT)`;
        buyBtn.disabled = false;
        buyBtn.style.opacity = "1";
        buyBtn.onclick = () => { buySkill(id); };
    }
}

function buySkill(id) {
    fetch(`https://${GetParentResourceName()}/buySkill`, {
        method: 'POST',
        body: JSON.stringify({ skill: id })
    }).then(resp => resp.json()).then(resp => {
        if (resp.success) {
            unlockedSkills.push(id);
            if (typeof resp.points === 'number') {
                skillPoints = resp.points;
                const spEl = document.getElementById('skill-points');
                if (spEl) spEl.innerText = skillPoints;
            }
            updateSkillTreeState();
            closeSkillInfo();
        }
    });
}

function updateSkillTreeState() {
    SKILL_GRAPH.forEach(node => {
        const el = document.getElementById('skill-' + node.id);
        if (!el) return;
        if (unlockedSkills.includes(node.id)) {
            el.classList.remove('locked');
            el.classList.add('active');
        } else {
            el.classList.add('locked');
            el.classList.remove('active');
        }
    });

    const lines = document.querySelectorAll('#skill-lines line');
    lines.forEach(line => {
        const from = line.dataset.from;
        const to = line.dataset.to;
        const active = from && to && unlockedSkills.includes(from) && unlockedSkills.includes(to);
        line.setAttribute('stroke', active ? 'rgba(168, 85, 247, 0.9)' : 'rgba(255,255,255,0.18)');
    });
}

function closeSkillInfo() {
    hideSkillTooltip();
    document.getElementById('skill-info-modal').style.display = 'none';
}

function renderSkillTree() {
    const canvas = document.getElementById('skill-tree-canvas');
    const nodesWrap = document.getElementById('skill-nodes');
    const linesSvg = document.getElementById('skill-lines');
    if (!canvas || !nodesWrap || !linesSvg) return;
    initSkillTreeDrag(canvas);

    if (nodesWrap.childElementCount === 0) {
        ensureSkillTooltip();
        linesSvg.innerHTML = '';
        nodesWrap.innerHTML = '';

        SKILL_GRAPH.forEach(node => {
            const nodeEl = document.createElement('div');
            nodeEl.className = 'skill-node locked';
            nodeEl.id = 'skill-' + node.id;
            nodeEl.style.left = node.x + '%';
            nodeEl.style.top = node.y + '%';
            nodeEl.innerHTML = `<div class=\"node-content\">${node.short}</div><span class=\"skill-label\">${node.label}</span>`;
            nodeEl.addEventListener('click', () => {
                if (skillTreePan.hasMoved) return;
                openSkillInfo(node.id);
            });
            nodeEl.addEventListener('mouseenter', (e) => showSkillTooltip(node.id, e.clientX, e.clientY));
            nodeEl.addEventListener('mousemove', (e) => positionSkillTooltip(e.clientX, e.clientY));
            nodeEl.addEventListener('mouseleave', hideSkillTooltip);
            nodesWrap.appendChild(nodeEl);
        });

        SKILL_GRAPH.forEach(node => {
            if (!node.req) return;
            const from = SKILL_GRAPH.find(n => n.id === node.req);
            if (!from) return;
            const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
            line.setAttribute('x1', from.x);
            line.setAttribute('y1', from.y);
            line.setAttribute('x2', node.x);
            line.setAttribute('y2', node.y);
            line.setAttribute('stroke', 'rgba(255,255,255,0.18)');
            line.setAttribute('stroke-width', '0.7');
            line.setAttribute('vector-effect', 'non-scaling-stroke');
            line.dataset.from = from.id;
            line.dataset.to = node.id;
            linesSvg.appendChild(line);
        });
    }

    applySkillTreePan();
    updateSkillTreeState();
}

// --- MISSIONER ---
function startMission(id) {
    if (!id) return;
    fetch(`https://${GetParentResourceName()}/startMission`, {
        method: 'POST',
        body: JSON.stringify({ missionId: id })
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.state) missionState = resp.state;
            renderMissions();
            if (resp && resp.success) {
                closeUI();
            }
        })
        .catch(() => {
            fetchMissionState();
        });
}

function fetchMissionState() {
    return fetch(`https://${GetParentResourceName()}/getMissionState`, {
        method: 'POST',
        body: JSON.stringify({})
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.success) {
                missionState = resp.state || { ...DEFAULT_MISSION_STATE };
                if (missionState && Array.isArray(missionState.missions) && missionState.missions.length > 0) {
                    missionCatalog = missionState.missions;
                } else {
                    missionCatalog = [...MISSION_POOL];
                }
            } else {
                missionState = { ...DEFAULT_MISSION_STATE };
                missionCatalog = [...MISSION_POOL];
            }
            renderMissions();
        })
        .catch(() => {
            missionState = { ...DEFAULT_MISSION_STATE };
            missionCatalog = [...MISSION_POOL];
            renderMissions();
        });
}

function formatMissionTime(seconds) {
    const total = Math.max(0, Math.floor(Number(seconds) || 0));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const secs = total % 60;
    if (hours > 0) return `${hours}t ${minutes}m`;
    return `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

function renderMissions() {
    const list = document.getElementById('missions-list');
    if (!list) return;
    if (!missionState) {
        list.innerHTML = '<div class="mission-card"><div class="mission-info"><h3>Indlæser missioner</h3><p>Henter mission-status fra serveren...</p></div></div>';
        return;
    }

    const now = Math.floor(Date.now() / 1000);
    const completed = Array.isArray(missionState.completedMissionIds) ? missionState.completedMissionIds : [];
    const activeMissionId = Number(missionState.activeMissionId) || 0;
    const nextMissionAt = Number(missionState.nextMissionAt) || 0;
    const cycleCooldownUntil = Number(missionState.cycleCooldownUntil) || 0;
    const cycleCooldownActive = cycleCooldownUntil > now;
    const intervalLocked = nextMissionAt > now;

    const cycleBanner = cycleCooldownActive
        ? `<div class="mission-card"><div class="mission-info"><h3>MISSION COOLDOWN</h3><p>Nye missioner bliver aktive om ${formatMissionTime(cycleCooldownUntil - now)}.</p></div></div>`
        : '';

    if (!Array.isArray(missionCatalog) || missionCatalog.length === 0) {
        list.innerHTML = '<div class="mission-card"><div class="mission-info"><h3>Ingen missioner</h3><p>Der er ikke registreret nogen gang missioner endnu.</p></div></div>';
        return;
    }

    const cards = missionCatalog.map(mission => {
        const isCompleted = completed.includes(mission.id);
        const isActive = activeMissionId === mission.id;
        let disabled = false;
        let buttonText = 'START';

        if (isCompleted) {
            disabled = true;
            buttonText = 'FULDFØRT';
        } else if (isActive) {
            disabled = true;
            buttonText = 'I GANG';
        } else if (cycleCooldownActive) {
            disabled = true;
            buttonText = `COOLDOWN ${formatMissionTime(cycleCooldownUntil - now)}`;
        } else if (intervalLocked) {
            disabled = true;
            buttonText = `KLAR OM ${formatMissionTime(nextMissionAt - now)}`;
        }

        const reward = mission.rewardText || 'Belønning gives ved fuldførelse.';
        const disabledAttr = disabled ? 'disabled' : '';

        return `
            <div class="mission-card">
                <div class="mission-info">
                    <h3>${mission.title}</h3>
                    <p>${mission.desc}</p>
                    <div class="mission-rewards">⭐ ${reward}</div>
                </div>
                <div class="mission-actions">
                    <button class="mission-start-btn" onclick="startMission(${mission.id})" ${disabledAttr}>${buttonText}</button>
                </div>
            </div>`;
    }).join('');

    list.innerHTML = cycleBanner + cards;
}

// Draggable Skill Tree
const canvas = document.getElementById('skill-canvas');
const draggable = document.getElementById('tree-draggable');
let isDown = false; let startX, startY, scrollLeft, scrollTop;

if (canvas && draggable) {
    canvas.addEventListener('mousedown', (e) => {
        isDown = true;
        canvas.style.cursor = 'grabbing';
        startX = e.pageX - draggable.offsetLeft;
        startY = e.pageY - draggable.offsetTop;
    });

    canvas.addEventListener('mousemove', (e) => {
        if (!isDown) return;
        draggable.style.left = (e.pageX - startX) + 'px';
        draggable.style.top = (e.pageY - startY) + 'px';
    });

    canvas.addEventListener('mouseup', () => { isDown = false; canvas.style.cursor = 'grab'; });
    canvas.addEventListener('mouseleave', () => { isDown = false; });
}

// --- BANDE KONTROL ---
function createGang() {
    const name = document.getElementById('gang-name').value;
    if (name.length < 3) return;
    fetch(`https://${GetParentResourceName()}/createGang`, { method: 'POST', body: JSON.stringify({ name: name }) });
    closeUI();
}

function invitePlayer() {
    const input = document.getElementById('invite-player-id');
    if (!input) return;

    const rawPlayerId = String(input.value || '').trim();
    const playerId = Number(rawPlayerId);
    if (!rawPlayerId || Number.isNaN(playerId) || playerId <= 0) return;

    fetch(`https://${GetParentResourceName()}/invitePlayer`, {
        method: 'POST',
        body: JSON.stringify({ playerId: playerId })
    })
        .then(resp => resp.json())
        .then(resp => {
            if (resp && resp.success) {
                input.value = '';
            }
        })
        .catch(() => {});
}

function leaveGang() {
    if (confirm("Vil du forlade banden?")) {
        fetch(`https://${GetParentResourceName()}/leaveGang`, { method: 'POST', body: JSON.stringify({}) });
        closeUI();
    }
}

// --- MODALS & SETTINGS ---
function openDeleteModal() { document.getElementById('delete-modal').style.display = "flex"; }
function closeModal() { document.getElementById('delete-modal').style.display = "none"; }
function confirmDelete() {
    fetch(`https://${GetParentResourceName()}/deleteGang`, { method: 'POST', body: JSON.stringify({}) });
    closeModal(); closeUI();
}

function updateSettings() {
    const s = document.getElementById('scale-slider').value;
    const o = document.getElementById('opacity-slider').value;
    document.getElementById('scale-val').innerText = s;
    document.getElementById('opacity-val').innerText = o;
    const wrapper = document.getElementById('tablet-wrapper');
    const container = document.getElementById('tablet-container');
    if (wrapper) {
        wrapper.style.transform = `translate(-50%, -50%) scale(${s})`;
        wrapper.style.opacity = o;
    }
    if (container) {
        container.style.opacity = 1;
    }
}

function saveSettings() {
    localStorage.setItem('stavex_tablet_scale', document.getElementById('scale-slider').value);
    localStorage.setItem('stavex_tablet_opacity', document.getElementById('opacity-slider').value);
}

function applySavedSettings() {
    const s = localStorage.getItem('stavex_tablet_scale') || 1.0;
    const o = localStorage.getItem('stavex_tablet_opacity') || 1.0;
    document.getElementById('scale-slider').value = s;
    document.getElementById('opacity-slider').value = o;
    updateSettings();
}

// --- UI KONTROL ---
function closeUI() {
    document.body.style.display = "none";
    hideSkillTooltip();
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: JSON.stringify({}) });
}

document.onkeydown = function(data) { if (data.which == 27) closeUI(); };

// Prevent native focus/selection artifacts (black focus block in some CEF builds).
document.addEventListener('mousedown', (event) => {
    const target = event.target.closest('button, .skill-node');
    if (!target) return;
    if (typeof target.blur === 'function') target.blur();
    const selection = window.getSelection && window.getSelection();
    if (selection && selection.removeAllRanges) selection.removeAllRanges();
}, true);
