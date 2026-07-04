import 'package:flutter/material.dart';

enum DocumentModuleId { devis, carnet, acompte, etat, pickup, historique }

class DocumentModule {
  const DocumentModule({
    required this.id,
    required this.label,
    required this.note,
    required this.icon,
    required this.migrationScope,
  });

  final DocumentModuleId id;
  final String label;
  final String note;
  final IconData icon;
  final List<String> migrationScope;
}

const documentModules = [
  DocumentModule(
    id: DocumentModuleId.devis,
    label: 'Devis',
    note: 'Composer, imprimer, telecharger et envoyer un devis.',
    icon: Icons.edit_document,
    migrationScope: [
      'Stepper 5 etapes',
      'Taille, langue, services, client, final',
      'Catalogue et lignes libres',
      'Generation PDF identique TypeScript',
    ],
  ),
  DocumentModule(
    id: DocumentModuleId.carnet,
    label: "Carnet d'entretien",
    note: 'Creer, completer et imprimer le carnet vehicule.',
    icon: Icons.menu_book_outlined,
    migrationScope: [
      'Client existant ou nouveau client',
      'Vehicule et date de visite',
      'Service realise',
      'PDF carnet premium',
    ],
  ),
  DocumentModule(
    id: DocumentModuleId.acompte,
    label: 'Acompte',
    note: "Recu d'acompte client multilingue.",
    icon: Icons.payments_outlined,
    migrationScope: [
      'FR / NL / EN',
      'Client et vehicule',
      'Services et acompte recu',
      'PDF acompte',
    ],
  ),
  DocumentModule(
    id: DocumentModuleId.etat,
    label: 'Etat des lieux',
    note: 'Inspection vehicule, photos et signatures.',
    icon: Icons.fact_check_outlined,
    migrationScope: [
      'Checklist vehicule',
      'Photos camera / galerie',
      'Signature client obligatoire',
      'PDF inspection',
    ],
  ),
  DocumentModule(
    id: DocumentModuleId.pickup,
    label: 'Service pick-up',
    note: 'Prise en charge, retour et distance.',
    icon: Icons.local_shipping_outlined,
    migrationScope: [
      'Distance avec marge et moyenne',
      'Signature client obligatoire',
      'Signature Car Luxe facultative',
      'PDF pick-up sans signature automatique',
    ],
  ),
  DocumentModule(
    id: DocumentModuleId.historique,
    label: 'Historique',
    note: 'Registre des devis, pick-up, carnets et acomptes.',
    icon: Icons.history_rounded,
    migrationScope: [
      'Filtres par type',
      'Recherche client / vehicule',
      'Reimpression',
      'Pagination',
    ],
  ),
];
