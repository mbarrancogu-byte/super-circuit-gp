from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(channel='chrome', args=['--use-gl=angle'])
    pg = b.new_page(viewport={'width':1280,'height':720})
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('http://localhost:8765/index.html')
    pg.wait_for_timeout(2500)
    pg.evaluate("localStorage.setItem('scgp_tuto','1')")
    pg.mouse.click(640, 400)                      # descartar el splash
    pg.wait_for_timeout(900)
    pg.evaluate("[...document.getElementById('circStrip').children].find(c=>c.textContent.includes('NEON'))?.click()")
    pg.wait_for_timeout(400)
    pg.evaluate("document.getElementById('playBtn').click()")
    pg.wait_for_timeout(4200)
    n = pg.evaluate("oilSpots.length")
    if n:
        pg.evaluate("""(() => {
          const s = oilSpots[0];
          car.x = s.x; car.z = s.z + 8; car.vx = 0; car.vz = 0;
        })()""")
        pg.wait_for_timeout(700)
        pg.screenshot(path='_g_oil.png')
    print('oil:', n, '| errors:', errs)
    b.close()
