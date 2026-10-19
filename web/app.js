// PicklePark Web & Android PWA Core Engine
const REACHCM_API_URL = 'https://burlingameca.portal.reachcm.com/api/calendar/get-events?feed_id=1830';
const WEBTRAC_RESERVE_URL = 'https://www.burlingame.org/rec';
const POINTS_COOLDOWN_MS = 4 * 3600 * 1000; // 4 Hours

// Profanity / Content Moderation Filter
const BANNED_WORDS = ['badword', 'swear', 'fuck', 'shit', 'ass', 'bitch', 'cunt', 'dick', 'pussy', 'nigger', 'faggot', 'whore', 'slut'];
function moderateText(text) {
  if (!text) return '';
  let cleaned = text;
  BANNED_WORDS.forEach(word => {
    const regex = new RegExp(`\\b${word}\\b`, 'gi');
    cleaned = cleaned.replace(regex, '***');
  });
  return cleaned;
}

// Initial State
let state = {
  activeTab: 'washington', // 'washington' | 'pickleque'
  leaderboardScope: 'thisMonth', // 'thisMonth' | 'allTime'
  scheduleScope: 'today', // 'today' | 'sevenDays' | 'month'
  activeDayOffset: 0,
  selectedDate: new Date(),
  courtsInUse: 4,
  inQueue: 0,
  court2State: 'free', // 'free' | 'oneSideTaken' | 'bothSidesTaken'
  court3State: 'free', // 'free' | 'oneSideTaken' | 'bothSidesTaken'
  lastReportDate: new Date(),
  lastPointsAwardedDate: null,
  priorUpdates: [
    { courts: 4, queue: 6, walkOn: 4, time: new Date(Date.now() - 3600000) },
    { courts: 4, queue: 4, walkOn: 4, time: new Date(Date.now() - 7200000) }
  ],
  currentUser: {
    name: 'Player (You)',
    snack: 'Cold Coconut Water & RXBar',
    avatar: '🎾',
    monthlyPoints: 0,
    allTimePoints: 0,
    monthlyReports: 0,
    allTimeReports: 0
  },
  users: [
    {
      id: 'user_player',
      name: 'Player (You)',
      snack: 'Cold Coconut Water & RXBar',
      avatar: '🎾',
      monthlyPoints: 0,
      allTimePoints: 0,
      monthlyReports: 0,
      allTimeReports: 0,
      isCurrent: true
    }
  ],
  cityReservations: []
};

// Load Saved State from localStorage
function loadState() {
  const saved = localStorage.getItem('picklepark_pwa_state_v3');
  if (saved) {
    try {
      const parsed = JSON.parse(saved);
      state = { ...state, ...parsed };
      if (state.lastReportDate) state.lastReportDate = new Date(state.lastReportDate);
      if (state.lastPointsAwardedDate) state.lastPointsAwardedDate = new Date(state.lastPointsAwardedDate);
    } catch (e) {
      console.error('Error loading state:', e);
    }
  }
  check11PMReset();
}

function check11PMReset() {
  if (!state.lastReportDate) return;
  const now = new Date();
  const report = new Date(state.lastReportDate);
  const isSameDay = now.getFullYear() === report.getFullYear() &&
                    now.getMonth() === report.getMonth() &&
                    now.getDate() === report.getDate();
  
  if (!isSameDay || (now.getHours() >= 23 && report.getHours() < 23)) {
    state.court2State = 'free';
    state.court3State = 'free';
    saveState();
  }
}

function saveState() {
  localStorage.setItem('picklepark_pwa_state_v3', JSON.stringify(state));
}

// Compute Dynamic Walk-On PB Courts Open (0 to 4 PB)
function getWalkOnCourtsAvailable() {
  let count = 0;
  if (state.court2State === 'free') count += 2;
  else if (state.court2State === 'oneSideTaken') count += 1;

  if (state.court3State === 'free') count += 2;
  else if (state.court3State === 'oneSideTaken') count += 1;

  return count;
}

// Points Gating Check (Once every 4 hours)
function getPointsStatus() {
  if (!state.lastPointsAwardedDate) {
    return { eligible: true, message: 'Earn +10 Leaderboard Points!' };
  }
  const elapsed = Date.now() - new Date(state.lastPointsAwardedDate).getTime();
  if (elapsed < POINTS_COOLDOWN_MS) {
    const remainingMs = POINTS_COOLDOWN_MS - elapsed;
    const hours = Math.floor(remainingMs / 3600000);
    const mins = Math.ceil((remainingMs % 3600000) / 60000);
    const timeStr = hours > 0 ? `${hours}h ${mins}m` : `${mins}m`;
    return { eligible: false, message: `Points cooldown: Next +10 pts in ${timeStr}.` };
  }
  return { eligible: true, message: 'Earn +10 Leaderboard Points!' };
}

// Main Render Loop
function render() {
  renderWashingtonView();
  renderWalkOnCourts();
  renderSchedule();
  renderLeaderboard();
  if (window.lucide) lucide.createIcons();
}

function renderWashingtonView() {
  document.getElementById('metric-courts').innerText = state.courtsInUse;
  document.getElementById('metric-queue').innerText = state.inQueue;
  document.getElementById('metric-walkon').innerText = getWalkOnCourtsAvailable();
  document.getElementById('last-report-time').innerText = timeAgo(state.lastReportDate);

  const priorList = document.getElementById('prior-updates-list');
  priorList.innerHTML = state.priorUpdates.map(u => `
    <div class="flex items-center justify-between text-xs py-1.5 px-3 bg-slate-50 rounded-lg border border-slate-100">
      <span class="text-slate-500 font-medium">${timeAgo(new Date(u.time))}</span>
      <span class="font-bold text-slate-700">${u.courts} Courts in Use · ${u.queue} In Queue · ${u.walkOn} Walk-On</span>
    </div>
  `).join('');
}

function renderWalkOnCourts() {
  const openCount = getWalkOnCourtsAvailable();
  const badge = document.getElementById('walkon-summary-badge');
  if (openCount === 4) {
    badge.className = 'px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-700';
    badge.innerText = '🟢 4 PB · All Open';
  } else if (openCount > 0) {
    badge.className = 'px-2.5 py-1 rounded-full text-xs font-bold bg-amber-100 text-amber-700';
    badge.innerText = `🟡 ${openCount} PB Open`;
  } else {
    badge.className = 'px-2.5 py-1 rounded-full text-xs font-bold bg-red-100 text-red-700';
    badge.innerText = '🔴 0 PB · Courts Full';
  }

  // Buttons for Court 2 & 3
  const c2Btns = document.getElementById('court-2-buttons');
  const c3Btns = document.getElementById('court-3-buttons');

  const options = [
    { id: 'free', label: 'Free (2 PB)', full: 'bg-emerald-600 text-white' },
    { id: 'oneSideTaken', label: '1 Side Taken', full: 'bg-amber-500 text-white' },
    { id: 'bothSidesTaken', label: 'Both Taken (0 PB)', full: 'bg-red-500 text-white' }
  ];

  c2Btns.innerHTML = options.map(opt => `
    <button onclick="setCourtSide(2, '${opt.id}')" class="flex-1 py-1.5 text-xs font-bold rounded-lg transition ${state.court2State === opt.id ? opt.full : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}">
      ${opt.label}
    </button>
  `).join('');

  c3Btns.innerHTML = options.map(opt => `
    <button onclick="setCourtSide(3, '${opt.id}')" class="flex-1 py-1.5 text-xs font-bold rounded-lg transition ${state.court3State === opt.id ? opt.full : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}">
      ${opt.label}
    </button>
  `).join('');
}

function setCourtSide(court, sideState) {
  if (court === 2) state.court2State = sideState;
  if (court === 3) state.court3State = sideState;
  saveState();
  render();
  showToast(`⚡️ Court ${court} status updated!`);
}

// -------------------------------------------------------------
// RESERVABLE COURTS 2 & 3 SCHEDULE ENGINE (Matches iOS Exactly)
// -------------------------------------------------------------
const HOURS = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];

function formatHourLabel(h) {
  const period = h >= 12 ? 'PM' : 'AM';
  const hour12 = h % 12 === 0 ? 12 : h % 12;
  return `${hour12}:00 ${period}`;
}

function renderSchedule() {
  const container = document.getElementById('reservable-schedule-container');
  if (!container) return;

  const now = new Date();
  const currentHour = now.getHours();

  // Scope Buttons
  const scopeTodayBtn = document.getElementById('scope-btn-today');
  const scope7DaysBtn = document.getElementById('scope-btn-7days');
  const scopeMonthBtn = document.getElementById('scope-btn-month');

  if (scopeTodayBtn && scope7DaysBtn && scopeMonthBtn) {
    [
      { id: 'today', btn: scopeTodayBtn },
      { id: 'sevenDays', btn: scope7DaysBtn },
      { id: 'month', btn: scopeMonthBtn }
    ].forEach(s => {
      if (state.scheduleScope === s.id) {
        s.btn.className = 'flex-1 py-2 rounded-lg font-bold text-xs bg-[#C6F24F] text-slate-900 shadow-sm transition';
      } else {
        s.btn.className = 'flex-1 py-2 rounded-lg font-medium text-xs text-slate-500 hover:text-slate-900 transition';
      }
    });
  }

  let subNavHtml = '';

  // 7 Days Bar
  if (state.scheduleScope === 'sevenDays') {
    const days = [];
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (let i = 0; i < 7; i++) {
      const d = new Date();
      d.setDate(now.getDate() + i);
      days.push({
        offset: i,
        name: i === 0 ? 'Today' : dayNames[d.getDay()],
        num: d.getDate(),
        date: d
      });
    }

    subNavHtml = `
      <div class="flex gap-2 overflow-x-auto pb-1">
        ${days.map(d => `
          <button onclick="state.activeDayOffset=${d.offset}; render();" class="flex-1 min-w-[50px] py-2 px-1 rounded-xl text-center transition ${state.activeDayOffset === d.offset ? 'bg-[#C6F24F] text-slate-900 font-bold shadow-sm' : 'bg-slate-50 text-slate-600 font-medium'}">
            <div class="text-[10px] uppercase">${d.name}</div>
            <div class="text-base font-black">${d.num}</div>
          </button>
        `).join('')}
      </div>
    `;
  } else if (state.scheduleScope === 'month') {
    const monthName = now.toLocaleString('default', { month: 'long', year: 'numeric' });
    subNavHtml = `
      <div class="p-3 bg-slate-50 rounded-xl border border-slate-100 text-center">
        <div class="font-bold text-xs text-slate-900">${monthName}</div>
        <div class="text-[11px] text-slate-500 mt-1">Viewing Court 2 & 3 Municipal Schedule</div>
      </div>
    `;
  }

  // Generate Court Cards (Court 2 & Court 3)
  const courts = [
    { id: 'c2', name: 'Court 2', subtitle: 'Reservable Pickleball / Tennis' },
    { id: 'c3', name: 'Court 3', subtitle: 'Reservable Pickleball / Tennis' }
  ];

  const courtsHtml = courts.map(court => {
    let openCount = 0;
    const isToday = state.scheduleScope === 'today' || (state.scheduleScope === 'sevenDays' && state.activeDayOffset === 0);

    const rowsHtml = HOURS.map(h => {
      const hourStr = formatHourLabel(h);
      const isPast = isToday && h < currentHour;

      // Check if slot has a reservation
      const resMatch = state.cityReservations.find(r => 
        (r.title || '').includes(court.name) && (r.title || '').includes(hourStr)
      );

      if (isPast) {
        return `
          <div class="flex items-center justify-between py-2 px-3 bg-slate-50/50 rounded-lg text-xs">
            <div class="flex items-center gap-2 text-slate-400 font-medium">
              <span class="w-16 font-bold">${hourStr}</span>
              <span class="w-2 h-2 rounded-full bg-slate-300"></span>
              <span>Past</span>
            </div>
          </div>
        `;
      } else if (resMatch) {
        return `
          <div class="flex items-center justify-between py-2 px-3 bg-red-50/70 border border-red-100 rounded-lg text-xs">
            <div class="flex items-center gap-2">
              <span class="w-16 font-bold text-slate-900">${hourStr}</span>
              <span class="w-2 h-2 rounded-full bg-red-500"></span>
              <span class="font-bold text-red-600 truncate max-w-[170px]">${resMatch.title || 'Reserved (WebTrac)'}</span>
            </div>
            <span class="text-[10px] font-bold text-red-600 bg-red-100 px-2 py-0.5 rounded-full">Booked</span>
          </div>
        `;
      } else {
        openCount++;
        return `
          <div class="flex items-center justify-between py-2 px-3 bg-white border border-slate-100 rounded-lg text-xs shadow-sm hover:border-lime-300 transition">
            <div class="flex items-center gap-2">
              <span class="w-16 font-bold text-slate-900">${hourStr}</span>
              <span class="w-2 h-2 rounded-full bg-emerald-500"></span>
              <span class="font-medium text-emerald-600">Available · Open on WebTrac</span>
            </div>
            <a href="${WEBTRAC_RESERVE_URL}" target="_blank" class="bg-[#C6F24F] hover:bg-lime-300 text-slate-900 font-bold text-[11px] px-3 py-1 rounded-lg shadow-sm transition">
              Book
            </a>
          </div>
        `;
      }
    }).join('');

    return `
      <div class="bg-white rounded-2xl p-4 border border-slate-200 shadow-sm space-y-3">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="text-blue-600 p-1.5 bg-blue-50 rounded-lg">
              <i data-lucide="calendar" class="w-4 h-4"></i>
            </div>
            <div>
              <div class="font-black text-sm text-slate-900">${court.name}</div>
              <div class="text-[10px] text-slate-500 font-medium">${court.subtitle}</div>
            </div>
          </div>
          <div class="px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-700">
            ${openCount} Open
          </div>
        </div>

        <div class="space-y-1.5 pt-1">
          ${rowsHtml}
        </div>
      </div>
    `;
  }).join('');

  container.innerHTML = `
    <div class="space-y-3">
      ${subNavHtml}
      <div class="text-xs font-bold text-slate-500 uppercase tracking-wider px-1">
        Reservable Courts Schedule (WebTrac)
      </div>
      <div class="space-y-3">
        ${courtsHtml}
      </div>
    </div>
  `;
}

function setScheduleScope(scope) {
  state.scheduleScope = scope;
  state.activeDayOffset = 0;
  render();
}

function renderLeaderboard() {
  const scope = state.leaderboardScope;
  const scopeMonth = document.getElementById('scope-month');
  const scopeAll = document.getElementById('scope-all');

  if (scope === 'thisMonth') {
    scopeMonth.className = 'flex-1 py-1.5 rounded-md font-bold text-center bg-white text-slate-900 shadow-sm';
    scopeAll.className = 'flex-1 py-1.5 rounded-md font-medium text-center text-slate-500 hover:text-slate-900';
  } else {
    scopeAll.className = 'flex-1 py-1.5 rounded-md font-bold text-center bg-white text-slate-900 shadow-sm';
    scopeMonth.className = 'flex-1 py-1.5 rounded-md font-medium text-center text-slate-500 hover:text-slate-900';
  }

  const sorted = [...state.users].sort((a, b) => {
    const pA = scope === 'thisMonth' ? a.monthlyPoints : a.allTimePoints;
    const pB = scope === 'thisMonth' ? b.monthlyPoints : b.allTimePoints;
    return pB - pA;
  });

  const mvp = sorted[0] || state.currentUser;
  const mvpBanner = document.getElementById('snack-mvp-banner');
  const listEl = document.getElementById('leaderboard-list');

  mvpBanner.innerHTML = `
    <div class="bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200 rounded-xl p-3.5 flex items-center gap-3">
      <div class="text-3xl">${mvp.avatar || '👑'}</div>
      <div class="flex-1">
        <div class="text-[10px] uppercase font-black tracking-wider text-amber-800">👑 Burlingame Snack MVP · ${scope === 'thisMonth' ? 'This Month' : 'All-Time'}</div>
        <div class="font-bold text-sm text-slate-900">${mvp.name}</div>
        <div class="text-xs text-amber-900 mt-0.5">🍪 Bring them: <strong>${mvp.snack || 'Cold Coconut Water & RXBar'}</strong></div>
      </div>
      <div class="text-right">
        <div class="text-base font-black text-amber-700">${scope === 'thisMonth' ? mvp.monthlyPoints : mvp.allTimePoints}</div>
        <div class="text-[10px] uppercase font-bold text-amber-600">Points</div>
      </div>
    </div>
  `;

  listEl.innerHTML = sorted.map((u, i) => `
    <div class="flex items-center justify-between p-3 rounded-xl ${u.isCurrent ? 'bg-blue-50 border border-blue-200' : 'bg-slate-50 border border-slate-100'}">
      <div class="flex items-center gap-3">
        <span class="text-xs font-bold text-slate-400 w-4">${i + 1}</span>
        <span class="text-lg">${u.avatar || '🎾'}</span>
        <div>
          <div class="font-bold text-xs text-slate-900 flex items-center gap-1">
            ${u.name}
            ${u.isCurrent ? '<span class="text-[9px] bg-blue-600 text-white px-1.5 py-0.5 rounded-full font-bold">YOU</span>' : ''}
          </div>
          <div class="text-[10px] text-slate-500">Snack: ${u.snack}</div>
        </div>
      </div>
      <div class="text-right">
        <div class="text-sm font-black text-slate-900">${scope === 'thisMonth' ? u.monthlyPoints : u.allTimePoints} pts</div>
        <div class="text-[10px] text-slate-400">${scope === 'thisMonth' ? u.monthlyReports : u.allTimeReports} reports</div>
      </div>
    </div>
  `).join('');
}

// Time Helper
function timeAgo(date) {
  const seconds = Math.floor((new Date() - date) / 1000);
  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(seconds / 3600);
  if (hours < 24) return `${hours} hr. ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

// Toast Helper
function showToast(msg) {
  const toast = document.getElementById('toast');
  toast.innerText = msg;
  toast.classList.remove('opacity-0', 'pointer-events-none');
  toast.classList.add('opacity-100');
  setTimeout(() => {
    toast.classList.remove('opacity-100');
    toast.classList.add('opacity-0', 'pointer-events-none');
  }, 3000);
}

// Fetch City Reservations
async function fetchCityReservations() {
  try {
    const today = new Date().toISOString().split('T')[0];
    const res = await fetch(`${REACHCM_API_URL}&date=${today}`);
    if (res.ok) {
      const data = await res.json();
      state.cityReservations = data || [];
      renderSchedule();
      showToast('⚡️ City of Burlingame Calendar Synced!');
    }
  } catch (e) {
    console.log('Using offline cache for ReachCM');
  }
}

// Fetch Real-Time Weather & AQI for Washington Park, Burlingame
async function fetchWeather() {
  try {
    const res = await fetch('https://wttr.in/Burlingame,CA?format=j1');
    if (res.ok) {
      const data = await res.json();
      const current = data.current_condition?.[0];
      if (current) {
        const temp = parseInt(current.temp_F) || 65;
        const windSpeed = parseInt(current.windspeedMiles) || 8;
        const windDir = current.winddir16Point || 'NNW';
        const desc = current.weatherDesc?.[0]?.value || 'Partly Cloudy';
        
        let emoji = '⛅️';
        const lowerDesc = desc.toLowerCase();
        if (lowerDesc.includes('rain') || lowerDesc.includes('shower')) emoji = '🌧️';
        else if (lowerDesc.includes('sun') || lowerDesc.includes('clear')) emoji = '☀️';
        else if (lowerDesc.includes('overcast') || lowerDesc.includes('cloud')) emoji = '☁️';
        
        const windText = windSpeed <= 2 ? '🍃 Calm' : `💨 ${windSpeed} mph ${windDir}`;
        const weatherEl = document.getElementById('weather-text');
        if (weatherEl) {
          weatherEl.innerHTML = `<span>${emoji}</span> ${temp}°F | ${windText}`;
        }
      }
    }
  } catch (e) {
    console.log('Weather offline fallback used');
  }

  // Fetch AQI
  try {
    const aqiRes = await fetch('https://air-quality-api.open-meteo.com/v1/air-quality?latitude=37.5779&longitude=-122.3481&current=us_aqi');
    if (aqiRes.ok) {
      const aqiData = await aqiRes.json();
      const aqi = aqiData.current?.us_aqi || 38;
      let status = 'Good';
      let ico = '🟢';
      if (aqi > 50 && aqi <= 100) { status = 'Okay'; ico = '🟡'; }
      else if (aqi > 100 && aqi <= 200) { status = 'Bad'; ico = '🔴'; }
      else if (aqi > 200) { status = 'Stay Indoors'; ico = '🟣'; }
      
      const aqiEl = document.getElementById('aqi-text');
      if (aqiEl) {
        aqiEl.innerText = `${ico} AQI ${aqi} · ${status}`;
      }
    }
  } catch (e) {}
}

// ==========================================
// 🎾 PickleMatch: Native On-Court Doubles Engine
// ==========================================

let matchState = {
  players: [
    { name: 'You', skill: '4.5' },
    { name: 'Alex', skill: '3.5' },
    { name: 'Sarah', skill: '5.0' },
    { name: 'Mike', skill: '3.5' },
    { name: 'Jordan', skill: '2.5' },
    { name: 'Taylor', skill: '4.5' },
    { name: 'Sam', skill: '3.5' },
    { name: 'Elena', skill: '2.5' }
  ],
  courtsCount: 2,
  targetScore: 11,
  matchmakingMode: 'balanced', // 'balanced' | 'tiered' | 'social'
  currentRoundNumber: 0,
  isSessionActive: false,
  matches: [],
  sittingPlayers: [],
  partnerHistory: {}
};

const SKILL_TIERS = ['2.5', '3.5', '4.5', '5.0'];
function getSkillColor(skill) {
  if (skill === '2.5') return '#10B981'; // Green
  if (skill === '3.5') return '#F59E0B'; // Amber
  if (skill === '4.5') return '#EF4444'; // Red
  return '#8B5CF6'; // Purple
}

function renderPickleMatch() {
  const setupView = document.getElementById('pm-setup-view');
  const activeView = document.getElementById('pm-active-view');
  if (!setupView || !activeView) return;

  if (!matchState.isSessionActive || matchState.matches.length === 0) {
    setupView.classList.remove('hidden');
    activeView.classList.add('hidden');
    renderMatchSetup();
  } else {
    setupView.classList.add('hidden');
    activeView.classList.remove('hidden');
    renderMatchActiveRound();
  }
}

function renderMatchSetup() {
  const container = document.getElementById('pm-players-list');
  const countBadge = document.getElementById('pm-player-count');
  const startBtn = document.getElementById('pm-start-btn');
  
  if (countBadge) countBadge.innerText = `${matchState.players.length} Players`;
  if (startBtn) {
    if (matchState.players.length >= 4) {
      startBtn.disabled = false;
      startBtn.className = 'w-full py-3.5 bg-[#C6F24F] hover:bg-lime-400 text-slate-950 font-black text-xs rounded-2xl shadow transition flex items-center justify-center gap-2';
    } else {
      startBtn.disabled = true;
      startBtn.className = 'w-full py-3.5 bg-slate-700 text-slate-400 font-bold text-xs rounded-2xl cursor-not-allowed flex items-center justify-center gap-2';
    }
  }

  // Update Courts Buttons (1, 2, 3, 4)
  document.querySelectorAll('.pm-court-btn').forEach(btn => {
    const val = parseInt(btn.dataset.val);
    btn.className = (val === matchState.courtsCount)
      ? 'flex-1 py-2.5 bg-[#C6F24F] text-slate-950 rounded-xl font-black text-xs shadow-sm'
      : 'flex-1 py-2.5 bg-white/10 text-white rounded-xl font-medium text-xs';
  });

  // Render Visual Court Diagrams
  const diagramContainer = document.getElementById('pm-diagrams-grid');
  if (diagramContainer) {
    let html = '';
    for (let c = 1; c <= matchState.courtsCount; c++) {
      html += `
        <div class="bg-white/5 p-2 rounded-xl border border-white/10 text-center space-y-1">
          <div class="text-[9px] font-black text-slate-300 uppercase">Court ${c}</div>
          <div class="relative bg-[#0d3460] h-14 rounded-lg flex flex-col justify-between p-1.5 border border-white/20">
            <div class="flex justify-around">
              <span class="w-2.5 h-2.5 rounded-full bg-[#C6F24F] shadow-sm"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-[#C6F24F] shadow-sm"></span>
            </div>
            <div class="w-full h-px bg-white/30"></div>
            <div class="flex justify-around">
              <span class="w-2.5 h-2.5 rounded-full bg-cyan-400 shadow-sm"></span>
              <span class="w-2.5 h-2.5 rounded-full bg-cyan-400 shadow-sm"></span>
            </div>
          </div>
        </div>
      `;
    }
    diagramContainer.innerHTML = html;
  }

  // Summary Text
  const summaryEl = document.getElementById('pm-court-summary');
  if (summaryEl) {
    const needed = matchState.courtsCount * 4;
    const playing = Math.min(matchState.players.length, needed);
    const sitting = Math.max(0, matchState.players.length - needed);
    summaryEl.innerText = `${playing} / ${needed} playing · ${sitting} in rotation queue`;
  }

  // Update Matchmaking Mode Pills
  document.querySelectorAll('.pm-mode-btn').forEach(btn => {
    const val = btn.dataset.val;
    btn.className = (val === matchState.matchmakingMode)
      ? 'flex-1 py-2 bg-[#C6F24F] text-slate-950 rounded-xl font-bold text-xs shadow-sm'
      : 'flex-1 py-2 bg-white/10 text-white rounded-xl font-medium text-xs';
  });

  // Update Target Score Pills
  document.querySelectorAll('.pm-score-btn').forEach(btn => {
    const val = parseInt(btn.dataset.val);
    btn.className = (val === matchState.targetScore)
      ? 'flex-1 py-1.5 bg-[#C6F24F] text-slate-950 rounded-lg font-bold text-xs shadow-sm'
      : 'flex-1 py-1.5 bg-white/10 text-white rounded-lg font-medium text-xs';
  });

  // Toggle skill select dropdown visibility in Add Player row
  const skillSelect = document.getElementById('pm-new-player-skill');
  if (skillSelect) {
    if (matchState.matchmakingMode === 'social') {
      skillSelect.classList.add('hidden');
    } else {
      skillSelect.classList.remove('hidden');
    }
  }

  // Player List
  if (container) {
    const isSocial = matchState.matchmakingMode === 'social';
    container.innerHTML = matchState.players.map((p, idx) => `
      <div class="flex items-center justify-between p-2.5 bg-white/10 rounded-xl">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-white">${p.name}</span>
        </div>
        <div class="flex items-center gap-2">
          ${!isSocial ? `
            <button onclick="cycleMatchPlayerSkill(${idx})" style="color: ${getSkillColor(p.skill)}; background: ${getSkillColor(p.skill)}22" class="px-2 py-0.5 rounded-full text-[10px] font-black border border-current">
              ${p.skill} DUPR ⟳
            </button>
          ` : ''}
          <button onclick="removeMatchPlayer(${idx})" class="text-slate-400 hover:text-red-400 p-1 text-xs">✕</button>
        </div>
      </div>
    `).join('');
  }
}

function addMatchPlayer() {
  const input = document.getElementById('pm-new-player-input');
  const skillSelect = document.getElementById('pm-new-player-skill');
  if (!input) return;
  const raw = input.value.trim();
  if (!raw) return;
  const clean = moderateText(raw.substring(0, 20));
  if (matchState.players.some(p => p.name.toLowerCase() === clean.toLowerCase())) {
    showToast('Player name already added.');
    return;
  }
  const skill = (skillSelect && matchState.matchmakingMode !== 'social') ? skillSelect.value : '3.5';
  matchState.players.push({ name: clean, skill: skill });
  input.value = '';
  renderPickleMatch();
}

function cycleMatchPlayerSkill(index) {
  const current = matchState.players[index].skill;
  const nextIdx = (SKILL_TIERS.indexOf(current) + 1) % SKILL_TIERS.length;
  matchState.players[index].skill = SKILL_TIERS[nextIdx];
  renderPickleMatch();
}

function removeMatchPlayer(index) {
  matchState.players.splice(index, 1);
  renderPickleMatch();
}

function setMatchCourts(val) {
  matchState.courtsCount = val;
  renderPickleMatch();
}

function setMatchmakingMode(val) {
  matchState.matchmakingMode = val;
  renderPickleMatch();
}

function setMatchTargetScore(val) {
  matchState.targetScore = val;
  renderPickleMatch();
}

function startMatchSession() {
  if (matchState.players.length < 4) return;
  matchState.currentRoundNumber = 0;
  matchState.partnerHistory = {};
  matchState.isSessionActive = true;
  generateMatchNextRound();
}

function generateMatchNextRound() {
  if (matchState.players.length < 4) return;
  matchState.currentRoundNumber += 1;

  const maxCourts = Math.max(1, Math.floor(matchState.players.length / 4));
  const activeCourts = Math.min(matchState.courtsCount, maxCourts);
  const playingSlots = activeCourts * 4;

  let pool = [...matchState.players].sort(() => Math.random() - 0.5);
  const activePlayers = pool.slice(0, playingSlots);
  const sittingPlayers = pool.slice(playingSlots);

  matchState.sittingPlayers = sittingPlayers;
  matchState.matches = [];

  if (matchState.matchmakingMode === 'balanced') {
    // Balanced pairing: high + low
    let sorted = [...activePlayers].sort((a, b) => parseFloat(b.skill) - parseFloat(a.skill));
    let pairs = [];
    while (sorted.length >= 2) {
      const high = sorted.shift();
      const low = sorted.pop();
      pairs.push({
        team: `${high.name} + ${low.name}`,
        rating: parseFloat(high.skill) + parseFloat(low.skill)
      });
    }
    pairs.sort((a, b) => b.rating - a.rating);
    for (let i = 0; i < activeCourts; i++) {
      if (pairs.length >= 2) {
        const teamA = pairs.shift();
        const teamB = pairs.shift();
        matchState.matches.push({
          courtNumber: i + 1,
          teamA: teamA.team,
          ratingA: teamA.rating.toFixed(1),
          teamB: teamB.team,
          ratingB: teamB.rating.toFixed(1),
          scoreA: 0,
          scoreB: 0,
          isFinished: false,
          winner: null
        });
      }
    }
  } else if (matchState.matchmakingMode === 'tiered') {
    // Tiered Courts: Court 1 gets highest rated players
    let sorted = [...activePlayers].sort((a, b) => parseFloat(b.skill) - parseFloat(a.skill));
    for (let i = 1; i <= activeCourts; i++) {
      if (sorted.length >= 4) {
        const quad = sorted.splice(0, 4).sort(() => Math.random() - 0.5);
        matchState.matches.push({
          courtNumber: i,
          teamA: `${quad[0].name} + ${quad[1].name}`,
          ratingA: (parseFloat(quad[0].skill) + parseFloat(quad[1].skill)).toFixed(1),
          teamB: `${quad[2].name} + ${quad[3].name}`,
          ratingB: (parseFloat(quad[2].skill) + parseFloat(quad[3].skill)).toFixed(1),
          scoreA: 0,
          scoreB: 0,
          isFinished: false,
          winner: null
        });
      }
    }
  } else {
    // Social / Random
    let remaining = [...activePlayers];
    for (let i = 1; i <= activeCourts; i++) {
      if (remaining.length < 4) break;
      const p1 = remaining.shift();
      const p2 = remaining.shift();
      const p3 = remaining.shift();
      const p4 = remaining.shift();
      matchState.matches.push({
        courtNumber: i,
        teamA: `${p1.name} + ${p2.name}`,
        ratingA: null,
        teamB: `${p3.name} + ${p4.name}`,
        ratingB: null,
        scoreA: 0,
        scoreB: 0,
        isFinished: false,
        winner: null
      });
    }
  }

  renderPickleMatch();
}

function renderMatchActiveRound() {
  const isSocial = matchState.matchmakingMode === 'social';
  const roundBadge = document.getElementById('pm-round-badge');
  if (roundBadge) roundBadge.innerText = `ROUND ${matchState.currentRoundNumber}`;

  const targetLabel = document.getElementById('pm-target-label');
  if (targetLabel) targetLabel.innerText = `${matchState.matchmakingMode.toUpperCase()} · First to ${matchState.targetScore}`;

  const courtsContainer = document.getElementById('pm-courts-container');
  if (courtsContainer) {
    courtsContainer.innerHTML = matchState.matches.map((m, idx) => `
      <div class="bg-[#051c36] p-4 rounded-2xl border border-sky-900/80 space-y-3">
        <div class="flex items-center justify-between">
          <span class="px-2 py-0.5 bg-[#C6F24F]/20 text-[#C6F24F] font-black text-[10px] rounded uppercase tracking-wider">Court ${m.courtNumber}</span>
          <span class="text-[10px] font-bold ${m.isFinished ? 'text-[#C6F24F]' : 'text-emerald-400'}">${m.isFinished ? 'GAME OVER ✓' : '🟢 LIVE'}</span>
        </div>

        <!-- Team A -->
        <div class="flex items-center justify-between p-2.5 rounded-xl ${m.winner === 'A' ? 'bg-[#C6F24F]/15 text-[#C6F24F]' : 'bg-white/5 text-white'}">
          <div>
            <div class="text-xs font-bold">${m.winner === 'A' ? '👑 ' : ''}${m.teamA}</div>
            <div class="text-[10px] text-slate-400">Team A${(!isSocial && m.ratingA) ? ` (${m.ratingA} DUPR)` : ''}</div>
          </div>
          <div class="flex items-center gap-2">
            <button onclick="updateMatchScore(${idx}, 'A', -1)" class="w-7 h-7 rounded-lg bg-white/10 text-white font-bold flex items-center justify-center">-</button>
            <span class="text-2xl font-black min-w-[28px] text-center">${m.scoreA}</span>
            <button onclick="updateMatchScore(${idx}, 'A', 1)" class="w-7 h-7 rounded-lg bg-[#C6F24F] text-slate-950 font-black flex items-center justify-center">+</button>
          </div>
        </div>

        <div class="text-center text-[10px] font-black text-slate-500 uppercase">VS</div>

        <!-- Team B -->
        <div class="flex items-center justify-between p-2.5 rounded-xl ${m.winner === 'B' ? 'bg-[#C6F24F]/15 text-[#C6F24F]' : 'bg-white/5 text-white'}">
          <div>
            <div class="text-xs font-bold">${m.winner === 'B' ? '👑 ' : ''}${m.teamB}</div>
            <div class="text-[10px] text-slate-400">Team B${(!isSocial && m.ratingB) ? ` (${m.ratingB} DUPR)` : ''}</div>
          </div>
          <div class="flex items-center gap-2">
            <button onclick="updateMatchScore(${idx}, 'B', -1)" class="w-7 h-7 rounded-lg bg-white/10 text-white font-bold flex items-center justify-center">-</button>
            <span class="text-2xl font-black min-w-[28px] text-center">${m.scoreB}</span>
            <button onclick="updateMatchScore(${idx}, 'B', 1)" class="w-7 h-7 rounded-lg bg-[#C6F24F] text-slate-950 font-black flex items-center justify-center">+</button>
          </div>
        </div>
      </div>
    `).join('');
  }

  // Sitters
  const sittersEl = document.getElementById('pm-sitters-container');
  if (sittersEl) {
    if (matchState.sittingPlayers.length > 0) {
      sittersEl.classList.remove('hidden');
      sittersEl.innerHTML = `
        <div class="p-3 bg-amber-500/10 border border-amber-500/30 rounded-xl space-y-1.5">
          <div class="text-[10px] font-black text-amber-400 uppercase tracking-wider">🛋️ Next Up (Sitting This Round · ${matchState.sittingPlayers.length})</div>
          <div class="flex flex-wrap gap-1.5">
            ${matchState.sittingPlayers.map(s => `
              <span class="px-2.5 py-1 bg-white/10 text-white text-xs font-bold rounded-lg flex items-center gap-1.5">
                <span>${s.name}</span>
                ${!isSocial ? `<span class="text-[9px] px-1 rounded bg-amber-400/20 text-amber-300 font-black">${s.skill}</span>` : ''}
              </span>
            `).join('')}
          </div>
        </div>
      `;
    } else {
      sittersEl.classList.add('hidden');
    }
  }
}

function updateMatchScore(matchIdx, team, delta) {
  const m = matchState.matches[matchIdx];
  if (!m) return;

  if (team === 'A') m.scoreA = Math.max(0, m.scoreA + delta);
  else m.scoreB = Math.max(0, m.scoreB + delta);

  if (m.scoreA >= matchState.targetScore && (m.scoreA - m.scoreB) >= 2) {
    m.isFinished = true;
    m.winner = 'A';
  } else if (m.scoreB >= matchState.targetScore && (m.scoreB - m.scoreA) >= 2) {
    m.isFinished = true;
    m.winner = 'B';
  } else {
    m.isFinished = false;
    m.winner = null;
  }

  renderPickleMatch();
}

let matchState = {
  isSessionActive: false,
  courtsCount: 2,
  matchmakingMode: 'balanced',
  scoringFormat: 'sideOut', // 'sideOut' | 'rally' | 'dreamBreaker'
  targetScore: 11,
  currentRoundNumber: 0,
  players: [
    { id: 1, name: 'You', skill: '4.5' },
    { id: 2, name: 'Alex', skill: '3.5' },
    { id: 3, name: 'Sarah', skill: '5.0' },
    { id: 4, name: 'Mike', skill: '3.5' },
    { id: 5, name: 'Jordan', skill: '2.5' },
    { id: 6, name: 'Taylor', skill: '4.5' },
    { id: 7, name: 'Sam', skill: '3.5' },
    { id: 8, name: 'Elena', skill: '2.5' }
  ],
  matches: [],
  sittingPlayers: [],
  partnerHistory: {}
};

function clearMatchPlayers() {
  if (confirm('Clear all players from lineup?')) {
    matchState.players = [];
    renderPickleMatch();
  }
}

function setMatchScoringFormat(format) {
  matchState.scoringFormat = format;
  if (format === 'sideOut') matchState.targetScore = 11;
  else if (format === 'rally') matchState.targetScore = 15;
  else if (format === 'dreamBreaker') matchState.targetScore = 21;

  document.querySelectorAll('.pm-scoring-btn').forEach(btn => {
    if (btn.dataset.val === format) {
      btn.className = 'pm-scoring-btn flex-1 py-1.5 rounded-lg font-bold bg-[#C6F24F] text-slate-950';
    } else {
      btn.className = 'pm-scoring-btn flex-1 py-1.5 rounded-lg font-medium text-white';
    }
  });

  renderPickleMatch();
}

function resetMatchSession() {
  if (confirm('Reset match rotations and return to court setup?')) {
    matchState.isSessionActive = false;
    matchState.currentRoundNumber = 0;
    matchState.matches = [];
    matchState.sittingPlayers = [];
    renderPickleMatch();
  }
}

// ==========================================
// 🏆 PickleTourney: Park Tournament Engine
// ==========================================

let tourneyState = {
  currentFormat: 'rotation', // 'rotation' | 'tournament'
  tournamentType: 'fixed',   // 'fixed' | 'rotating'
  scoringFormat: 'sideOut',  // 'sideOut' | 'rally' | 'dreamBreaker'
  targetScore: 11,
  stage: 'setup', // 'setup' | 'roundRobin' | 'playoffs' | 'championship' | 'podium'
  teams: [
    { id: 1, name: 'Dink Dynamos', p1: 'You', p2: 'Alex', wins: 0, losses: 0, pointsWon: 0, pointsLost: 0 },
    { id: 2, name: 'Kitchen Kings', p1: 'Sarah', p2: 'Mike', wins: 0, losses: 0, pointsWon: 0, pointsLost: 0 },
    { id: 3, name: 'Erne Express', p1: 'Jordan', p2: 'Taylor', wins: 0, losses: 0, pointsWon: 0, pointsLost: 0 },
    { id: 4, name: 'Lob Stars', p1: 'Sam', p2: 'Elena', wins: 0, losses: 0, pointsWon: 0, pointsLost: 0 }
  ],
  individualPlayers: [
    { id: 1, name: 'You' },
    { id: 2, name: 'Alex' },
    { id: 3, name: 'Sarah' },
    { id: 4, name: 'Mike' },
    { id: 5, name: 'Jordan' },
    { id: 6, name: 'Taylor' },
    { id: 7, name: 'Sam' },
    { id: 8, name: 'Elena' }
  ],
  individualStandings: [],
  roundRobinMatches: [],
  playoffMatches: [],
  championshipMatch: null,
  bronzeMatch: null,
  goldWinner: null,
  silverWinner: null,
  bronzeWinner: null
};

function setTourneyType(type) {
  tourneyState.tournamentType = type;
  const fixedBox = document.getElementById('tourney-fixed-setup');
  const indivBox = document.getElementById('tourney-indiv-setup');
  const btnFixed = document.getElementById('btn-tourn-type-fixed');
  const btnIndiv = document.getElementById('btn-tourn-type-indiv');

  if (type === 'fixed') {
    if (fixedBox) fixedBox.classList.remove('hidden');
    if (indivBox) indivBox.classList.add('hidden');
    if (btnFixed) btnFixed.className = 'flex-1 py-1.5 rounded-lg font-bold bg-[#C6F24F] text-slate-950';
    if (btnIndiv) btnIndiv.className = 'flex-1 py-1.5 rounded-lg font-medium text-white';
  } else {
    if (fixedBox) fixedBox.classList.add('hidden');
    if (indivBox) indivBox.classList.remove('hidden');
    if (btnFixed) btnFixed.className = 'flex-1 py-1.5 rounded-lg font-medium text-white';
    if (btnIndiv) btnIndiv.className = 'flex-1 py-1.5 rounded-lg font-bold bg-[#C6F24F] text-slate-950';
  }
  renderTournament();
}

function setTourneyScoringFormat(format) {
  tourneyState.scoringFormat = format;
  if (format === 'sideOut') tourneyState.targetScore = 11;
  else if (format === 'rally') tourneyState.targetScore = 15;
  else if (format === 'dreamBreaker') tourneyState.targetScore = 21;

  document.querySelectorAll('.tourn-scoring-btn').forEach(btn => {
    if (btn.dataset.val === format) {
      btn.className = 'tourn-scoring-btn flex-1 py-1.5 rounded-lg font-bold bg-[#C6F24F] text-slate-950';
    } else {
      btn.className = 'tourn-scoring-btn flex-1 py-1.5 rounded-lg font-medium text-white';
    }
  });
}

function clearTourneyTeams() {
  if (confirm('Clear all registered teams?')) {
    tourneyState.teams = [];
    renderTournament();
  }
}

function clearTourneyIndivPlayers() {
  if (confirm('Clear all individual players?')) {
    tourneyState.individualPlayers = [];
    renderTournament();
  }
}

function switchGameFormat(format) {
  tourneyState.currentFormat = format;
  const rotSec = document.getElementById('pm-rotation-section');
  const tourneySec = document.getElementById('pm-tournament-section');
  const btnRot = document.getElementById('btn-format-rotation');
  const btnTourn = document.getElementById('btn-format-tourney');

  if (format === 'rotation') {
    if (rotSec) rotSec.classList.remove('hidden');
    if (tourneySec) tourneySec.classList.add('hidden');
    if (btnRot) btnRot.className = 'flex-1 py-2.5 bg-[#C6F24F] text-slate-950 font-black text-xs rounded-xl shadow-sm';
    if (btnTourn) btnTourn.className = 'flex-1 py-2.5 bg-white/10 text-white font-medium text-xs rounded-xl';
    renderPickleMatch();
  } else {
    if (rotSec) rotSec.classList.add('hidden');
    if (tourneySec) tourneySec.classList.remove('hidden');
    if (btnRot) btnRot.className = 'flex-1 py-2.5 bg-white/10 text-white font-medium text-xs rounded-xl';
    if (btnTourn) btnTourn.className = 'flex-1 py-2.5 bg-[#C6F24F] text-slate-950 font-black text-xs rounded-xl shadow-sm';
    renderTournament();
  }
}

function renderTournament() {
  const views = ['setup', 'roundRobin', 'playoffs', 'championship', 'podium'];
  views.forEach(v => {
    const el = document.getElementById(`tourney-view-${v}`);
    if (el) {
      if (v === tourneyState.stage) el.classList.remove('hidden');
      else el.classList.add('hidden');
    }
  });

  if (tourneyState.stage === 'setup') renderTourneySetup();
  else if (tourneyState.stage === 'roundRobin') renderTourneyRoundRobin();
  else if (tourneyState.stage === 'playoffs') renderTourneyPlayoffs();
  else if (tourneyState.stage === 'championship') renderTourneyChampionship();
  else if (tourneyState.stage === 'podium') renderTourneyPodium();
}

function renderTourneySetup() {
  const list = document.getElementById('tourney-teams-list');
  const countBadge = document.getElementById('tourney-teams-count');
  const indivList = document.getElementById('tourney-indiv-list');
  const indivCountBadge = document.getElementById('tourney-indiv-count');
  const startBtn = document.getElementById('tourney-start-btn');

  if (countBadge) countBadge.innerText = `${tourneyState.teams.length} Teams`;
  if (indivCountBadge) indivCountBadge.innerText = `${tourneyState.individualPlayers.length} Players`;

  const canStart = tourneyState.tournamentType === 'fixed'
    ? tourneyState.teams.length >= 4
    : tourneyState.individualPlayers.length >= 4;

  if (startBtn) {
    startBtn.disabled = !canStart;
    startBtn.className = canStart
      ? 'w-full py-3.5 bg-[#C6F24F] hover:bg-lime-400 text-slate-950 font-black text-xs rounded-2xl shadow transition flex items-center justify-center gap-2'
      : 'w-full py-3.5 bg-slate-700 text-slate-400 font-bold text-xs rounded-2xl cursor-not-allowed flex items-center justify-center gap-2';
  }

  if (list) {
    if (tourneyState.teams.length === 0) {
      list.innerHTML = '<div class="text-[11px] text-slate-400 py-2">No teams added. Add at least 4 teams to start.</div>';
    } else {
      list.innerHTML = tourneyState.teams.map((t, idx) => `
        <div class="flex items-center justify-between p-2.5 bg-white/10 rounded-xl">
          <div>
            <div class="text-xs font-black text-[#C6F24F]">${t.name}</div>
            <div class="text-[10px] text-slate-300">${t.p1} & ${t.p2}</div>
          </div>
          <button onclick="removeTourneyTeam(${idx})" class="text-slate-400 hover:text-red-400 p-1 text-xs">✕</button>
        </div>
      `).join('');
    }
  }

  if (indivList) {
    if (tourneyState.individualPlayers.length === 0) {
      indivList.innerHTML = '<div class="text-[11px] text-slate-400 py-2">No players added. Add at least 4 players to start.</div>';
    } else {
      indivList.innerHTML = tourneyState.individualPlayers.map((p, idx) => `
        <div class="flex items-center justify-between p-2.5 bg-white/10 rounded-xl">
          <div class="text-xs font-bold text-white">${p.name}</div>
          <button onclick="removeTourneyIndivPlayer(${idx})" class="text-slate-400 hover:text-red-400 p-1 text-xs">✕</button>
        </div>
      `).join('');
    }
  }
}

function addTourneyTeam() {
  const nameInput = document.getElementById('tourney-team-name-input');
  const p1Input = document.getElementById('tourney-p1-input');
  const p2Input = document.getElementById('tourney-p2-input');
  if (!nameInput || !p1Input || !p2Input) return;

  const name = moderateText(nameInput.value.trim().substring(0, 20));
  const p1 = moderateText(p1Input.value.trim().substring(0, 18));
  const p2 = moderateText(p2Input.value.trim().substring(0, 18));

  if (!name || !p1 || !p2) {
    showToast('Please enter team name and both players.');
    return;
  }

  tourneyState.teams.push({
    id: Date.now(),
    name: name,
    p1: p1,
    p2: p2,
    wins: 0,
    losses: 0,
    pointsWon: 0,
    pointsLost: 0
  });

  nameInput.value = '';
  p1Input.value = '';
  p2Input.value = '';
  renderTournament();
}

function removeTourneyTeam(idx) {
  tourneyState.teams.splice(idx, 1);
  renderTournament();
}

function addTourneyIndivPlayer() {
  const input = document.getElementById('tourney-indiv-name-input');
  if (!input) return;
  const name = moderateText(input.value.trim().substring(0, 18));
  if (!name) return;

  tourneyState.individualPlayers.push({ id: Date.now(), name: name });
  input.value = '';
  renderTournament();
}

function removeTourneyIndivPlayer(idx) {
  tourneyState.individualPlayers.splice(idx, 1);
  renderTournament();
}

function startTournament() {
  if (tourneyState.tournamentType === 'fixed') {
    if (tourneyState.teams.length < 4) return;
    tourneyState.teams.forEach(t => {
      t.wins = 0; t.losses = 0; t.pointsWon = 0; t.pointsLost = 0;
    });

    tourneyState.roundRobinMatches = [];
    let matchIdx = 1;
    const count = tourneyState.teams.length;
    for (let i = 0; i < count; i++) {
      for (let j = i + 1; j < count; j++) {
        tourneyState.roundRobinMatches.push({
          id: matchIdx,
          title: `Pool Match ${matchIdx}`,
          courtNumber: ((matchIdx - 1) % 2) + 1,
          teamA: tourneyState.teams[i],
          teamB: tourneyState.teams[j],
          scoreA: 0,
          scoreB: 0,
          isFinished: false,
          winnerId: null
        });
        matchIdx++;
      }
    }
  } else {
    // Rotating King of Court
    if (tourneyState.individualPlayers.length < 4) return;
    tourneyState.individualStandings = tourneyState.individualPlayers.map(p => ({
      id: p.id,
      name: p.name,
      wins: 0,
      losses: 0,
      pointsWon: 0,
      pointsLost: 0
    }));

    tourneyState.roundRobinMatches = [];
    let matchIdx = 1;
    let pool = [...tourneyState.individualPlayers].sort(() => Math.random() - 0.5);
    const validCount = Math.floor(pool.length / 4) * 4;
    pool = pool.slice(0, validCount);

    for (let round = 1; round <= 3; round++) {
      pool.sort(() => Math.random() - 0.5);
      for (let i = 0; i < pool.length; i += 4) {
        if (i + 3 >= pool.length) break;
        const p1 = pool[i];
        const p2 = pool[i+1];
        const p3 = pool[i+2];
        const p4 = pool[i+3];

        tourneyState.roundRobinMatches.push({
          id: matchIdx,
          title: `Round ${round} · Match ${matchIdx}`,
          courtNumber: ((matchIdx - 1) % 2) + 1,
          teamA: { id: `${p1.id}_${p2.id}`, name: `${p1.name} + ${p2.name}`, p1: p1.name, p2: p2.name, p1Id: p1.id, p2Id: p2.id },
          teamB: { id: `${p3.id}_${p4.id}`, name: `${p3.name} + ${p4.name}`, p1: p3.name, p2: p4.name, p1Id: p3.id, p2Id: p4.id },
          scoreA: 0,
          scoreB: 0,
          isFinished: false,
          winnerId: null
        });
        matchIdx++;
      }
    }
  }

  tourneyState.stage = 'roundRobin';
  renderTournament();
}

function getRankedStandings() {
  if (tourneyState.tournamentType === 'fixed') {
    return [...tourneyState.teams].sort((a, b) => {
      if (b.wins !== a.wins) return b.wins - a.wins;
      const diffA = a.pointsWon - a.pointsLost;
      const diffB = b.pointsWon - b.pointsLost;
      if (diffB !== diffA) return diffB - diffA;
      return b.pointsWon - a.pointsWon;
    });
  } else {
    return [...tourneyState.individualStandings].sort((a, b) => {
      if (b.wins !== a.wins) return b.wins - a.wins;
      const diffA = a.pointsWon - a.pointsLost;
      const diffB = b.pointsWon - b.pointsLost;
      if (diffB !== diffA) return diffB - diffA;
      return b.pointsWon - a.pointsWon;
    });
  }
}

function renderTourneyRoundRobin() {
  const standingsTable = document.getElementById('tourney-standings-table');
  const matchesContainer = document.getElementById('tourney-rr-matches');
  const advanceBtn = document.getElementById('tourney-advance-playoffs-btn');
  const titleLabel = document.getElementById('tourney-stage1-title');

  if (titleLabel) {
    titleLabel.innerText = tourneyState.tournamentType === 'fixed'
      ? 'Stage 1: Team Round Robin Pool'
      : 'Stage 1: Individual King of Court';
  }

  const standings = getRankedStandings();

  if (standingsTable) {
    if (tourneyState.tournamentType === 'fixed') {
      standingsTable.innerHTML = standings.map((t, idx) => {
        const diff = t.pointsWon - t.pointsLost;
        const isTop4 = idx < 4;
        return `
          <div class="flex items-center justify-between p-2 rounded-lg ${isTop4 ? 'bg-[#C6F24F]/10 border border-[#C6F24F]/20' : 'bg-white/5'}">
            <div class="flex items-center gap-2 flex-1">
              <span class="text-xs font-black ${isTop4 ? 'text-[#C6F24F]' : 'text-slate-500'}">#${idx + 1}</span>
              <div>
                <div class="text-xs font-bold text-white">${t.name}</div>
                <div class="text-[9px] text-slate-400">${t.p1} & ${t.p2}</div>
              </div>
            </div>
            <div class="flex items-center gap-4 text-xs font-bold">
              <span class="${t.wins > t.losses ? 'text-[#C6F24F]' : 'text-white'}">${t.wins}-${t.losses}</span>
              <span class="${diff >= 0 ? 'text-emerald-400' : 'text-orange-400'}">${diff >= 0 ? '+' : ''}${diff}</span>
              <span class="text-slate-300">${t.pointsWon} pts</span>
            </div>
          </div>
        `;
      }).join('');
    } else {
      // Individual standings
      standingsTable.innerHTML = standings.map((p, idx) => {
        const diff = p.pointsWon - p.pointsLost;
        const isTop4 = idx < 4;
        return `
          <div class="flex items-center justify-between p-2 rounded-lg ${isTop4 ? 'bg-[#C6F24F]/10 border border-[#C6F24F]/20' : 'bg-white/5'}">
            <div class="flex items-center gap-2 flex-1">
              <span class="text-xs font-black ${isTop4 ? 'text-[#C6F24F]' : 'text-slate-500'}">#${idx + 1}</span>
              <div class="text-xs font-bold text-white">${p.name}</div>
            </div>
            <div class="flex items-center gap-4 text-xs font-bold">
              <span class="${p.wins > p.losses ? 'text-[#C6F24F]' : 'text-white'}">${p.wins}-${p.losses}</span>
              <span class="${diff >= 0 ? 'text-emerald-400' : 'text-orange-400'}">${diff >= 0 ? '+' : ''}${diff}</span>
              <span class="text-slate-300">${p.pointsWon} pts</span>
            </div>
          </div>
        `;
      }).join('');
    }
  }

  const allFinished = tourneyState.roundRobinMatches.length > 0 && tourneyState.roundRobinMatches.every(m => m.isFinished);

  if (advanceBtn) {
    advanceBtn.disabled = !allFinished;
    const btnLabel = tourneyState.tournamentType === 'fixed'
      ? 'Advance Top 4 to Playoffs ➔'
      : '🥇 Advance Top 4 to Gold Championship ➔';
    advanceBtn.innerHTML = `<span>${btnLabel}</span>`;
    advanceBtn.className = allFinished
      ? 'w-full py-3.5 bg-[#C6F24F] hover:bg-lime-400 text-slate-950 font-black text-xs rounded-2xl shadow transition flex items-center justify-center gap-2'
      : 'w-full py-3.5 bg-slate-700 text-slate-400 font-bold text-xs rounded-2xl cursor-not-allowed flex items-center justify-center gap-2';
  }

  if (matchesContainer) {
    matchesContainer.innerHTML = tourneyState.roundRobinMatches.map((m, idx) => renderTourneyMatchCardHtml('rr', idx, m)).join('');
  }
}

function renderTourneyMatchCardHtml(type, idx, m) {
  const isDream = tourneyState.scoringFormat === 'dreamBreaker';
  const total = m.scoreA + m.scoreB;
  const rotText = isDream ? `<span class="text-[9px] text-amber-400 font-black px-1.5 py-0.5 rounded bg-amber-400/20">⚡️ Rot ${(Math.floor(total/4)%2)+1}</span>` : '';

  return `
    <div class="bg-[#051c36] p-3.5 rounded-2xl border border-sky-900 space-y-2.5">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-1.5">
          <span class="text-[10px] font-black text-[#C6F24F] uppercase">${m.title} · Court ${m.courtNumber}</span>
          ${rotText}
        </div>
        <span class="text-[10px] font-bold ${m.isFinished ? 'text-[#C6F24F]' : 'text-emerald-400'}">${m.isFinished ? 'FINISHED ✓' : '🟢 LIVE'}</span>
      </div>

      <!-- Team A -->
      <div class="flex items-center justify-between p-2 rounded-xl ${m.winnerId === m.teamA.id ? 'bg-[#C6F24F]/15 text-[#C6F24F]' : 'bg-white/5 text-white'}">
        <div>
          <div class="text-xs font-bold">${m.winnerId === m.teamA.id ? '👑 ' : ''}${m.teamA.name}</div>
          <div class="text-[9px] text-slate-400">${m.teamA.p1} & ${m.teamA.p2}</div>
        </div>
        <div class="flex items-center gap-2">
          <button onclick="updateTourneyScore('${type}', ${idx}, 'A', -1)" class="w-6 h-6 rounded bg-white/10 text-white font-bold flex items-center justify-center text-xs">-</button>
          <span class="text-xl font-black min-w-[24px] text-center">${m.scoreA}</span>
          <button onclick="updateTourneyScore('${type}', ${idx}, 'A', 1)" class="w-6 h-6 rounded bg-[#C6F24F] text-slate-950 font-black flex items-center justify-center text-xs">+</button>
        </div>
      </div>

      <!-- Team B -->
      <div class="flex items-center justify-between p-2 rounded-xl ${m.winnerId === m.teamB.id ? 'bg-[#C6F24F]/15 text-[#C6F24F]' : 'bg-white/5 text-white'}">
        <div>
          <div class="text-xs font-bold">${m.winnerId === m.teamB.id ? '👑 ' : ''}${m.teamB.name}</div>
          <div class="text-[9px] text-slate-400">${m.teamB.p1} & ${m.teamB.p2}</div>
        </div>
        <div class="flex items-center gap-2">
          <button onclick="updateTourneyScore('${type}', ${idx}, 'B', -1)" class="w-6 h-6 rounded bg-white/10 text-white font-bold flex items-center justify-center text-xs">-</button>
          <span class="text-xl font-black min-w-[24px] text-center">${m.scoreB}</span>
          <button onclick="updateTourneyScore('${type}', ${idx}, 'B', 1)" class="w-6 h-6 rounded bg-[#C6F24F] text-slate-950 font-black flex items-center justify-center text-xs">+</button>
        </div>
      </div>
    </div>
  `;
}

function updateTourneyScore(type, idx, team, delta) {
  let m;
  if (type === 'rr') m = tourneyState.roundRobinMatches[idx];
  else if (type === 'playoffs') m = tourneyState.playoffMatches[idx];
  else if (type === 'champ') m = tourneyState.championshipMatch;
  else if (type === 'bronze') m = tourneyState.bronzeMatch;

  if (!m) return;

  if (team === 'A') m.scoreA = Math.max(0, m.scoreA + delta);
  else m.scoreB = Math.max(0, m.scoreB + delta);

  const target = tourneyState.targetScore || 11;
  if (m.scoreA >= target && (m.scoreA - m.scoreB) >= 2) {
    m.isFinished = true;
    m.winnerId = m.teamA.id;
  } else if (m.scoreB >= target && (m.scoreB - m.scoreA) >= 2) {
    m.isFinished = true;
    m.winnerId = m.teamB.id;
  } else {
    m.isFinished = false;
    m.winnerId = null;
  }

  // Recalculate round robin stats
  if (type === 'rr') {
    if (tourneyState.tournamentType === 'fixed') {
      tourneyState.teams.forEach(t => { t.wins = 0; t.losses = 0; t.pointsWon = 0; t.pointsLost = 0; });
      tourneyState.roundRobinMatches.forEach(match => {
        if (match.isFinished) {
          const teamA = tourneyState.teams.find(t => t.id === match.teamA.id);
          const teamB = tourneyState.teams.find(t => t.id === match.teamB.id);
          if (teamA && teamB) {
            teamA.pointsWon += match.scoreA; teamA.pointsLost += match.scoreB;
            teamB.pointsWon += match.scoreB; teamB.pointsLost += match.scoreA;
            if (match.winnerId === teamA.id) { teamA.wins++; teamB.losses++; }
            else if (match.winnerId === teamB.id) { teamB.wins++; teamA.losses++; }
          }
        }
      });
    } else {
      // Recalculate individual standings
      tourneyState.individualStandings.forEach(p => { p.wins = 0; p.losses = 0; p.pointsWon = 0; p.pointsLost = 0; });
      tourneyState.roundRobinMatches.forEach(match => {
        if (match.isFinished) {
          const pA1 = tourneyState.individualStandings.find(p => p.id === match.teamA.p1Id);
          const pA2 = tourneyState.individualStandings.find(p => p.id === match.teamA.p2Id);
          const pB1 = tourneyState.individualStandings.find(p => p.id === match.teamB.p1Id);
          const pB2 = tourneyState.individualStandings.find(p => p.id === match.teamB.p2Id);

          if (pA1) { pA1.pointsWon += match.scoreA; pA1.pointsLost += match.scoreB; if (match.winnerId === match.teamA.id) pA1.wins++; else pA1.losses++; }
          if (pA2) { pA2.pointsWon += match.scoreA; pA2.pointsLost += match.scoreB; if (match.winnerId === match.teamA.id) pA2.wins++; else pA2.losses++; }
          if (pB1) { pB1.pointsWon += match.scoreB; pB1.pointsLost += match.scoreA; if (match.winnerId === match.teamB.id) pB1.wins++; else pB1.losses++; }
          if (pB2) { pB2.pointsWon += match.scoreB; pB2.pointsLost += match.scoreA; if (match.winnerId === match.teamB.id) pB2.wins++; else pB2.losses++; }
        }
      });
    }
  }

  renderTournament();
}

function advanceToPlayoffs() {
  const standings = getRankedStandings();
  if (standings.length < 4) return;

  if (tourneyState.tournamentType === 'fixed') {
    tourneyState.playoffMatches = [
      {
        id: 1,
        title: 'Semi-Final 1 (#1 vs #4 Seed)',
        courtNumber: 1,
        teamA: standings[0],
        teamB: standings[3],
        scoreA: 0,
        scoreB: 0,
        isFinished: false,
        winnerId: null
      },
      {
        id: 2,
        title: 'Semi-Final 2 (#2 vs #3 Seed)',
        courtNumber: 2,
        teamA: standings[1],
        teamB: standings[2],
        scoreA: 0,
        scoreB: 0,
        isFinished: false,
        winnerId: null
      }
    ];
    tourneyState.stage = 'playoffs';
  } else {
    // Top 4 individual players
    const p1 = standings[0];
    const p2 = standings[1];
    const p3 = standings[2];
    const p4 = standings[3];

    tourneyState.championshipMatch = {
      id: 1,
      title: '🥇 GOLD CHAMPIONSHIP (TOP 4 ROTATION)',
      courtNumber: 1,
      teamA: { id: `${p1.id}_${p4.id}`, name: `👑 ${p1.name} + ${p4.name}`, p1: p1.name, p2: p4.name },
      teamB: { id: `${p2.id}_${p3.id}`, name: `👑 ${p2.name} + ${p3.name}`, p1: p2.name, p2: p3.name },
      scoreA: 0,
      scoreB: 0,
      isFinished: false,
      winnerId: null
    };

    tourneyState.stage = 'championship';
  }

  renderTournament();
}

function renderTourneyPlayoffs() {
  const container = document.getElementById('tourney-playoffs-matches');
  const advanceBtn = document.getElementById('tourney-advance-champ-btn');

  if (container) {
    container.innerHTML = tourneyState.playoffMatches.map((m, idx) => renderTourneyMatchCardHtml('playoffs', idx, m)).join('');
  }

  const allDone = tourneyState.playoffMatches.length === 2 && tourneyState.playoffMatches.every(m => m.isFinished);
  if (advanceBtn) {
    advanceBtn.disabled = !allDone;
    advanceBtn.className = allDone
      ? 'w-full py-3.5 bg-[#C6F24F] hover:bg-lime-400 text-slate-950 font-black text-xs rounded-2xl shadow transition flex items-center justify-center gap-2'
      : 'w-full py-3.5 bg-slate-700 text-slate-400 font-bold text-xs rounded-2xl cursor-not-allowed flex items-center justify-center gap-2';
  }
}

function advanceToChampionship() {
  const s1 = tourneyState.playoffMatches[0];
  const s2 = tourneyState.playoffMatches[1];
  if (!s1.isFinished || !s2.isFinished) return;

  const s1Win = s1.winnerId === s1.teamA.id ? s1.teamA : s1.teamB;
  const s1Loss = s1.winnerId === s1.teamA.id ? s1.teamB : s1.teamA;
  const s2Win = s2.winnerId === s2.teamA.id ? s2.teamA : s2.teamB;
  const s2Loss = s2.winnerId === s2.teamA.id ? s2.teamB : s2.teamA;

  tourneyState.championshipMatch = {
    id: 1,
    title: '🥇 GOLD MEDAL CHAMPIONSHIP',
    courtNumber: 1,
    teamA: s1Win,
    teamB: s2Win,
    scoreA: 0,
    scoreB: 0,
    isFinished: false,
    winnerId: null
  };

  tourneyState.bronzeMatch = {
    id: 2,
    title: '🥉 BRONZE MEDAL (3RD PLACE)',
    courtNumber: 2,
    teamA: s1Loss,
    teamB: s2Loss,
    scoreA: 0,
    scoreB: 0,
    isFinished: false,
    winnerId: null
  };

  tourneyState.stage = 'championship';
  renderTournament();
}

function renderTourneyChampionship() {
  const champBox = document.getElementById('tourney-champ-match');
  const bronzeBox = document.getElementById('tourney-bronze-match');
  const finalizeBtn = document.getElementById('tourney-finalize-btn');

  if (champBox && tourneyState.championshipMatch) {
    champBox.innerHTML = renderTourneyMatchCardHtml('champ', 0, tourneyState.championshipMatch);
  }
  if (bronzeBox && tourneyState.bronzeMatch) {
    bronzeBox.innerHTML = renderTourneyMatchCardHtml('bronze', 0, tourneyState.bronzeMatch);
  }

  const done = tourneyState.championshipMatch?.isFinished;
  if (finalizeBtn) {
    finalizeBtn.disabled = !done;
    finalizeBtn.className = done
      ? 'w-full py-3.5 bg-[#C6F24F] hover:bg-lime-400 text-slate-950 font-black text-xs rounded-2xl shadow transition flex items-center justify-center gap-2'
      : 'w-full py-3.5 bg-slate-700 text-slate-400 font-bold text-xs rounded-2xl cursor-not-allowed flex items-center justify-center gap-2';
  }
}

function finalizeTournamentPodium() {
  const champ = tourneyState.championshipMatch;
  if (!champ || !champ.isFinished) return;

  tourneyState.goldWinner = (champ.winnerId === champ.teamA.id) ? champ.teamA : champ.teamB;
  tourneyState.silverWinner = (champ.winnerId === champ.teamA.id) ? champ.teamB : champ.teamA;

  const bronze = tourneyState.bronzeMatch;
  if (bronze && bronze.isFinished) {
    tourneyState.bronzeWinner = (bronze.winnerId === bronze.teamA.id) ? bronze.teamA : bronze.teamB;
  } else {
    tourneyState.bronzeWinner = bronze?.teamA;
  }

  tourneyState.stage = 'podium';
  renderTournament();
}

function renderTourneyPodium() {
  const goldEl = document.getElementById('podium-gold-team');
  const silverEl = document.getElementById('podium-silver-team');
  const bronzeEl = document.getElementById('podium-bronze-team');

  if (goldEl && tourneyState.goldWinner) {
    goldEl.innerHTML = `
      <div class="text-xs font-black text-amber-400">🥇 1ST PLACE GOLD CHAMPIONS</div>
      <div class="text-xl font-black text-white">${tourneyState.goldWinner.name}</div>
      <div class="text-xs font-bold text-[#C6F24F]">${tourneyState.goldWinner.p1} & ${tourneyState.goldWinner.p2}</div>
    `;
  }

  if (silverEl && tourneyState.silverWinner) {
    silverEl.innerHTML = `
      <div class="text-[10px] font-bold text-slate-300">🥈 2nd Place Silver</div>
      <div class="text-sm font-black text-white">${tourneyState.silverWinner.name}</div>
      <div class="text-[10px] text-slate-400">${tourneyState.silverWinner.p1} & ${tourneyState.silverWinner.p2}</div>
    `;
  }

  if (bronzeEl && tourneyState.bronzeWinner) {
    bronzeEl.innerHTML = `
      <div class="text-[10px] font-bold text-amber-500">🥉 3rd Place Bronze</div>
      <div class="text-sm font-black text-white">${tourneyState.bronzeWinner.name}</div>
      <div class="text-[10px] text-slate-400">${tourneyState.bronzeWinner.p1} & ${tourneyState.bronzeWinner.p2}</div>
    `;
  }
}

function resetTournament() {
  if (confirm('Reset tournament and return to team registration?')) {
    tourneyState.stage = 'setup';
    tourneyState.roundRobinMatches = [];
    tourneyState.playoffMatches = [];
    tourneyState.championshipMatch = null;
    tourneyState.bronzeMatch = null;
    tourneyState.goldWinner = null;
    tourneyState.silverWinner = null;
    tourneyState.bronzeWinner = null;
    renderTournament();
  }
}

// Init PWA
window.addEventListener('DOMContentLoaded', () => {
  loadState();
  render();
  fetchCityReservations();
  fetchWeather();

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js').catch(err => console.log('SW register fail:', err));
  }

  let deferredPrompt;
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    const installBanner = document.getElementById('install-banner');
    if (installBanner) {
      installBanner.classList.remove('hidden');
      document.getElementById('install-btn').addEventListener('click', () => {
        installBanner.classList.add('hidden');
        deferredPrompt.prompt();
      });
    }
  });
});
