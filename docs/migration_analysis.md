# Migration TypeScript vers Flutter - Car Luxe Cleaning

## Architecture TypeScript observee

- Framework: React 19 + Vite + TypeScript.
- UI: Tailwind CSS, CSS global, lucide-react, motion/react.
- State: Zustand pour navigation, theme, auth locale et editions texte.
- Donnees locales: Dexie/IndexedDB (`CarLuxeCleaningDB`).
- Backend: Express dans `server.ts`.
- Endpoints critiques:
  - `GET /api/health`
  - `GET /api/gemini/status`
  - `POST /api/gemini`
  - `GET /api/geocode`
  - `GET /api/route-distance`
  - `GET /api/autoref/*`
  - `GET /api/cbe/search`
  - `GET /api/cbe/company/:vatOrCbeNumber`
  - `GET /api/vat/lookup`
  - `POST /api/generate-pdf`
- PDF: `jspdf`, `pdf-lib`, `@pdf-lib/fontkit`, helpers dans `src/lib/pdfTemplate.ts`, `src/lib/carnetPdf.ts`, `src/lib/pdfPrint.ts`.
- IA: Gemini via backend Express, schema strict `AssistantResponse`, photos en base64.
- Import Excel: donnees abonnements deja normalisees dans `src/data/subscriptionExcelImport.ts`.
- Auth: code local simple via Zustand, pas encore token backend.
- Pages principales:
  - Composer mon panier
  - Documents
  - Clients
  - CRM / Abonnements
  - Assistant IA
  - Packages
  - Reglages
  - Corbeille

## Strategie de migration

La migration Flutter est separee du projet web dans `car_luxe_cleaning_flutter`.
Le projet TypeScript reste intact et sert de reference fonctionnelle.

Phases recommandees:

1. Socle Flutter: theme, navigation, responsive tablette/mobile.
2. Modeles Dart: clients, vehicules, abonnements, visites, assistant.
3. Couche API: Dio + repositories.
4. Migration CRM Abonnements.
5. Migration Assistant IA connectee au backend Gemini existant.
6. Migration Clients/Vehicules et formulaires BCE/Autoref.
7. Migration PDF avec `pdf` + `printing` + `signature`.
8. Persistance mobile: SQLite/local database ou backend selon decision produit.
9. Tests tablette/iOS/Android et durcissement offline/error states.

## Etat actuel Flutter

- Theme premium monochrome cree dans `lib/app/theme.dart`.
- Navigation responsive creee avec `go_router`.
- Layout tablette avec navigation laterale, mobile avec bottom navigation.
- Navigation principale alignee sur l'application React:
  - Composer;
  - Documents;
  - Clients;
  - CRM;
  - Assistant IA.
- Page Composer migree avec:
  - catalogue officiel issu de `src/data/serviceCatalog.ts`;
  - tailles S / M / L;
  - categories et prestations;
  - panier et total actuel.
- Page Documents ajoutee avec les six modules metier:
  - Devis;
  - Carnet d'entretien;
  - Acompte;
  - Etat des lieux;
  - Service pick-up;
  - Historique.
- Builders Documents migres en Flutter avec:
  - parcours devis en 5 etapes;
  - carnet en 4 etapes;
  - recu d'acompte;
  - service pick-up avec formule distance moyenne/median;
  - etat des lieux avec checklist, photos et signature client;
  - generation PDF locale via `pdf` + `printing`.
- Page Clients migree avec:
  - recherche globale;
  - filtres vehicule / plaque / type;
  - liste premium separee par lignes grises;
  - contacts et vehicules.
- Page Abonnements migree avec:
  - statistiques;
  - vues Liste / 12 mois / Prochains / Renouvel.;
  - badges plan/statut;
  - progression des passages;
  - action Passage;
  - source locale issue de l'Excel normalise.
- Page Assistant IA migree avec:
  - conversation;
  - suggestions;
  - camera / galerie;
  - endpoint `/api/gemini`;
  - etats erreur/loading.
- Services TODO propres:
  - PDF;
  - auth;
  - clients;
  - rendez-vous.

## Points a brancher ensuite

- Remplacer `LocalSubscriptionRepository` par une vraie persistance mobile ou API.
- Raffiner les PDF Flutter pour atteindre une exactitude visuelle totale avec les PDF TypeScript.
- Persister l'historique documents au lieu de le garder comme registre de modules actifs.
- Porter les formulaires Clients/Vehicules, BCE, Autoref et suggestions vehicules.
- Remplacer les actions TODO par les vrais flux create/edit/delete.
- Ajouter les tests widget et integration tablette.
