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
            startStage(1, 12345);
            tutoT = 0; el('tuto').style.display='none';
        }""")
        await pg.wait_for_timeout(3000)
        print('camera?', await pg.evaluate("() => typeof cam3 + ' ' + typeof paused + ' ' + typeof renderer"))
        # pausa el juego y coloca la cámara mirando la boca del túnel de frente
        await pg.evaluate("""() => {
            paused = true;
            const i = Math.floor(path.length * 0.42);
            const p = path[i];
            const nx = -p.tz, nz = p.tx;
            cam3.position.set(p.x - p.tx * 16, 3.4, p.z - p.tz * 16);
            cam3.lookAt(p.x, 2.2, p.z);
            renderer3.render(scene3, cam3);
        }""")
        await pg.wait_for_timeout(300)
        await pg.screenshot(path='_tunarch_in.png')
        await pg.evaluate("""() => {
            const i = Math.floor(path.length * 0.58);
            const p = path[i];
            cam3.position.set(p.x + p.tx * 16, 3.4, p.z + p.tz * 16);
            cam3.lookAt(p.x, 2.2, p.z);
            renderer3.render(scene3, cam3);
        }""")
        await pg.wait_for_timeout(300)
        await pg.screenshot(path='_tunarch_out.png')
        print('errors:', errors)
        await b.close()

asyncio.run(main())
