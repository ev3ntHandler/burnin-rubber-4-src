const $ = (id) => document.getElementById(id);

const PHASE_NAMES = ['LOBBY', 'COUNTDOWN', 'RACING', 'FINISHING', 'RESULTS'];

export const ui = {
  el: $,

  screen(name) {
    $('lobby').classList.toggle('hidden', name !== 'lobby');
    $('game').classList.toggle('hidden', name !== 'game');
  },

  pill(id, text) {
    $(id).textContent = text;
  },

  room(name, players) {
    $('room-pill').textContent = name;
    $('players-pill').textContent = `${players} player${players === 1 ? '' : 's'}`;
  },

  chat(text, { name = '', channel = 0, system = false, me = false } = {}) {
    const log = $('chat-log');
    const line = document.createElement('div');
    if (system) {
      line.className = 'system';
      line.textContent = text;
    } else if (channel === 3) {
      line.className = 'whisper';
      line.innerHTML = `<b>${escapeHtml(name)}</b> → ${escapeHtml(text)}`;
    } else if (me) {
      line.className = 'me';
      line.textContent = text;
    } else {
      line.innerHTML = `<b>${escapeHtml(name)}</b> ${escapeHtml(text)}`;
    }
    log.appendChild(line);
    while (log.children.length > 60) log.firstChild.remove();
    log.scrollTop = log.scrollHeight;
  },

  toast(text, ms = 2600) {
    const box = $('toasts');
    const el = document.createElement('div');
    el.textContent = text;
    box.appendChild(el);
    setTimeout(() => el.remove(), ms);
    while (box.children.length > 4) box.firstChild.remove();
  },

  kill(text) {
    const feed = $('killfeed');
    const el = document.createElement('div');
    el.textContent = text;
    feed.appendChild(el);
    setTimeout(() => el.remove(), 5000);
    while (feed.children.length > 5) feed.firstChild.remove();
  },

  speed(kmh, health, nitro) {
    $('speed-value').textContent = String(Math.round(kmh));
    $('health-bar').style.width = `${Math.max(0, Math.min(100, health))}%`;
    $('nitro-bar').style.width = `${Math.max(0, Math.min(100, nitro * 100))}%`;
  },

  race(race, selfId, names) {
    const panel = $('race-panel');
    if (!race) {
      panel.classList.add('hidden');
      return;
    }
    panel.classList.remove('hidden');
    $('race-phase').textContent = PHASE_NAMES[race.phase] ?? '—';
    $('race-timer').textContent = formatTime(race.timeMs);
    const list = $('standings');
    list.innerHTML = '';
    race.standings.slice(0, 10).forEach((standing, i) => {
      const li = document.createElement('li');
      if (standing.id === selfId) li.className = 'me';
      const name = names.get(standing.id) ?? `#${standing.id}`;
      const lapText = standing.finished ? 'FIN' : `${standing.lap + (race.phase === 2 ? 1 : 0)}/${race.totalLaps}`;
      li.innerHTML = `<span class="pos">${i + 1}</span><span>${escapeHtml(name)}</span><span class="lap">${lapText}</span><span class="gap">${
        standing.finished ? formatTime(standing.finishTimeMs) : `${Math.round(standing.dist)}m`
      }</span>`;
      list.appendChild(li);
    });

    const cd = $('race-countdown');
    if (race.phase === 1 && race.countdownMs > 0) {
      cd.classList.remove('hidden');
      cd.textContent = String(Math.ceil(race.countdownMs / 1000));
    } else {
      cd.classList.add('hidden');
    }
  },

  rooms(rooms, onJoin) {
    const list = $('rooms');
    list.innerHTML = '';
    if (!rooms.length) {
      const li = document.createElement('li');
      li.innerHTML = '<span>No rooms yet — start one!</span>';
      list.appendChild(li);
      return;
    }
    for (const room of rooms.slice(0, 12)) {
      const li = document.createElement('li');
      const label = room.mode === 'race' ? `🏁 ${room.track ?? 'race'}` : `🌆 ${room.world}`;
      li.innerHTML = `<span>${escapeHtml(label)}</span><span>${room.players}/${room.maxPlayers ?? 32} · ${
        room.joinable ? 'open' : 'locked'
      }</span>`;
      list.appendChild(li);
    }
  },

  tracks(tracks, selected) {
    const select = $('track');
    select.innerHTML = '';
    for (const track of tracks) {
      const option = document.createElement('option');
      option.value = track.id;
      option.textContent = `${track.name} · ${(track.length / 1000).toFixed(1)} km · ${track.type}`;
      select.appendChild(option);
    }
    if (selected) select.value = selected;
  },

  help(show) {
    $('help').classList.toggle('hidden', !show);
  },
};

export function formatTime(ms) {
  const total = Math.max(0, Math.round(ms));
  const minutes = Math.floor(total / 60000);
  const seconds = Math.floor((total % 60000) / 1000);
  const millis = total % 1000;
  return `${minutes}:${String(seconds).padStart(2, '0')}.${String(millis).padStart(3, '0')}`;
}

export function escapeHtml(text) {
  return String(text ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
