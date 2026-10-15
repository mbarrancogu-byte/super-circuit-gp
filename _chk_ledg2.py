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
            startStage(1, 12345);
            tutoT = 0; el('tuto').style.display='none';
        }""")
        await pg.wait_for_timeout(3000)
        # mueve el coche hasta una baliza y mira con camara cercana
        await pg.evaluate("""() => {
            const bc = beacons[Math.floor(beacons.length/2)];
            car.x = bc.x; car.z = bc.z + 6; car.a = -Math.PI/2;
            car.v = 0;
        }""")
        for t in range(4):
            await pg.wait_for_timeout(280)
            await pg.screenshot(path=f'_ledc{t}.png')
        print('errors:', errors)
        await b.close()

asyncio.run(main())
