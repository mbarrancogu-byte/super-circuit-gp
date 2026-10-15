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
            OPTS.cam = 0; OPTS.circSel = 2;          // PRINCIPAL
            startStage(1, 12345);
        }""")
        await pg.wait_for_timeout(4500)
        await pg.evaluate("""() => {
            const o = obstacles.find(o => o.r > 2.5);
            if (o) { car.x = o.x - 10; car.z = o.z + 3; car.a = Math.atan2(10, -3); }
            car.vx = car.vz = 0;
            camZoom = 0.04;
            tutoT = 0; el('tuto').style.display='none';
        }""")
        await pg.wait_for_timeout(350)
        await pg.screenshot(path='_tree.png')
        print('errors:', errors)
        await b.close()

asyncio.run(main())
