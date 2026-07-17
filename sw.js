const CACHE_NAME = "punto-burger-v3";
const APP_SHELL = [
  "./",
  "./index.html",
  "./manifest.json",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-512-maskable.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);

  // CRÍTICO: nunca interceptar ni cachear peticiones que no sean del propio
  // sitio (Supabase, CDNs de fuentes/librerías, etc.). Esas siempre deben
  // viajar a la red — si no, la app queda "congelada" mostrando datos viejos.
  if (url.origin !== self.location.origin) {
    return;
  }

  const isAppShellFile = APP_SHELL.some((path) => {
    const cleanPath = path.replace("./", "/");
    return url.pathname === cleanPath || url.pathname.endsWith(cleanPath);
  });
  if (!isAppShellFile) {
    return; // deja pasar sin cachear (ej: kitchen.html, otras páginas nuevas)
  }

  const isHTML = req.mode === "navigate" || url.pathname.endsWith("index.html") || url.pathname.endsWith("/");

  if (isHTML) {
    // NETWORK-FIRST para el HTML: así cada actualización se ve al instante,
    // sin depender de que el usuario borre caché o reinstale la app.
    event.respondWith(
      fetch(req)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
          return response;
        })
        .catch(() => caches.match(req).then((cached) => cached || caches.match("./index.html")))
    );
    return;
  }

  // CACHE-FIRST para íconos y manifest: casi nunca cambian, y así
  // funcionan sin conexión.
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(req, copy));
          return response;
        })
        .catch(() => caches.match("./index.html"));
    })
  );
});
