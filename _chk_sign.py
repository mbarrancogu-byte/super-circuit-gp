import asyncio, sys
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
            const s = document.getElementById('splash');
            if (s) s.style.display = 'none';
        }""")
        await pg.wait_for_timeout(400)
        await pg.evaluate("() => startStage(1, 12345)")
        await pg.wait_for_timeout(5000)
        # teleportar el coche 30u antes de la curva más cerrada
        await pg.evaluate("""() => {
            let best = 0, bt = 0;
            for (let i = 0; i < pathLen; i++) {
                const p = path[i], pa = path[(i + 6) % pathLen];
                const tr = Math.abs(p.tx * pa.tz - p.tz * pa.tx);
                if (tr > bt) { bt = tr; best = i; }
            }
            const p = path[best];
            car.x = p.x - p.tx * 28; car.z = p.z - p.tz * 28;
            car.a = Math.atan2(p.tx, p.tz);
            car.prog = best;
        }""")
        await pg.wait_for_timeout(400)
        await pg.screenshot(path='_sign_led_a.png')
        await pg.wait_for_timeout(260)
        await pg.screenshot(path='_sign_led_b.png')
        # acercar más: zoom sobre las señales
        print('errors:', errors)
        await b.close()

asyncio.run(main())
