import asyncio, json
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(channel='chrome', args=['--use-angle=d3d11'])
        pg = await b.new_page(viewport={'width':1280,'height':760})
        errors=[]
        pg.on('pageerror', lambda e: errors.append('PE:'+str(e)[:200]))
        pg.on('console', lambda m: errors.append('CE:'+m.text[:200]) if m.type=='error' else None)
        shots=[]
        async def go(name): 
            await pg.screenshot(path=f'_aud_{name}.png'); shots.append(name)

        await pg.goto('http://127.0.0.1:52793/index.html')
        await pg.wait_for_timeout(2200)
        await go('01_splash')
        await pg.mouse.click(640,400); await pg.wait_for_timeout(1800)
        await go('02_intro')
        try: await pg.click('#introExit', timeout=2500)
        except Exception as e: errors.append('noIntroExit')
        await pg.wait_for_timeout(1800)
        await go('03_menu')
        # ficha
        await pg.click('#car3dInfo'); await pg.wait_for_timeout(1800); await go('04_ficha')
        await pg.evaluate("document.getElementById('ciBack').click()"); await pg.wait_for_timeout(500)
        # opciones
        await pg.click('#optsBtn'); await pg.wait_for_timeout(700); await go('05_opts')
        # cars3d
        await pg.click('#cars3dBtn'); await pg.wait_for_timeout(2200); await go('06_cars3d')
        await pg.evaluate("document.getElementById('c3dAll').click()"); await pg.wait_for_timeout(3200)
        await go('07_cars3d_all')
        await pg.evaluate("document.getElementById('c3dBack').click()"); await pg.wait_for_timeout(500)
        await pg.evaluate("document.getElementById('optBack').click()"); await pg.wait_for_timeout(500)
        # pantallas del menu
        for bid,name in [('demoBtn','08_demo'),('champBtn','09_champ'),('ttBtn','10_tt'),('koBtn','11_ko'),('powBtn','12_pow')]:
            try:
                await pg.click('#'+bid, timeout=1500); await pg.wait_for_timeout(700)
                await go(name)
                # volver al menu
                await pg.evaluate("""(() => {
                  const menu=document.getElementById('menu');
                  document.querySelectorAll('.screen.show').forEach(s=>{ if(s.id!=='menu') s.classList.remove('show'); });
                  menu.classList.add('show');
                })()""")
                await pg.wait_for_timeout(300)
            except Exception as e: errors.append(f'{bid}:{str(e)[:80]}')
        # arrancar carrera
        try:
            await pg.click('#playBtn', timeout=1500)
            await pg.wait_for_timeout(4500)   # countdown + inicio
            await go('13_race')
            # acelerar un rato
            await pg.evaluate("kState.gas=1")
            await pg.wait_for_timeout(4000)
            await go('14_race_gas')
            # pausa
            await pg.evaluate("setPaused(true)"); await pg.wait_for_timeout(400)
            await go('15_pause')
            await pg.evaluate("setPaused(false)"); await pg.wait_for_timeout(300)
            st = await pg.evaluate("({playing, paused, laps: car.lap, dist: car.dist, fps: (window._fps||fps||0)})")
            print('race:', json.dumps(st))
        except Exception as e: errors.append('race:'+str(e)[:120])
        print('errors:', json.dumps(errors, indent=0))
        await b.close()
asyncio.run(main())
