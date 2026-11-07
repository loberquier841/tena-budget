#!/usr/bin/env python3
"""
TENΛ Budget — Serveur Local Souverain & Lanceur Multiplateforme
0 € de frais • Aucun serveur distant • 100% Hors-ligne
"""

import http.server
import socketserver
import os
import sys
import webbrowser
import subprocess

PORT = 8080
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STANDALONE_DIR = os.path.join(BASE_DIR, "standalone")

class TenaHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STANDALONE_DIR, **kwargs)

    def do_GET(self):
        # Routage vers l'application
        if self.path == "/app" or self.path == "/app/":
            self.path = "/app.html"
        elif self.path == "/" or self.path == "":
            self.path = "/index.html"
        return super().do_GET()

def start_server():
    socketserver.TCPServer.allow_reuse_address = True
    try:
        with socketserver.TCPServer(("", PORT), TenaHandler) as httpd:
            site_url = f"http://localhost:{PORT}"
            app_url = f"http://localhost:{PORT}/app"

            print("=" * 65)
            print("  🌟 TENΛ BUDGET — ÉCOSYSTÈME LOCAL SOUVERAIN (0 € / MOIS)")
            print("=" * 65)
            print(f"  🌐 Site officiel de présentation :  {site_url}")
            print(f"  📱 Application financière active  :  {app_url}")
            print("-" * 65)
            print("  🔒 Stockage : 100% Local sur votre Mac (Chiffré)")
            print("  📡 Réseau   : Aucun serveur distant, zéro collecte")
            print("=" * 65)
            print("  Ouverture automatique dans votre navigateur…")
            print("  Appuyez sur Ctrl+C dans ce terminal pour arrêter le serveur.")
            print("=" * 65)

            # Ouverture du navigateur macOS
            try:
                subprocess.Popen(["open", site_url])
            except Exception:
                webbrowser.open(site_url)

            httpd.serve_forever()
    except OSError as e:
        if e.errno == 48: # Port déjà utilisé
            print(f"Le port {PORT} est déjà occupé. Tentative sur le port 8081...")
            # Relance sur 8081
            with socketserver.TCPServer(("", 8081), TenaHandler) as httpd:
                print(f"  🌐 Site : http://localhost:8081")
                print(f"  📱 App  : http://localhost:8081/app")
                subprocess.Popen(["open", "http://localhost:8081"])
                httpd.serve_forever()
        else:
            raise e

if __name__ == "__main__":
    start_server()
