// Frames raw app screenshots for the stores: a caption on the brand background above the screen.
//   App Store:   store/screenshots/app-store/*.png    1320 × 2868 (iPhone 6.9")
//   Google Play: store/screenshots/google-play/*.png  1080 × 1920 (9:16; Play allows at most 2:1)
// Usage (from mobile/): node store/frame_screenshots.cjs [path to playwright]
// Playwright comes from the admin panel: npm install in admin/ first.
const fs = require('fs');
const path = require('path');
const { chromium } = require(process.argv[2] || path.resolve(__dirname, '../../admin/node_modules/playwright'));

const root = path.resolve(__dirname, 'screenshots');
const captions = {
  '01-home': 'Абонемент и новости клуба',
  '02-membership': 'Срок, посещения и заморозка',
  '03-qr-pass': 'Вход по QR-пропуску',
  '04-face-access': 'Проходите в клуб по лицу',
  '05-trainers': 'Выберите своего тренера',
  '06-workouts': 'Тренировки по расписанию',
};
const formats = [
  { dir: 'app-store', width: 1320, height: 2868, font: 96, top: 230, shotTop: 560, shotHeight: 2200, radius: 70 },
  { dir: 'google-play', width: 1080, height: 1920, font: 68, top: 120, shotTop: 330, shotHeight: 1500, radius: 48 },
];

const page = (f, caption, image) => `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:${f.width}px;height:${f.height}px;overflow:hidden}
body{background:radial-gradient(${f.width}px ${f.height * 0.5}px at 50% 0%,rgba(30,172,216,.30),transparent 70%),
  radial-gradient(${f.width}px ${f.height * 0.4}px at 50% 100%,rgba(184,243,90,.14),transparent 70%),#050507;
  font-family:-apple-system,"SF Pro Display","Helvetica Neue",Arial,sans-serif}
h1{position:absolute;left:0;right:0;top:${f.top}px;margin:0 ${f.width * 0.08}px;text-align:center;color:#f5f5f7;
  font-size:${f.font}px;line-height:1.12;font-weight:800;letter-spacing:-1px}
img{position:absolute;top:${f.shotTop}px;left:50%;height:${f.shotHeight}px;transform:translateX(-50%);
  border-radius:${f.radius}px;box-shadow:0 0 0 3px #2c2c30,0 40px 120px rgba(0,0,0,.7)}
</style></head><body><h1>${caption}</h1><img src="data:image/png;base64,${image}"></body></html>`;

(async () => {
  const raw = path.join(root, 'raw');
  const names = fs.readdirSync(raw).filter((n) => n.endsWith('.png')).sort();
  if (names.length === 0) throw new Error(`No screenshots in ${raw}`);
  let browser;
  try { browser = await chromium.launch(); } catch { browser = await chromium.launch({ channel: 'chrome' }); }
  for (const f of formats) {
    fs.mkdirSync(path.join(root, f.dir), { recursive: true });
    const tab = await browser.newPage({ viewport: { width: f.width, height: f.height }, deviceScaleFactor: 1 });
    for (const name of names) {
      const id = name.replace(/\.png$/, '');
      const image = fs.readFileSync(path.join(raw, name)).toString('base64');
      await tab.setContent(page(f, captions[id] ?? '', image), { waitUntil: 'load' });
      await tab.screenshot({ path: path.join(root, f.dir, name), omitBackground: false });
      console.log(`${f.dir}/${name}`);
    }
    await tab.close();
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
