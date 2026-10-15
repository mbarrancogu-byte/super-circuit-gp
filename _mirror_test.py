import asyncio, json
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(channel='chrome', args=['--use-angle=d3d11'])
        pg = await b.new_page(viewport={'width':1280,'height':760})
        errors=[]
        pg.on('pageerror', lambda e: errors.append(str(e)))
        pg.on('console', lambda m: errors.append(m.text) if m.type=='error' else None)
        await pg.goto('http://127.0.0.1:52793/index.html')
        await pg.wait_for_timeout(2000)
        await pg.mouse.click(640,400); await pg.wait_for_timeout(800)
        try: await pg.click('#introExit', timeout=2000)
        except Exception: pass
        await pg.wait_for_timeout(1800)
        await pg.screenshot(path='_mirror_menu.png')
        # ficha técnica
        await pg.click('#car3dInfo', timeout=3000); await pg.wait_for_timeout(2200)
        await pg.screenshot(path='_mirror_ci.png')
        await pg.evaluate("document.getElementById('ciBack').click()"); await pg.wait_for_timeout(600)
        # opciones -> cars3d
        await pg.click('#optsBtn', timeout=3000); await pg.wait_for_timeout(500)
        await pg.click('#cars3dBtn', timeout=3000); await pg.wait_for_timeout(2200)
        await pg.screenshot(path='_mirror_c3d.png')
        await pg.click('#c3dAll', timeout=3000); await pg.wait_for_timeout(3000)
        await pg.screenshot(path='_mirror_c3dall.png')
        print('errors:', json.dumps(errors))
        await b.close()
asyncio.run(main())
