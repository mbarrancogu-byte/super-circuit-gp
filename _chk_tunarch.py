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
        # coche a la entrada del túnel (i0 = 42% del path)
        await pg.evaluate("""() => {
            const i = Math.floor(path.length * 0.42);
            const p = path[i];
            car.x = p.x - p.tx * 18; car.z = p.z - p.tz * 18;
            car.a = Math.atan2(-p.tx, -p.tz);
            car.v = 0;
        }""")
        await pg.wait_for_timeout(400)
        await pg.screenshot(path='_tunin.png')
        # boca de salida (i1 = 58%)
        await pg.evaluate("""() => {
            const i = Math.floor(path.length * 0.58);
            const p = path[i];
            car.x = p.x - p.tx * 18; car.z = p.z - p.tz * 18;
            car.a = Math.atan2(-p.tx, -p.tz);
            car.v = 0;
        }""")
        await pg.wait_for_timeout(400)
        await pg.screenshot(path='_tunout.png')
        print('errors:', errors)
        await b.close()

asyncio.run(main())
