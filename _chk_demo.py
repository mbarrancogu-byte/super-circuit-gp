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
            startStage(1, 777, false, 'demo');
        }""")
        await pg.wait_for_timeout(4500)
        chip = await pg.evaluate("() => el('stageChip').textContent")
        name = await pg.evaluate("() => circAt(stage).name")
        hasimg = await pg.evaluate("() => !!circAt(stage).img")
        await pg.evaluate("() => { tutoT = 0; el('tuto').style.display='none'; }")
        await pg.wait_for_timeout(300)
        await pg.screenshot(path='_demo.png')
        print('chip:', chip, '| circuito:', name, '| sin img (neon):', hasimg == False)
        print('errors:', errors)
        await b.close()

asyncio.run(main())
