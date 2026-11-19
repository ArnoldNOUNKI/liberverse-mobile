// Génère les icônes Android (classiques + adaptatives) et iOS depuis assets/icon.svg.
// Usage : node tool/make_icons.js   (nécessite le paquet npm « sharp » : npm i -g sharp, ou NODE_PATH vers un node_modules qui le contient)
const sharp = require('sharp'), fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..'), svg = fs.readFileSync(path.join(root, 'assets/icon.svg'));
const res = path.join(root, 'android/app/src/main/res');
const ios = path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const D = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
(async () => {
  for (const [d, k] of Object.entries(D)) {
    const dir = path.join(res, `mipmap-${d}`); fs.mkdirSync(dir, { recursive: true });
    await sharp(svg, { density: 900 }).resize(Math.round(48 * k), Math.round(48 * k)).png().toFile(path.join(dir, 'ic_launcher.png'));
    // Icône adaptative : premier plan 108 dp, logo dans la zone sûre (66 dp)
    const s = Math.round(108 * k), logo = Math.round(70 * k);
    const fg = await sharp(svg, { density: 900 }).resize(logo, logo).png().toBuffer();
    await sharp({ create: { width: s, height: s, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
      .composite([{ input: fg, top: Math.round((s - logo) / 2), left: Math.round((s - logo) / 2) }]).png().toFile(path.join(dir, 'ic_launcher_foreground.png'));
  }
  const any = path.join(res, 'mipmap-anydpi-v26'); fs.mkdirSync(any, { recursive: true });
  fs.writeFileSync(path.join(any, 'ic_launcher.xml'), `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
`);
  fs.writeFileSync(path.join(res, 'values/ic_launcher_background.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#8E0F30</color>
    <color name="liberverse_night">#10070A</color>
</resources>
`);
  const C = JSON.parse(fs.readFileSync(path.join(ios, 'Contents.json')));
  for (const im of C.images) {
    const px = Math.round(parseFloat(im.size) * parseInt(im.scale));
    await sharp(svg, { density: 900 }).resize(px, px).flatten({ background: '#8E0F30' }).png().toFile(path.join(ios, im.filename));
  }
  console.log('Icônes générées');
})();
