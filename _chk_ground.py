from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(channel='chrome', args=['--use-gl=angle'])
    pg = b.new_page(viewport={'width':1280,'height':720})
    errs = []
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.goto('http://localhost:8765/index.html')
    pg.wait_for_timeout(2500)
    pg.evaluate("localStorage.setItem('scgp_tuto','1')")
    # elegir NEON directamente por su tarjeta
    pg.evaluate("[...document.getElementById('circStrip').children].find(c=>c.textContent.includes('NEON'))?.click()")
    pg.wait_for_timeout(400)
    pg.evaluate("document.getElementById('playBtn').click()")
    pg.wait_for_timeout(4200)
    pg.keyboard.down('ArrowUp')
    pg.wait_for_timeout(4500)
    pg.screenshot(path='_g_neon.png')
    pg.keyboard.up('ArrowUp')
    pg.wait_for_timeout(300)
    pg.screenshot(path='_g_neon2.png')
    print('errors:', errs)
    b.close()
