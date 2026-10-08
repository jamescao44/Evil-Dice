// Run against a fresh Web export served over HTTP. Requires Playwright.
// EVIL_DICE_BROWSER can select an installed Chromium/Edge executable.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const url = process.argv[2] || 'http://127.0.0.1:8821/index.html';

(async () => {
  const browser = await chromium.launch({
    ...(process.env.EVIL_DICE_BROWSER ? { executablePath: process.env.EVIL_DICE_BROWSER } : {}),
    headless: true,
    args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader'],
  });
  let checks = 0;
  fs.mkdirSync('test-output', { recursive: true });
  try {
    for (const dpr of [1, 2, 3]) {
      const context = await browser.newContext({viewport:{width:402,height:874},deviceScaleFactor:dpr,isMobile:true,hasTouch:true});
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
      await page.goto(url);
      await page.waitForSelector('canvas');
      await page.waitForFunction(() => !document.getElementById('status'));
      for (const size of [{width:402,height:874}, {width:402,height:780}, {width:874,height:402}, {width:402,height:874}]) {
        await page.setViewportSize(size);
        // Wait for browser resize and Godot's render loop to agree, including letterboxing.
        await page.waitForFunction(() => {
          const canvas = document.querySelector('canvas');
          const gl = canvas.getContext('webgl2');
          if (!gl) return false;
          const v = gl.getParameter(gl.VIEWPORT);
          const scale = Math.min(canvas.width / 804, canvas.height / 1748);
          const w = Math.round(804 * scale), h = Math.round(1748 * scale);
          return Math.abs(canvas.width - innerWidth * devicePixelRatio) <= 1
            && Math.abs(canvas.height - innerHeight * devicePixelRatio) <= 1
            && Math.abs(v[2] - w) <= 2 && Math.abs(v[3] - h) <= 2
            && Math.abs(v[0] - (canvas.width - w) / 2) <= 2
            && Math.abs(v[1] - (canvas.height - h) / 2) <= 2;
        }, null, {timeout:5000});
        checks++;
      }
      if (dpr === 3) {
        await page.screenshot({path:'test-output/web-home-play.png'});
        await page.touchscreen.tap(125,800); // Ancients tab.
        await page.touchscreen.tap(201,658); // Skills.
        await page.screenshot({path:'test-output/web-home-skills.png'});
        await page.touchscreen.tap(356,154); // Close skills.
        await page.touchscreen.tap(50,800); // Dices tab.
        await page.touchscreen.tap(105,225); // Bone dice.
        await page.screenshot({path:'test-output/web-home-dice.png'});
        await page.touchscreen.tap(201,686); // Equipped / close detail.
        await page.touchscreen.tap(201,800); // Play tab.
        await page.touchscreen.tap(201,696); // Start battle.
        await page.waitForTimeout(350);
        await page.screenshot({path:'test-output/web-fixed-portrait.png'});
        await page.touchscreen.tap(162,84); // DBG, transformed from the 804x1748 design canvas.
        await page.screenshot({path:'test-output/web-fixed-debug-touch.png'});
        await page.touchscreen.tap(356,88); // Close debug menu.
        await page.touchscreen.tap(201,716); // Charge dice.
        await page.screenshot({path:'test-output/web-fixed-charge-touch.png'});
        await page.touchscreen.tap(201,716); // Release dice.
        await page.waitForTimeout(4500);
        await page.touchscreen.tap(358,84); // Grimoire.
        await page.touchscreen.tap(279,88); // Home.
        await page.waitForTimeout(250);
        await page.screenshot({path:'test-output/web-home-return.png'});
      }
      assert.deepEqual(errors, [], 'Web build reports no runtime errors');
      checks++;
      await context.close();
    }
    console.log(`Web sizing: ${checks} checks passed (DPR 1/2/3, portrait, browser-height changes, rotation and return).`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
