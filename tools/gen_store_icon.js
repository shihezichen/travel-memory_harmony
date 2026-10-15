/* 应用市场（AGC 应用信息）用的直角方图：满幅、不透明、不带圆角。
 *
 * 用法（在仓库根目录执行）：
 *   node tools/gen_store_icon.js store
 *
 * AGC 的「应用图标」示意图写的是「上传直角图标 + Mask蒙层 = 展示效果」，
 * 蒙层由商店自己加 —— 所以这里**不能**带圆角，否则会「圆角里套圆角、四角透明」。
 * 桌面图标那套（分层图标）是另一个脚本 tools/gen_app_icons.js 的事。
 *
 * 产出：store/icon-1024.png（推荐）、store/icon-216.png
 */
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

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
  const t = Buffer.from(type, 'ascii');
  const c = Buffer.alloc(4); c.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, c]);
}
function encodePNG(w, h, rgba) {
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const stride = w * 4;
  const raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (stride + 1)] = 0; rgba.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride); }
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.buf = Buffer.alloc(w * h * 4); }
  blend(x, y, r, g, b, a) {
    if (a <= 0 || x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    if (a > 1) a = 1;
    const i = (y * this.w + x) * 4;
    const dr = this.buf[i], dg = this.buf[i + 1], db = this.buf[i + 2], da = this.buf[i + 3] / 255;
    const na = a + da * (1 - a);
    if (na === 0) return;
    this.buf[i] = Math.round((r * a + dr * da * (1 - a)) / na);
    this.buf[i + 1] = Math.round((g * a + dg * da * (1 - a)) / na);
    this.buf[i + 2] = Math.round((b * a + db * da * (1 - a)) / na);
    this.buf[i + 3] = Math.round(na * 255);
  }
  circle(cx, cy, r, color, alpha = 1) {
    const x0 = Math.max(0, Math.floor(cx - r - 1)), x1 = Math.min(this.w - 1, Math.ceil(cx + r + 1));
    const y0 = Math.max(0, Math.floor(cy - r - 1)), y1 = Math.min(this.h - 1, Math.ceil(cy + r + 1));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const cov = Math.min(1, Math.max(0, r - Math.hypot(x + 0.5 - cx, y + 0.5 - cy) + 0.5));
      if (cov > 0) this.blend(x, y, color[0], color[1], color[2], alpha * cov);
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
      if ((w0 < 0 || w1 < 0 || w2 < 0) && (w0 > 0 || w1 > 0 || w2 > 0)) continue;
      this.blend(x, y, color[0], color[1], color[2], alpha);
    }
  }
}

const TOP = [0xFB, 0xB0, 0x4C];
const BOT = [0xF0, 0x5A, 0x1E];
const WHITE = [255, 255, 255];
const gradientAt = (y, h) => {
  const t = y / (h - 1);
  return [
    Math.round(TOP[0] + (BOT[0] - TOP[0]) * t),
    Math.round(TOP[1] + (BOT[1] - TOP[1]) * t),
    Math.round(TOP[2] + (BOT[2] - TOP[2]) * t),
  ];
};

function storeIcon(size) {
  const c = new Canvas(size, size);
  // 满幅渐变（直角，不裁圆角）
  for (let y = 0; y < size; y++) {
    const g = gradientAt(y, size);
    for (let x = 0; x < size; x++) c.blend(x, y, g[0], g[1], g[2], 1);
  }
  // 和 App 图标里的 background.png 保持同一套柔光
  c.circle(size * 0.82, size * 0.14, size * 0.40, WHITE, 0.10);
  c.circle(size * 0.12, size * 0.90, size * 0.34, [0, 0, 0], 0.06);
  // 定位针 + 足迹点（与分层图标 foreground 相同几何）
  const cx = size * 0.50, cy = size * 0.42, R = size * 0.155;
  for (const [tx, ty, tr, ta] of [[0.24, 0.72, 0.035, 0.95], [0.32, 0.80, 0.030, 0.85],
                                  [0.42, 0.86, 0.026, 0.75], [0.53, 0.89, 0.022, 0.65],
                                  [0.64, 0.90, 0.018, 0.55]]) {
    c.circle(size * tx, size * ty, size * tr, WHITE, ta);
  }
  c.circle(cx, cy, R, WHITE, 1);
  c.triangle([cx - R * 0.78, cy + R * 0.55], [cx + R * 0.78, cy + R * 0.55], [cx, cy + R * 2.35], WHITE, 1);
  c.circle(cx, cy, R * 0.42, gradientAt(cy, size), 1);   // 针眼填底色（不是透明）
  return encodePNG(size, size, c.buf);
}

const outDir = process.argv[2];
if (!outDir) { console.error('usage: node gen_store_icon.js <dir>'); process.exit(1); }
fs.mkdirSync(outDir, { recursive: true });
for (const size of [1024, 216]) {
  const png = storeIcon(size);
  const f = path.join(outDir, `icon-${size}.png`);
  fs.writeFileSync(f, png);
  console.log('wrote', f, png.length + ' bytes');
}
