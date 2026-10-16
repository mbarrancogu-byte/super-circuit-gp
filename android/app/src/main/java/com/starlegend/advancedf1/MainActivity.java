package com.starlegend.advancedf1;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.util.Base64;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.UUID;

// WebView a pantalla completa que ejecuta el juego (index.html) desde assets.
// Expone window.BT: duelos Bluetooth directos móvil-móvil (RFCOMM) para el modo
// multijugador del juego — líneas JSON separadas por '\n' en ambos sentidos.
public class MainActivity extends Activity {
    private WebView web;
    private BtBridge bt;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        web = new WebView(this);
        WebView.setWebContentsDebuggingEnabled(true);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(true);
        // Texturas (logo_gp.webp, tex_r26/*, fotos aéreas) cargadas desde
        // file://android_asset/ se suben a WebGL — sin esto Chrome las marca
        // como cross-origin y texImage2D las rechaza (escudo/coches en blanco)
        s.setAllowUniversalAccessFromFileURLs(true);
        web.setWebViewClient(new WebViewClient());

        bt = new BtBridge();
        web.addJavascriptInterface(bt, "BT");

        // Permisos de Bluetooth (Android 12+ piden en tiempo de ejecución; en
        // versiones antiguas el descubrimiento requiere localización)
        if (Build.VERSION.SDK_INT >= 31) {
            requestPermissions(new String[]{
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE}, 7);
        } else if (Build.VERSION.SDK_INT >= 23) {
            requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, 7);
        }

        web.loadUrl("file:///android_asset/index.html");
        setContentView(web);
        hideSystemUi();
    }

    private void hideSystemUi() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) hideSystemUi();
    }

    // Al girar el móvil (la actividad sobrevive por configChanges) el sistema
    // puede restaurar las barras — las volvemos a ocultar
    @Override
    public void onConfigurationChanged(android.content.res.Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        hideSystemUi();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (web != null) web.onResume();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (web != null) web.onPause();
    }

    @Override
    protected void onDestroy() {
        if (bt != null) bt.stopAll();
        super.onDestroy();
    }

    // ================= Puente Bluetooth RFCOMM =================
    class BtBridge {
        private static final String SVC = "AdvancedF1-Duel";
        private static final UUID SVC_UUID =
            UUID.fromString("b4f4a1d0-9f1a-4b7a-8a1a-2f0f1a2b3c4d");
        private final BluetoothAdapter ad = BluetoothAdapter.getDefaultAdapter();
        private BluetoothSocket sock;
        private OutputStream out;
        private Thread acceptT, readT;
        private BroadcastReceiver rx;

        private void js(String code) {
            runOnUiThread(() -> { if (web != null) web.evaluateJavascript(code, null); });
        }

        // Escucha conexiones entrantes (CREAR SALA)
        @JavascriptInterface
        public void host() {
            stopConn();
            if (ad == null) { js("onBtConn(false)"); return; }
            try { if (!ad.isEnabled()) ad.enable(); } catch (Exception ignored) {}
            acceptT = new Thread(() -> {
                try {
                    BluetoothServerSocket srv =
                        ad.listenUsingInsecureRfcommWithServiceRecord(SVC, SVC_UUID);
                    BluetoothSocket s2 = srv.accept(120000);
                    srv.close();
                    if (s2 != null) connected(s2);
                    else js("onBtConn(false)");
                } catch (Exception e) { js("onBtConn(false)"); }
            });
            acceptT.start();
        }

        // Descubre dispositivos cercanos (BUSCAR RIVAL)
        @JavascriptInterface
        public void scan() {
            if (ad == null) return;
            try { if (!ad.isEnabled()) ad.enable(); } catch (Exception ignored) {}
            try { if (rx != null) unregisterReceiver(rx); } catch (Exception ignored) {}
            rx = new BroadcastReceiver() {
                public void onReceive(Context c, Intent i) {
                    BluetoothDevice d = i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                    if (d == null) return;
                    try {
                        String n = d.getName() == null ? "?" : d.getName().replace("'", " ");
                        js("onBtFound('" + d.getAddress() + "','" + n + "')");
                    } catch (Exception ignored) {}
                }
            };
            registerReceiver(rx, new IntentFilter(BluetoothDevice.ACTION_FOUND));
            // Los ya vinculados aparecen al instante (cero espera si es tu amigo habitual)
            try {
                for (BluetoothDevice d : ad.getBondedDevices()) {
                    String n = d.getName() == null ? "?" : d.getName().replace("'", " ");
                    js("onBtFound('" + d.getAddress() + "','" + n + "')");
                }
            } catch (Exception ignored) {}
            try { ad.startDiscovery(); } catch (Exception ignored) {}
        }

        // Conecta con la sala del rival (toca su nombre en la lista)
        @JavascriptInterface
        public void join(String addr) {
            if (ad == null) return;
            stopConn();
            new Thread(() -> {
                try {
                    ad.cancelDiscovery();
                    BluetoothSocket s2 = ad.getRemoteDevice(addr)
                        .createInsecureRfcommSocketToServiceRecord(SVC_UUID);
                    s2.connect();
                    connected(s2);
                } catch (Exception e) { js("onBtConn(false)"); }
            }).start();
        }

        // Envía una línea JSON (el juego ya la serializa)
        @JavascriptInterface
        public void send(String s2) {
            try {
                if (out != null) { out.write((s2 + "\n").getBytes("UTF-8")); out.flush(); }
            } catch (Exception ignored) {}
        }

        @JavascriptInterface
        public void close() { stopAll(); }

        private void connected(BluetoothSocket s2) {
            try { out = s2.getOutputStream(); } catch (Exception ignored) {}
            js("onBtConn(true)");
            readT = new Thread(() -> {
                try {
                    InputStream in = s2.getInputStream();
                    ByteArrayOutputStream buf = new ByteArrayOutputStream();
                    byte[] tmp = new byte[1024];
                    int n;
                    while ((n = in.read(tmp)) >= 0) {
                        buf.write(tmp, 0, n);
                        String all = buf.toString("UTF-8");
                        int k;
                        while ((k = all.indexOf('\n')) >= 0) {
                            String line = all.substring(0, k);
                            all = all.substring(k + 1);
                            js("onBtData('" + Base64.encodeToString(
                                line.getBytes("UTF-8"), Base64.NO_WRAP) + "')");
                        }
                        buf.reset(); buf.write(all.getBytes("UTF-8"));
                    }
                } catch (Exception ignored) {}
                js("onBtClosed()");
            });
            readT.start();
        }

        private void stopConn() {
            try { if (sock != null) sock.close(); } catch (Exception ignored) {}
            sock = null; out = null;
        }

        void stopAll() {
            stopConn();
            try { if (acceptT != null) acceptT.interrupt(); } catch (Exception ignored) {}
            try { if (ad != null) ad.cancelDiscovery(); } catch (Exception ignored) {}
            try { if (rx != null) unregisterReceiver(rx); } catch (Exception ignored) {}
            rx = null;
        }
    }
}
