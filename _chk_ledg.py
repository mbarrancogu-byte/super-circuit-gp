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
            OPTS.cam = 1;
            startStage(1, 12345);
        }""")
        await pg.wait_for_timeout(3500)
        n = await pg.evaluate("() => beacons.length")
        print('beacons:', n)
        # pulso: muestra opacidades en dos instantes
        ops = await pg.evaluate("() => beacons.slice(0,12).map(b=>+b.b.opacity.toFixed(2))")
        await pg.wait_for_timeout(400)
        ops2 = await pg.evaluate("() => beacons.slice(0,12).map(b=>+b.b.opacity.toFixed(2))")
        print('ops t0:', ops)
        print('ops t1:', ops2)
        await pg.screenshot(path='_ledg1.png')
        await pg.wait_for_timeout(300)
        await pg.screenshot(path='_ledg2.png')
        print('errors:', errors)
        await b.close()

asyncio.run(main())
