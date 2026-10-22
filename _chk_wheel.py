from playwright.sync_api import sync_playwright
errs=[]
with sync_playwright() as p:
    b=p.chromium.launch(channel='chrome')
    pg=b.new_page(viewport={'width':1400,'height':800})
    pg.on('pageerror',lambda e:errs.append(str(e)))
    pg.on('console',lambda m:errs.append('console:'+m.text) if m.type=='error' else None)
    pg.goto('http://127.0.0.1:52793/index.html',wait_until='domcontentloaded')
    pg.wait_for_timeout(4500)
    pg.evaluate("""()=>{introEnd();el('splash').style.display='none';
      el('menu').classList.remove('show');OPTS.tod='day';}""")
    pg.evaluate("startStage(1, 12345, false, 'vs')")
    pg.wait_for_timeout(2500)
    # acercar cámara para que aparezca el volante
    pg.evaluate("camZoom=0")
    pg.wait_for_timeout(800)
    pg.screenshot(path=r'E:\PROYECTOS\ADVANCED F1\_wheel_new.png')
    # recorte del volante
    box=pg.evaluate("""()=>{const r=document.getElementById('wheelWrap').getBoundingClientRect();
      return {x:r.x,y:r.y,w:r.width,h:r.height,op:el('wheelImg').style.opacity};}""")
    print('wheelbox',box)
    print('BUILD',pg.evaluate('BUILD_NO'))
    print('ERRORS',errs)
    b.close()
