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
        await pg.wait_for_timeout(4500)
        await pg.evaluate("() => { tutoT = 0; el('tuto').style.display='none'; }")
        # acelerar desde parado -> quema de rueda
        await pg.keyboard.down('ArrowUp')
        await pg.wait_for_timeout(1200)
        await pg.screenshot(path='_smk1.png')
        await pg.wait_for_timeout(800)
        await pg.screenshot(path='_smk2.png')
        n = await pg.evaluate("() => dustPool.filter(s => s.visible).length")
        await pg.keyboard.up('ArrowUp')
        print('sprites humo activos:', n)
        print('errors:', errors)
        await b.close()

asyncio.run(main())
