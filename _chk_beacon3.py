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
        }""")
        await pg.wait_for_timeout(6000)
        # poner el coche junto a la primera baliza
        await pg.evaluate("""() => {
            const bc = beacons[Math.floor(beacons.length / 2)];
            if (!bc) return;
            car.x = bc.x; car.z = bc.z + 16;
            car.a = Math.PI / 2;
            tutoT = 0; el('tuto').style.display = 'none';
        }""")
        await pg.wait_for_timeout(300)
        # capturas completas para ver las balizas encendidas/apagadas
        for k in range(4):
            await pg.screenshot(path=f'_bn3_{k}.png', clip={'x': 250, 'y': 30, 'width': 780, 'height': 560})
            await pg.wait_for_timeout(330)
        print('errors:', errors)
        await b.close()

asyncio.run(main())
