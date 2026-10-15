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
        await pg.wait_for_timeout(5000)
        await pg.evaluate("() => { tutoT = 0; el('tuto').style.display='none'; }")
        # 1) vibración en curva: tecla de giro pulsada a velocidad
        await pg.keyboard.down('ArrowUp')
        await pg.wait_for_timeout(1500)
        await pg.keyboard.down('ArrowLeft')
        await pg.wait_for_timeout(300)
        tf1 = await pg.evaluate("() => el('wheelImg').style.transform")
        st = await pg.evaluate("() => car.steer")
        await pg.keyboard.up('ArrowLeft')
        await pg.keyboard.up('ArrowUp')
        wv0 = st
        # 2) vibración de choque: simular impacto de muro
        await pg.evaluate("() => { car.wheelVib = 1.4; }")
        await pg.wait_for_timeout(80)
        tf2 = await pg.evaluate("() => el('wheelImg').style.transform")
        wv1 = await pg.evaluate("() => car.wheelVib")
        await pg.wait_for_timeout(700)
        wv2 = await pg.evaluate("() => car.wheelVib")
        tf3 = await pg.evaluate("() => el('wheelImg').style.transform")
        await pg.screenshot(path='_wvib.png', clip={'x': 400, 'y': 380, 'width': 480, 'height': 380})
        print('curva:', tf1, '| wheelVib en curva:', wv0)
        print('choque:', tf2, '| wheelVib tras choque:', wv1, '-> decae a', wv2)
        print('errors:', errors)
        await b.close()

asyncio.run(main())
