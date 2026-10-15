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
            OPTS.cam = 2;
            startStage(1, 12345);
            tutoT = 0; el('tuto').style.display='none';
        }""")
        await pg.wait_for_timeout(4500)   # salida
        # teletransporta a la boca de entrada del túnel y deja que la cámara se asiente
        await pg.evaluate("""() => {
            const i = Math.floor(path.length * 0.42), p = path[i];
            car.x = p.x - p.tx * 10; car.z = p.z - p.tz * 10;
            car.a = Math.atan2(-p.tx, -p.tz);
            car.vx = car.vz = 0;
        }""")
        await pg.wait_for_timeout(1200)
        await pg.screenshot(path='_tunarch_a.png', clip={'x': 340, 'y': 200, 'width': 600, 'height': 420})
        # boca de salida
        await pg.evaluate("""() => {
            const i = Math.floor(path.length * 0.58), p = path[i];
            car.x = p.x - p.tx * 10; car.z = p.z - p.tz * 10;
            car.a = Math.atan2(-p.tx, -p.tz);
            car.vx = car.vz = 0;
        }""")
        await pg.wait_for_timeout(1200)
        await pg.screenshot(path='_tunarch_b.png', clip={'x': 340, 'y': 200, 'width': 600, 'height': 420})
        print('errors:', errors)
        await b.close()

asyncio.run(main())
