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
        await pg.wait_for_timeout(4000)
        await pg.evaluate("() => { addDamage(48); tutoT=0; el('tuto').style.display='none'; }")
        await pg.wait_for_timeout(200)
        await pg.screenshot(path='_dmg48.png', clip={'x': 0, 'y': 30, 'width': 300, 'height': 380})
        await pg.evaluate("() => addDamage(45)")
        await pg.wait_for_timeout(200)
        await pg.screenshot(path='_dmg93.png', clip={'x': 0, 'y': 30, 'width': 300, 'height': 380})
        print('errors:', errors)
        await b.close()

asyncio.run(main())
