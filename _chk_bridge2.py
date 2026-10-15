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
            OPTS.cam = 0;
            startStage(1, 12345, false, 'demo');
        }""")
        await pg.wait_for_timeout(4500)
        await pg.evaluate("""() => {
            const i = Math.floor(pathLen * 0.8), p = path[i];
            car.x = p.x - p.tx * 4; car.z = p.z - p.tz * 4;
            car.a = Math.atan2(p.tx, p.tz);
            car.prog = i;
            tutoT = 0; el('tuto').style.display='none';
        }""")
        await pg.wait_for_timeout(400)
        await pg.screenshot(path='_bridge2.png')
        await pg.screenshot(path='_bridge3.png', clip={'x': 250, 'y': 100, 'width': 780, 'height': 560})
        print('errors:', errors)
        await b.close()

asyncio.run(main())
