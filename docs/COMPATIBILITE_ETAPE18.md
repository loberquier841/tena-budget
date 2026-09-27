# Compatibilite Etape 18 - 375px / 768px / 1200px+
Appareils verifies code:
- 375px telephone: ResponsiveNav @media max-width 768px translateX(-100%)->0 + overlay + bouton + auto-fit minmax 220px + padding-top 56px + inputs min-width 200 - PASS code
- 768px tablette: desktop 260px fixe + mobile coulissant, grids auto-fit, overflowX auto - PASS code
- 1200px+ ordi: sidebar 260px fixe, main marginLeft 260, grids auto-fit minmax 300px - PASS code
- Tactile: boutons min 44px, inputs min-width 200 - PASS code
- PWA installable: manifest.json display standalone + next-pwa - EXISTS PASS mais NON VERIFIE installation reelle
- Navigation mobile/desktop: menu lateral desktop fixe + mobile coulissant overlay - PASS
Problemes trouves et corriges: 0 ecrans casses, 0 debordement, ResponsiveNav PASS, auto-fit minmax PASS. app/page.tsx et login/page.tsx simples sans grid complexe - pas correctif necessaire.
Preparation Capacitor/Tauri: core pure TS sans DOM, Int centimes, familyId isole, Dexie offline-first compatible Capacitor/Tauri, next-pwa compatible, Auth.js JWT httpOnly compatible, aucune dependance PC personnel.
Etat reel: code verifie 17 ecrans tous responsive, reel appareil 375/768/1200 NON VERIFIE - a tester Chrome DevTools + iPhone/Android reels Etape 19.
