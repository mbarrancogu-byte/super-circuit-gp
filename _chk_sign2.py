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
        await pg.evaluate("() => { const s=document.getElementById('splash'); if(s) s.style.display='none'; }")
        await pg.evaluate("() => startStage(1, 12345)")
        await pg.wait_for_timeout(4500)
        # coche justo antes de la curva más cerrada, mirando a las señales
        await pg.evaluate("""() => {
            let best = 0, bt = 0;
            for (let i = 0; i < pathLen; i++) {
                const p = path[i], pa = path[(i + 6) % pathLen];
                const tr = Math.abs(p.tx * pa.tz - p.tz * pa.tx);
                if (tr > bt) { bt = tr; best = i; }
            }
            const p = path[best];
            car.x = p.x - p.tx * 14; car.z = p.z - p.tz * 14;
            car.a = Math.atan2(p.tx, p.tz);
            car.prog = best;
        }""")
        # 4 capturas cada 140ms -> 4 fases del barrido
        for k in range(4):
            await pg.screenshot(path=f'_led_{k}.png', clip={'x': 560, 'y': 0, 'width': 720, 'height': 500})
            await pg.wait_for_timeout(140)
        print('errors:', errors)
        await b.close()

asyncio.run(main())
