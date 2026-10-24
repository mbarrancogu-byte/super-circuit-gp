// Service worker: actualiza primero por red y guarda copia para offline (PWA)
const CACHE = 'scgp-v399';
const ASSETS = [
  './', 'index.html', 'circuitos.js', 'fondo.jpg', 'fondo2.jpg', 'portada.jpg',
  'fondo_pw.png', 'fondo_card.jpg', 'fondo_manual.jpg', 'f1.png', 'f1sel.png', 'f1_r26.png', 'f1_scarlet.png', 'f1_verde.png', 'f1_amarillo.png', 'f1_negro.png', 'f1_rosa.png', 'f1_naranja.png', 'volante.webp', 'volante_giro.webp', 'volante_fijo.webp', 'cockpit_car.webp', 'stick_dpad.webp', 'fpv_tire.webp', 'logo_gp.webp', 'trofeo.webp', 'logo_shape.js', 'RADIO.mp3', 'three.min.js', 'postprocessing.min.js', 'peerjs.min.js',
  'cockpit.webp', 'icon-192.png', 'icon-512.png', 'manifest.json', 'scar.glb', 'heli.glb', 'gltfloader.js',
  'circ1_day.jpg', 'circ1_dusk.jpg', 'circ1_night.jpg', 'circ2_day.jpg', 'circ2_dusk.jpg', 'circ2_night.jpg',
  'intro1.jpg', 'intro2.jpg', 'intro3.jpg', 'intro4.jpg', 'intro5.jpg',
  'ctl_girar.webp', 'ctl_acelerar.webp', 'ctl_frenar.webp', 'ctl_derrape.webp', 'ctl_nitro.webp', 'ctl_boxes.webp', 'ctl_zoom.webp'
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks =>
    Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  // Network-first: la versión nueva manda; si no hay red, se usa la caché
  e.respondWith(fetch(e.request).then(net => {
    const cp = net.clone();
    caches.open(CACHE).then(c => c.put(e.request, cp));
    return net;
  }).catch(() => caches.match(e.request)));
});
