/** Top-down canvas renderer for the harness. World space is Z-up, metres. */
const ZOOMS = [0.22, 0.42, 0.7, 1.1];

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.zoomIndex = 1;
    this.world = null;
    this.track = null;
    this.cam = { x: 0, y: 0 };
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  resize() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    this.canvas.width = Math.floor(window.innerWidth * dpr);
    this.canvas.height = Math.floor(window.innerHeight * dpr);
    this.canvas.style.width = `${window.innerWidth}px`;
    this.canvas.style.height = `${window.innerHeight}px`;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.w = window.innerWidth;
    this.h = window.innerHeight;
  }

  cycleZoom() {
    this.zoomIndex = (this.zoomIndex + 1) % ZOOMS.length;
    return ZOOMS[this.zoomIndex];
  }

  get scale() {
    return ZOOMS[this.zoomIndex];
  }

  setWorld(world) {
    this.world = world;
  }

  setTrack(track) {
    this.track = track;
  }

  worldToScreen(x, y) {
    return {
      x: this.w / 2 + (x - this.cam.x) * this.scale,
      y: this.h / 2 - (y - this.cam.y) * this.scale,
    };
  }

  draw({ self, entities, effects, pickupsTaken, cameraTarget, palette }) {
    const ctx = this.ctx;
    const s = this.scale;
    const target = cameraTarget ?? self?.pos ?? { x: 0, y: 0 };
    this.cam.x += (target.x - this.cam.x) * 0.18;
    this.cam.y += (target.y - this.cam.y) * 0.18;

    ctx.fillStyle = '#080a0f';
    ctx.fillRect(0, 0, this.w, this.h);
    this.drawGrid(ctx, s);
    if (this.world) {
      this.drawRoads(ctx, s);
      this.drawMarkers(ctx, s);
      this.drawPickups(ctx, s, pickupsTaken);
    }
    if (this.track) {
      this.drawRoute(ctx, s);
      this.drawGates(ctx, s, entities, self);
    }
    for (const entity of entities) {
      if (entity.isSelf) continue;
      this.drawCar(ctx, s, entity, palette.get(entity.id), false);
    }
    if (self) this.drawCar(ctx, s, self, palette.get(self.id ?? 0), true);
    this.drawEffects(ctx, s, effects);
    this.drawCompass(ctx);
  }

  drawGrid(ctx, s) {
    const step = s > 0.8 ? 50 : s > 0.35 ? 100 : 250;
    const stride = step * s;
    const offsetX = ((-this.cam.x * s + this.w / 2) % stride + stride) % stride;
    const offsetY = ((this.cam.y * s + this.h / 2) % stride + stride) % stride;
    ctx.strokeStyle = 'rgba(255,255,255,0.035)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let x = offsetX; x < this.w; x += stride) {
      ctx.moveTo(x, 0);
      ctx.lineTo(x, this.h);
    }
    for (let y = offsetY; y < this.h; y += stride) {
      ctx.moveTo(0, y);
      ctx.lineTo(this.w, y);
    }
    ctx.stroke();
  }

  drawRoads(ctx, s) {
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    for (const road of this.world.roads ?? []) {
      ctx.beginPath();
      road.points.forEach((p, i) => {
        const pt = this.worldToScreen(p[0], p[1]);
        if (i === 0) ctx.moveTo(pt.x, pt.y);
        else ctx.lineTo(pt.x, pt.y);
      });
      ctx.closePath();
      ctx.strokeStyle = '#131a26';
      ctx.lineWidth = Math.max(6, 16 * s);
      ctx.stroke();
      ctx.strokeStyle = 'rgba(90,120,160,0.16)';
      ctx.lineWidth = Math.max(2, 3 * s);
      ctx.stroke();
    }
  }

  drawRoute(ctx, s) {
    const route = this.track?.route ?? [];
    if (route.length < 2) return;
    ctx.beginPath();
    route.forEach((p, i) => {
      const pt = this.worldToScreen(p[0], p[1]);
      if (i === 0) ctx.moveTo(pt.x, pt.y);
      else ctx.lineTo(pt.x, pt.y);
    });
    ctx.closePath();
    ctx.setLineDash([10 * Math.max(0.4, s), 12 * Math.max(0.4, s)]);
    ctx.strokeStyle = 'rgba(255,210,63,0.35)';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.setLineDash([]);
  }

  drawGates(ctx, s, entities, self) {
    const gates = this.track?.checkpoints ?? [];
    const nextIndex = self?.nextGate ?? -1;
    for (const gate of gates) {
      const yaw = (gate.yawDeg * Math.PI) / 180;
      const halfW = gate.width / 2;
      const dx = -Math.sin(yaw) * halfW;
      const dy = Math.cos(yaw) * halfW;
      const a = this.worldToScreen(gate.pos[0] - dx, gate.pos[1] - dy);
      const b = this.worldToScreen(gate.pos[0] + dx, gate.pos[1] + dy);
      const isNext = gate.index === nextIndex;
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.strokeStyle = isNext ? 'rgba(255,93,46,0.95)' : 'rgba(255,255,255,0.18)';
      ctx.lineWidth = isNext ? 4 : 2;
      ctx.stroke();
      if (isNext) {
        ctx.beginPath();
        ctx.arc(b.x, b.y, 3, 0, Math.PI * 2);
        ctx.fillStyle = '#ff5d2e';
        ctx.fill();
      }
    }
  }

  drawMarkers(ctx, s) {
    if (!this.world || s < 0.3) return;
    ctx.font = '10px Inter, system-ui, sans-serif';
    for (const marker of this.world.markers ?? []) {
      const pt = this.worldToScreen(marker.pos[0], marker.pos[1]);
      if (pt.x < -50 || pt.x > this.w + 50 || pt.y < -50 || pt.y > this.h + 50) continue;
      const label = marker.kind.replace(/(City|Desert|Jungle|Industrial|Snow)$/i, '');
      const interesting = /Shop|SafeHouse|Ticket|BossEnd|Challenge|Entrance|Mission/i.test(label);
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, interesting ? 3.2 : 1.8, 0, Math.PI * 2);
      ctx.fillStyle = interesting ? 'rgba(143,211,255,0.75)' : 'rgba(143,211,255,0.25)';
      ctx.fill();
      if (interesting && s > 0.55) {
        ctx.fillStyle = 'rgba(200,225,255,0.55)';
        ctx.fillText(label.slice(0, 22), pt.x + 6, pt.y + 3);
      }
    }
  }

  drawPickups(ctx, s, taken) {
    if (!this.world || s < 0.3) return;
    const colours = { repair: '#43d17c', health: '#43d17c', nitro: '#ffd23f', ammo: '#8fd3ff', cashstash: '#a6ff6b' };
    for (const pickup of this.world.pickups ?? []) {
      if (taken?.has(pickup.index)) continue;
      const pt = this.worldToScreen(pickup.pos[0], pickup.pos[1]);
      if (pt.x < -20 || pt.x > this.w + 20 || pt.y < -20 || pt.y > this.h + 20) continue;
      ctx.beginPath();
      ctx.arc(pt.x, pt.y, Math.max(2, 4 * s), 0, Math.PI * 2);
      ctx.fillStyle = colours[pickup.kind] ?? '#ffffff';
      ctx.globalAlpha = 0.85;
      ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  drawCar(ctx, s, entity, color, isSelf) {
    const pt = this.worldToScreen(entity.pos.x, entity.pos.y);
    const length = Math.max(9, 26 * s);
    const width = Math.max(5, 13 * s);
    ctx.save();
    ctx.translate(pt.x, pt.y);
    ctx.rotate(-entity.yaw);
    if (entity.dead) ctx.globalAlpha = 0.35;

    ctx.beginPath();
    ctx.roundRect(-length / 2, -width / 2, length, width, Math.max(2, 3 * s));
    ctx.fillStyle = color;
    ctx.fill();
    ctx.strokeStyle = isSelf ? 'rgba(255,255,255,0.9)' : 'rgba(0,0,0,0.55)';
    ctx.lineWidth = isSelf ? 2 : 1;
    ctx.stroke();

    ctx.beginPath();
    ctx.moveTo(length / 2 - 2, 0);
    ctx.lineTo(length / 2 - width * 0.7, -width * 0.35);
    ctx.lineTo(length / 2 - width * 0.7, width * 0.35);
    ctx.closePath();
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.fill();
    ctx.restore();

    if (s > 0.3) {
      ctx.font = '600 11px Inter, system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillStyle = isSelf ? '#ffd23f' : 'rgba(255,255,255,0.86)';
      ctx.fillText(entity.name ?? '', pt.x, pt.y - width - 6);
      if (entity.health < 100 && !entity.isBot) {
        const barW = 26;
        ctx.fillStyle = 'rgba(0,0,0,0.55)';
        ctx.fillRect(pt.x - barW / 2, pt.y - width - 4, barW, 3);
        ctx.fillStyle = entity.health > 40 ? '#43d17c' : '#ff4d5e';
        ctx.fillRect(pt.x - barW / 2, pt.y - width - 4, (barW * entity.health) / 100, 3);
      }
      ctx.textAlign = 'start';
    }
  }

  drawEffects(ctx, s, effects) {
    const now = performance.now();
    for (const fx of effects) {
      const life = (fx.until - now) / (fx.duration ?? 300);
      if (life <= 0) continue;
      if (fx.type === 'tracer') {
        const a = this.worldToScreen(fx.from.x, fx.from.y);
        const b = this.worldToScreen(fx.to.x, fx.to.y);
        ctx.beginPath();
        ctx.moveTo(a.x, a.y);
        ctx.lineTo(b.x, b.y);
        ctx.strokeStyle = `rgba(255,210,63,${0.8 * life})`;
        ctx.lineWidth = 2;
        ctx.stroke();
      } else if (fx.type === 'boom') {
        const pt = this.worldToScreen(fx.pos.x, fx.pos.y);
        const r = (1 - life) * (fx.radius ?? 12) * Math.max(0.5, s);
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, r, 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(255,120,40,${life})`;
        ctx.lineWidth = 3;
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, r * 0.5, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,210,63,${0.35 * life})`;
        ctx.fill();
      } else if (fx.type === 'text') {
        const pt = this.worldToScreen(fx.pos.x, fx.pos.y);
        ctx.font = '700 13px Inter, system-ui, sans-serif';
        ctx.fillStyle = `rgba(255,255,255,${life})`;
        ctx.fillText(fx.text, pt.x, pt.y - (1 - life) * 26);
      }
    }
  }

  drawCompass(ctx) {
    ctx.save();
    ctx.translate(this.w - 34, 40);
    ctx.beginPath();
    ctx.arc(0, 0, 14, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(14,18,26,0.7)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.stroke();
    ctx.fillStyle = '#ff5d2e';
    ctx.font = '700 10px Inter, system-ui, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('N', 0, -3);
    ctx.restore();
  }
}

/** Stable colour per player id (like a livery). */
export function makePalette() {
  const base = ['#ff5d2e', '#8fd3ff', '#43d17c', '#ffd23f', '#c39bff', '#ff8fb1', '#7ee7d8', '#f0a35e'];
  const cache = new Map();
  return {
    get(id) {
      if (!cache.has(id)) cache.set(id, base[cache.size % base.length]);
      return cache.get(id);
    },
  };
}
