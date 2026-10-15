from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(channel='chrome', args=['--use-gl=angle'])
    pg = b.new_page(viewport={'width':1280,'height':720})
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('http://localhost:8765/index.html')
    pg.wait_for_timeout(2500)
    pg.mouse.click(640, 400)
    pg.wait_for_timeout(900)
    # abrir opciones -> CARS 3D
    pg.evaluate("document.getElementById('optsBtn')?.click()")
    pg.wait_for_timeout(600)
    pg.evaluate("document.getElementById('cars3dBtn')?.click()")
    pg.wait_for_timeout(2500)
    pg.screenshot(path='_g_c3d1.png')
    # pulsar TODOS
    pg.evaluate("document.getElementById('c3dAll').click()")
    pg.wait_for_timeout(3500)
    pg.screenshot(path='_g_c3d2.png')
    print('name:', pg.evaluate("document.getElementById('c3dName').textContent"), '| errors:', errs)
    b.close()
