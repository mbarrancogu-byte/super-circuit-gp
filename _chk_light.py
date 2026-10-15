import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(channel='chrome')
        pg = await b.new_page(viewport={'width': 1280, 'height': 760})
        errors = []
        pg.on('pageerror', lambda e: errors.append(str(e)))
        pg.on('console', lambda m: errors.append(m.text) if m.type == 'error' else None)
        await pg.goto('http://localhost:8765/')
        await pg.wait_for_timeout(2500)
        await pg.evaluate("""() => {
            const s=document.getElementById('splash'); if(s) s.style.display='none';
            OPTS.cam = 0; OPTS.touchUi = 1;
            startStage(1, 12345);
        }""")
        await pg.wait_for_timeout(4500)
        await pg.evaluate("""() => {
            tutoT = 0; el('tuto').style.display='none';
            for (const id of TOUCH_IDS) { const e = el(id); if (e) e.style.display = 'flex'; }
        }""")
        await pg.wait_for_timeout(200)
        await pg.screenshot(path='_lgt_off.png', clip={'x': 960, 'y': 460, 'width': 320, 'height': 300})
        await pg.click('#lightsBtn')
        await pg.wait_for_timeout(150)
        await pg.screenshot(path='_lgt_on.png', clip={'x': 960, 'y': 460, 'width': 320, 'height': 300})
        print('errors:', errors)
        await b.close()

asyncio.run(main())
