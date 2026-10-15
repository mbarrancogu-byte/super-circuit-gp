# -*- coding: utf-8 -*-
"""Verificación: coches a escala del circuito (BUILD 0339)."""
import sys
from playwright.sync_api import sync_playwright

URL = 'http://127.0.0.1:52793/index.html'
errs = []

with sync_playwright() as pw:
    b = pw.chromium.launch(channel='chrome', headless=True,
                           args=['--use-gl=angle', '--enable-webgl'])
    pg = b.new_page(viewport={'width': 1280, 'height': 720})
    pg.on('pageerror', lambda e: errs.append(str(e)))
    pg.on('console', lambda m: errs.append(m.text) if m.type == 'error' else None)
    pg.goto(URL)
    pg.wait_for_timeout(3000)

    # Portada -> intro -> SALTAR -> portada -> Enter -> menú
    pg.mouse.click(640, 400); pg.wait_for_timeout(800)          # portada -> intro
    pg.evaluate("if(typeof introEnd==='function')introEnd(); else document.getElementById('intro').classList.remove('show')")
    pg.wait_for_timeout(600)
    pg.evaluate("document.getElementById('splash').classList.add('hide')"); pg.wait_for_timeout(800)        # portada -> menú

    # Lanzar carrera
    pg.evaluate("document.getElementById('playBtn').click()")
    pg.wait_for_timeout(2500)
    pg.evaluate("if(typeof playing!=='undefined') playing=true")

    info = pg.evaluate("""() => {
      const m = carGrp && carGrp.userData && carGrp.userData.r26;
      const b = new THREE.Box3().setFromObject(m || carGrp);
      return { playing,
        grpScale: carGrp ? carGrp.scale.x : -1, glb: !!m,
        carLen: +(Math.max(b.max.z-b.min.z, b.max.x-b.min.x)).toFixed(2),
        carW:   +(Math.min(b.max.z-b.min.z, b.max.x-b.min.x)).toFixed(2),
        hw: trackHW ? +trackHW[0].toFixed(2) : 10,
        cpus: cpus.length };
    }""")
    print('INFO:', info)

    pg.evaluate("inGas=1"); pg.wait_for_timeout(2500)
    pg.evaluate("el('wheelImg').style.opacity='1'")
    pg.wait_for_timeout(300)
    pg.screenshot(path='_wheel_shadow.png', clip={'x':300,'y':380,'width':680,'height':340})
    pg.evaluate("inGas=0"); pg.wait_for_timeout(300)

    print('errors:', errs[:6] if errs else '[]')
    b.close()
