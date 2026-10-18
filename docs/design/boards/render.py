"""Render every board in docs/design/boards to PNG at 1440px: python3 render.py [names...]
Needs Playwright with Chromium (pip install playwright && playwright install chromium)."""
import asyncio, pathlib, sys
from playwright.async_api import async_playwright

HERE = pathlib.Path(__file__).resolve().parent
names = sys.argv[1:] or sorted(p.stem for p in HERE.glob("*.html"))

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        for n in names:
            pg = await b.new_page(viewport={"width": 1440, "height": 900})
            await pg.goto((HERE / f"{n}.html").as_uri())
            await pg.wait_for_timeout(1500)  # web fonts
            await pg.screenshot(path=str(HERE / f"{n}.png"), full_page=True)
            await pg.close()
            print(n)
        await b.close()

asyncio.run(main())
