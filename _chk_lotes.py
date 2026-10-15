import asyncio, json
from playwright.async_api import async_playwright

URL = 'http://127.0.0.1:52793/index.html'

async def main():
    errors = []
    async with async_playwright() as p:
        b = await p.chromium.launch(channel='chrome')
        pg = await b.new_page(viewport={'width': 1280, 'height': 760})
        pg.on('pageerror', lambda e: errors.append(str(e)))
        pg.on('console', lambda m: errors.append(m.text) if m.type == 'error' else None)
        await pg.goto(URL)
        await pg.wait_for_timeout(2500)

        # Portada -> cerrar con Enter -> intro -> SALTAR -> menu
        st = await pg.evaluate("""() => ({
          splash: document.getElementById('splash').classList.contains('hide'),
          glbBar: !!document.getElementById('glbBar'),
          glbLoad: getComputedStyle(document.getElementById('glbLoad')).display })""")
        print('SPLASH:', json.dumps(st))

        await pg.keyboard.press('Enter'); await pg.wait_for_timeout(600)
        intro = await pg.evaluate("document.getElementById('intro').classList.contains('show')")
        if intro:
            await pg.click('#introExit'); await pg.wait_for_timeout(600)
        # SALTAR vuelve a la portada → cerrarla otra vez para llegar al menú
        if not await pg.evaluate("document.getElementById('splash').classList.contains('hide')"):
            await pg.keyboard.press('Enter'); await pg.wait_for_timeout(600)
        await pg.screenshot(path='_lote_menu.png')

        # --- Entrar a carrera normal (JUGAR) ---
        await pg.click('#playBtn'); await pg.wait_for_timeout(3000)
        # saltar luces si hace falta
        await pg.wait_for_timeout(2500)
        playing = await pg.evaluate('playing')
        print('PLAYING:', playing)

        # Elementos nuevos presentes en HUD
        hud = await pg.evaluate("""() => ({
          fuel: !!document.getElementById('fuelChip'),
          fuelVis: document.getElementById('fuelChip').style.display,
          sc: !!document.getElementById('scChip'),
          form: !!document.getElementById('formChip'),
          re: !!document.getElementById('reChip'),
          boards: raceBoards.length })""")
        print('HUD:', json.dumps(hud))

        # Marcha atrás: X mantenido tras frenar -> R y vf negativo
        await pg.keyboard.down('x'); await pg.wait_for_timeout(2600)
        rv = await pg.evaluate("""() => ({ gear: document.getElementById('gearNum').textContent,
          vx: +car.vx.toFixed(1), vz: +car.vz.toFixed(1) })""")
        await pg.keyboard.up('x')
        print('REVERSE:', json.dumps(rv))
        await pg.screenshot(path='_lote_race.png')

        # Nitro sobrecalentamiento: mantener N 4.5s
        await pg.keyboard.down('w'); await pg.wait_for_timeout(1200)
        await pg.keyboard.down('n'); await pg.wait_for_timeout(4500)
        nit = await pg.evaluate("""() => ({ heat: Math.round(nitroHeat), hot: document.getElementById('nitroWrap').classList.contains('hot'), on: nitroOn })""")
        await pg.keyboard.up('n'); await pg.keyboard.up('w')
        print('NITRO:', json.dumps(nit))

        # Safety car forzado + tableros SC
        await pg.evaluate('scT = 5')
        await pg.wait_for_timeout(700)
        scs = await pg.evaluate("""() => ({ scT: +scT.toFixed(1),
          chip: document.getElementById('scChip').style.display })""")
        print('SC:', json.dumps(scs))
        await pg.screenshot(path='_lote_sc.png')

        # Replay: sembrar buffer y pulsar botón
        rep = await pg.evaluate("""() => { reBuf = []; for (let i=0;i<200;i++) reBuf.push({t:i*0.1, x:car.x+i*0.3, z:car.z, a:car.a});
          document.getElementById('replayBtn').click(); return {replay: replaying, res: document.getElementById('results').classList.contains('show')} }""")
        print('REPLAY:', json.dumps(rep))
        await pg.wait_for_timeout(2500)
        rep2 = await pg.evaluate("""() => ({ replaying, reI, chip: document.getElementById('reChip').style.display })""")
        print('REPLAY2:', json.dumps(rep2))
        await pg.screenshot(path='_lote_replay.png')
        await pg.keyboard.press('Escape'); await pg.wait_for_timeout(400)

        # Volver al menú -> opciones -> récords y logros
        await pg.evaluate("exitToMenu(); document.getElementById('menu').classList.remove('show');")
        await pg.evaluate("document.getElementById('results').classList.remove('show'); document.getElementById('menu').classList.add('show')")
        await pg.click('#optsBtn'); await pg.wait_for_timeout(500)
        await pg.click('#recBtn'); await pg.wait_for_timeout(400)
        rec = await pg.evaluate("""() => ({ show: document.getElementById('recScr').classList.contains('show'),
          rows: document.getElementById('recList').children.length })""")
        print('RECORDS:', json.dumps(rec))
        await pg.screenshot(path='_lote_rec.png')
        await pg.click('#recBack'); await pg.wait_for_timeout(300)
        await pg.click('#achBtn'); await pg.wait_for_timeout(400)
        ach = await pg.evaluate("""() => ({ show: document.getElementById('achScr').classList.contains('show'),
          rows: document.getElementById('achList').children.length })""")
        print('ACHS:', json.dumps(ach))
        await pg.screenshot(path='_lote_ach.png')
        await pg.click('#achBack')

        # Lobby MP visible en versus
        await pg.click('#vsBack'); await pg.wait_for_timeout(200)
        await pg.evaluate("document.getElementById('opts').classList.remove('show')")
        await pg.click('#versusBtn'); await pg.wait_for_timeout(400)
        lob = await pg.evaluate("""() => ({ code: !!document.getElementById('mpCode'),
          host: !!document.getElementById('mpHostBtn'), join: !!document.getElementById('mpJoinBtn') })""")
        print('LOBBY:', json.dumps(lob))
        await pg.screenshot(path='_lote_lobby.png')

        print('ERRORS:', json.dumps(errors))
        await b.close()

asyncio.run(main())
