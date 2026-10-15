from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(channel='chrome', args=['--use-gl=angle'])
    pg = b.new_page(viewport={'width':1280,'height':720})
    pg.goto('http://localhost:8765/index.html')
    pg.wait_for_timeout(2500)
    pg.mouse.click(640, 400)
    pg.wait_for_timeout(900)
    pg.evaluate("document.getElementById('optsBtn')?.click()")
    pg.wait_for_timeout(600)
    pg.evaluate("document.getElementById('cars3dBtn')?.click()")
    pg.wait_for_timeout(2500)
    pg.evaluate("document.getElementById('c3dAll').click()")
    pg.wait_for_timeout(3500)
    info = pg.evaluate("""(() => {
      const out = [];
      const T = THREE;
      c3d.allGrp.children.forEach((w, i) => {
        const bb = new T.Box3(); bb.setFromObject(w);
        const s = bb.getSize(new T.Vector3());
        out.push(i + ': scale=' + w.scale.x.toFixed(2) + ' size=' + s.x.toFixed(1) + 'x' + s.y.toFixed(1) + 'x' + s.z.toFixed(1));
      });
      return out;
    })()""")
    print('\n'.join(info))
    b.close()
