/* 生成 App 图标（无第三方依赖，纯 Node）。
 *
 * 用法（在仓库根目录执行）：
 *   node tools/gen_app_icons.js AppScope/resources/base/media
 *   node tools/gen_app_icons.js entry/src/main/resources/base/media
 *
 * 产出三张：
 *   background.png  满幅橙色渐变（分层图标的底）
 *   foreground.png  透明底 + 白色定位针 + 足迹点（分层图标的前景）
 *   startIcon.png   圆角方块 + 定位针（启动页图标）
 *
 * 注意：分层图标的圆角由系统裁；商店（AGC 应用信息）要的是「直角原图」，
 * 那是另一个脚本 tools/gen_store_icon.js 的事，别混用。
 */
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

/* ---------- PNG encoding ---------- */
let CRC_TABLE = null;
function crc32(buf) {
  if (!CRC_TABLE) {
    CRC_TABLE = new Int32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      CRC_TABLE[n] = c;
    }
  }
  let crc = -1;
  for (let i = 0; i < buf.length; i++) crc = (crc >>> 8) ^ CRC_TABLE[(crc ^ buf[i]) & 0xff];
  return (crc ^ -1) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}
function encodePNG(width, height, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    rgba.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}

/* ---------- tiny raster canvas ---------- */
class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.buf = Buffer.alloc(w * h * 4); }
  blend(x, y, r, g, b, a) {
    if (a <= 0) return;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    if (a > 1) a = 1;
    const i = (y * this.w + x) * 4;
    const dr = this.buf[i], dg = this.buf[i + 1], db = this.buf[i + 2], da = this.buf[i + 3] / 255;
    const na = a + da * (1 - a);
    const outA = na === 0 ? 0 : na;
    this.buf[i] = Math.round((r * a + dr * da * (1 - a)) / outA);
    this.buf[i + 1] = Math.round((g * a + dg * da * (1 - a)) / outA);
    this.buf[i + 2] = Math.round((b * a + db * da * (1 - a)) / outA);
    this.buf[i + 3] = Math.round(outA * 255);
  }
  clearRect(x, y, w, h) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      const px = x + i, py = y + j;
      if (px < 0 || py < 0 || px >= this.w || py >= this.h) continue;
      const k = (py * this.w + px) * 4;
      this.buf[k] = 0; this.buf[k + 1] = 0; this.buf[k + 2] = 0; this.buf[k + 3] = 0;
    }
  }
  /* anti-aliased circle: signed distance based coverage */
  circle(cx, cy, r, color, alpha = 1) {
    const x0 = Math.max(0, Math.floor(cx - r - 1)), x1 = Math.min(this.w - 1, Math.ceil(cx + r + 1));
    const y0 = Math.max(0, Math.floor(cy - r - 1)), y1 = Math.min(this.h - 1, Math.ceil(cy + r + 1));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
      const cov = Math.min(1, Math.max(0, r - d + 0.5));
      if (cov > 0) this.blend(x, y, color[0], color[1], color[2], alpha * cov);
    }
  }
  /* erase (set alpha 0) with anti-aliasing, using circle coverage */
  eraseCircle(cx, cy, r) {
    const x0 = Math.max(0, Math.floor(cx - r - 1)), x1 = Math.min(this.w - 1, Math.ceil(cx + r + 1));
    const y0 = Math.max(0, Math.floor(cy - r - 1)), y1 = Math.min(this.h - 1, Math.ceil(cy + r + 1));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
      const cov = Math.min(1, Math.max(0, r - d + 0.5));
      if (cov <= 0) continue;
      const i = (y * this.w + x) * 4;
      this.buf[i + 3] = Math.round(this.buf[i + 3] * (1 - cov));
    }
  }
  triangle(p0, p1, p2, color, alpha = 1) {
    const minX = Math.max(0, Math.floor(Math.min(p0[0], p1[0], p2[0])) - 1);
    const maxX = Math.min(this.w - 1, Math.ceil(Math.max(p0[0], p1[0], p2[0])) + 1);
    const minY = Math.max(0, Math.floor(Math.min(p0[1], p1[1], p2[1])) - 1);
    const maxY = Math.min(this.h - 1, Math.ceil(Math.max(p0[1], p1[1], p2[1])) + 1);
    const edge = (a, b, x, y) => (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0]);
    for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) {
      const px = x + 0.5, py = y + 0.5;
      const w0 = edge(p1, p2, px, py), w1 = edge(p2, p0, px, py), w2 = edge(p0, p1, px, py);
      const hasNeg = (w0 < 0) || (w1 < 0) || (w2 < 0);
      const hasPos = (w0 > 0) || (w1 > 0) || (w2 > 0);
      if (hasNeg && hasPos) continue;
      this.blend(x, y, color[0], color[1], color[2], alpha);
    }
  }
  roundRect(x, y, w, h, r, color, alpha = 1) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      const px = i + 0.5, py = j + 0.5;
      let inside = true;
      const cxs = [r, w - r], cys = [r, h - r];
      if (px < r && py < r) inside = Math.hypot(px - r, py - r) <= r;
      else if (px > w - r && py < r) inside = Math.hypot(px - (w - r), py - r) <= r;
      else if (px < r && py > h - r) inside = Math.hypot(px - r, py - (h - r)) <= r;
      else if (px > w - r && py > h - r) inside = Math.hypot(px - (w - r), py - (h - r)) <= r;
      if (inside) this.blend(x + i, y + j, color[0], color[1], color[2], alpha);
    }
  }
  gradient(colorTop, colorBottom) {
    for (let y = 0; y < this.h; y++) {
      const t = y / (this.h - 1);
      const r = Math.round(colorTop[0] + (colorBottom[0] - colorTop[0]) * t);
      const g = Math.round(colorTop[1] + (colorBottom[1] - colorTop[1]) * t);
      const b = Math.round(colorTop[2] + (colorBottom[2] - colorTop[2]) * t);
      for (let x = 0; x < this.w; x++) this.blend(x, y, r, g, b, 1);
    }
  }
  toPNG() { return encodePNG(this.w, this.h, this.buf); }
}

const ORANGE_TOP = [0xFB, 0xB0, 0x4C];   // warm amber
const ORANGE_BOTTOM = [0xF0, 0x5A, 0x1E]; // deep orange
const WHITE = [255, 255, 255];

/* draw the brand glyph (pin + trailing route dots) into a canvas */
function drawGlyph(c, s, opts) {
  const pinColor = opts.white ? WHITE : WHITE;
  const cx = s * 0.50, cy = s * 0.42, R = s * 0.155;

  // trail dots (behind the pin), fading toward lower-left
  const trail = [
    [0.24, 0.72, 0.035, 0.95],
    [0.32, 0.80, 0.030, 0.85],
    [0.42, 0.86, 0.026, 0.75],
    [0.53, 0.89, 0.022, 0.65],
    [0.64, 0.90, 0.018, 0.55],
  ];
  for (const [tx, ty, tr, ta] of trail) c.circle(s * tx, s * ty, s * tr, pinColor, ta);

  // pin body = circle + tail triangle
  c.circle(cx, cy, R, pinColor, 1);
  c.triangle([cx - R * 0.78, cy + R * 0.55], [cx + R * 0.78, cy + R * 0.55], [cx, cy + R * 2.35], pinColor, 1);
  if (opts.holeColor) {
    // fill the inner hole with the local background colour (tile icon)
    c.circle(cx, cy, R * 0.42, opts.holeColor, 1);
  } else {
    // inner hole transparent, shows what's underneath (layered icon)
    c.eraseCircle(cx, cy, R * 0.42);
  }
}

function gradientAt(y, h) {
  const t = y / (h - 1);
  return [
    Math.round(ORANGE_TOP[0] + (ORANGE_BOTTOM[0] - ORANGE_TOP[0]) * t),
    Math.round(ORANGE_TOP[1] + (ORANGE_BOTTOM[1] - ORANGE_TOP[1]) * t),
    Math.round(ORANGE_TOP[2] + (ORANGE_BOTTOM[2] - ORANGE_TOP[2]) * t),
  ];
}

function write(file, buf) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buf);
  console.log('wrote', file, buf.length + ' bytes');
}

const root = process.argv[2];
if (!root) { console.error('usage: node gen_icons.js <media-dir>'); process.exit(1); }

/* background: orange gradient, full bleed */
const bg = new Canvas(1024, 1024);
bg.gradient(ORANGE_TOP, ORANGE_BOTTOM);
bg.circle(1024 * 0.82, 1024 * 0.14, 1024 * 0.40, [255, 255, 255], 0.10);
bg.circle(1024 * 0.12, 1024 * 0.90, 1024 * 0.34, [0, 0, 0], 0.06);

/* foreground: transparent + glyph, safe zone ~ centred 60% */
const fg = new Canvas(1024, 1024);
drawGlyph(fg, 1024, {});

/* startIcon: rounded orange tile with the glyph */
const si = new Canvas(512, 512);
const siBg = new Canvas(512, 512);
siBg.gradient(ORANGE_TOP, ORANGE_BOTTOM);
// rounded mask
for (let y = 0; y < 512; y++) for (let x = 0; x < 512; x++) {
  const r = 512 * 0.22;
  let inside = true;
  const px = x + 0.5, py = y + 0.5;
  if (px < r && py < r) inside = Math.hypot(px - r, py - r) <= r;
  else if (px > 512 - r && py < r) inside = Math.hypot(px - (512 - r), py - r) <= r;
  else if (px < r && py > 512 - r) inside = Math.hypot(px - r, py - (512 - r)) <= r;
  else if (px > 512 - r && py > 512 - r) inside = Math.hypot(px - (512 - r), py - (512 - r)) <= r;
  if (!inside) { const i = (y * 512 + x) * 4; siBg.buf[i + 3] = 0; }
}
drawGlyph(siBg, 512, { holeColor: gradientAt(512 * 0.42, 512) });

write(path.join(root, 'background.png'), bg.toPNG());
write(path.join(root, 'foreground.png'), fg.toPNG());
write(path.join(root, 'startIcon.png'), siBg.toPNG());
