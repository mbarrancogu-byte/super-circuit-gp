import sys, json
sys.stdout.reconfigure(encoding='utf-8')
from playwright.sync_api import sync_playwright

URL = 'http://127.0.0.1:52793/index.html'
errors = []

with sync_playwright() as p:
    br = p.chromium.launch(channel='chrome')
    pg = br.new_page(viewport={'width': 1280, 'height': 720})
    pg.on('pageerror', lambda e: errors.append('PAGE: ' + str(e)))
    pg.on('console', lambda m: errors.append('CONS: ' + m.text) if m.type == 'error' else None)
    pg.goto(URL)
    pg.wait_for_timeout(2500)
    pg.evaluate("() => { const s = document.getElementById('splash'); if (s) s.style.display='none'; startStage(1, 77, false, 'champ'); }")
    pg.wait_for_timeout(6500)   # semáforo + salida: los CPU queman rueda al lanzar

    # Cuenta sprites de humo activos durante la salida (los CPU deberían echar humo)
    st1 = pg.evaluate("""() => ({
        raceT, v: cpus.map(c => +c.v.toFixed(1)),
        puffs: dustPool.filter(s => s.visible).length, pool: dustPool.length })""")
    print('launch:', json.dumps(st1))
    pg.screenshot(path='_smoke_launch.png')

    # Forzar lluvia → spray trasero de los CPU
    pg.evaluate("() => { rainAt = 0.01; rainEnd = -1; rain = 0.9; }")
    pg.wait_for_timeout(3000)
    st2 = pg.evaluate("""() => ({
        rain, v: cpus.map(c => +c.v.toFixed(1)),
        puffs: dustPool.filter(s => s.visible).length })""")
    print('rain:', json.dumps(st2))
    pg.screenshot(path='_smoke_rain.png')

    # Motor roto de un CPU → humo negro
    pg.evaluate("() => { cpus[0].dmg = 90; rain = 0; rainAt = -1; rainEnd = -1; }")
    pg.wait_for_timeout(2000)
    st3 = pg.evaluate("() => ({ puffs: dustPool.filter(s => s.visible).length })")
    print('dmg:', json.dumps(st3))
    print('errors:', errors)
    br.close()
