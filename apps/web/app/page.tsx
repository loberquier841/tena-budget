
import { APP_NAME } from '@tena/shared';

export default function Home() {
  return (
    <main>
      <h1>{APP_NAME} — Fondations V1.1</h1>
      <p>Étape 1 active. Offline-ready via Dexie. Auth via Auth.js à venir Étape 2.</p>
      <ul>
        <li>Dexie DB initialisée</li>
        <li>Core permissions chargées</li>
        <li>Import-engine 6 couches prêt (sans UI)</li>
        <li>Banking interfaces seules (pas de provider)</li>
      </ul>
    </main>
  );
}
