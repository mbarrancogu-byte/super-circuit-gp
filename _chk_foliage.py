import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(channel='chrome')
        pg = await b.new_page(viewport={'width': 800, 'height': 600})
        errors = []
        pg.on('pageerror', lambda e: errors.append(str(e)))
        await pg.goto('http://localhost:8765/')
        await pg.wait_for_timeout(2500)
        # dibuja el tile de follaje repetido 2x2 en un canvas visible
        await pg.evaluate("""() => {
            const tx = makeFoliageTex();
            const img = tx.image;
            const cv = document.createElement('canvas');
            cv.width = cv.height = 512;
            const t = cv.getContext('2d');
            for (let x = 0; x < 2; x++) for (let y = 0; y < 2; y++)
                t.drawImage(img, x * 256, y * 256);
            cv.style.cssText = 'position:fixed;inset:0;z-index:99999';
            document.body.appendChild(cv);
        }""")
        await pg.wait_for_timeout(300)
        await pg.screenshot(path='_foliage.png')
        print('errors:', errors)
        await b.close()

asyncio.run(main())
