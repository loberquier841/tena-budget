import { APP_NAME, APP_VERSION } from "@tena/shared";

export default function DownloadPage() {
  const windowsArchitectures = ["x64", "ia32"];
  const currentVersion = APP_VERSION || "0.1.0";
  const publishDate = new Date("2024-01-15");

  return (
    <main className="max-w-2xl mx-auto py-12">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-4">
          Télécharger TENΛ Budget pour Windows
        </h1>
        <p className="text-lg text-gray-600">
          Application de gestion budgétaire personnelle hors ligne
        </p>
      </header>

      <section className="bg-gray-50 rounded-lg p-6 mb-8">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Version disponible
        </h2>
        <p className="text-gray-600">
          {currentVersion}
        </p>
        <p className="text-sm text-gray-500 mt-2">
          Publié le {publishDate.toLocaleDateString("fr-FR", {
            year: "numeric",
            month: "long",
            day: "numeric",
          })}
        </p>
      </section>

      <section className="bg-white rounded-lg p-6 mb-8 shadow">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Architectures supportées
        </h2>
        <ul className="space-y-2 text-gray-600 text-sm">
          {windowsArchitectures.map((arch) => (
            <li key={arch}>{
              arch === "x64" && "Processeurs 64 bits (recommandé)"
            } {arch === "ia32" && "Processeurs 32 bits"}
          </li>)
          )}
        </ul>
      </section>

      <section className="bg-white rounded-lg p-6 mb-8 shadow">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Prérequis
        </h2>
        <ul className="space-y-2 text-gray-600 text-sm">
          <li>Windows 10 ou version ultérieure</li>
          <li>Espace disque minimum : 200 Mo</li>
          <li>.NET Framework 4.7.2 ou version ultérieure (inclut dans Windows 10)</li>
          <li>Administrateur requis pour l'installation</li>
        </ul>
      </section>

      <section className="bg-white rounded-lg p-6 mb-8 shadow">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Instructions d'installation
        </h2>
        <ol className="list-decimal pl-5 text-gray-600 text-sm">
          <li>Télécharger l'installeur ci-dessous</li>
          <li>Exécuter le fichier .exe téléchargé</li>
          <li>Suivre les instructions de l'assistant d'installation</li>
          <li>Choisir le dossier d'installation</li>
          <li>Lancer TENΛ Budget depuis le menu Démarrer ou le raccourci créé sur le bureau</li>
        </ol>
      </section>

      <section className="bg-white rounded-lg p-6 mb-8 shadow">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Notes de version et sécurité
        </h2>
        <ul className="space-y-2 text-gray-600 text-sm">
          <li>
            L'application utilise Electron pour l'interface desktop et stocke les données
            localement via IndexedDB (Dexie.js). Aucune donnée n'est envoyée vers des serveurs
            tiers sans votre consentement.
          </li>
          <li>
            L'application est signé sous respect des lignes directrices de sécurité Microsoft.
            Vérifiez l'empreinte SHA-256 après le téléchargement pour vous assurer de l'intégrité
            du fichier.
          </li>
        </ul>
      </section>

      <div className="mt-8">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">
          Téléchargement
        </h2>
        <p className="text-gray-600 mb-4">
          L'installateur n'est pas encore disponible au téléchargement public. Une fois l'installateur
          Build et hébergé, ce bouton deviendra actif.
        </p>
      </div>
    </main>
  );
}