enum CatalogVehicleSize { s, m, l }

class ServicePrice {
  const ServicePrice.fixed(this.value) : bySize = null;
  const ServicePrice.bySize(this.bySize) : value = null;

  final int? value;
  final Map<CatalogVehicleSize, int>? bySize;

  int resolve(CatalogVehicleSize size) {
    if (value != null) return value!;
    return bySize![size]!;
  }

  bool get isFixed => value != null;
}

class ServiceCatalogEntry {
  const ServiceCatalogEntry({
    required this.id,
    required this.label,
    required this.price,
  });

  final String id;
  final String label;
  final ServicePrice price;
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.label,
    required this.services,
  });

  final String id;
  final String label;
  final List<ServiceCatalogEntry> services;
}

const officialServiceCategories = [
  ServiceCategory(
    id: 'lavage',
    label: 'Lavage',
    services: [
      ServiceCatalogEntry(
        id: 'lavage_splendeur',
        label: 'Lavage Splendeur',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 70,
          CatalogVehicleSize.m: 80,
          CatalogVehicleSize.l: 90,
        }),
      ),
      ServiceCatalogEntry(
        id: 'lavage_serenite',
        label: 'Lavage Sérénité',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 90,
          CatalogVehicleSize.m: 100,
          CatalogVehicleSize.l: 120,
        }),
      ),
      ServiceCatalogEntry(
        id: 'lavage_supreme',
        label: 'Lavage Suprême',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 140,
          CatalogVehicleSize.m: 160,
          CatalogVehicleSize.l: 190,
        }),
      ),
      ServiceCatalogEntry(
        id: 'lavage_excellence',
        label: 'Lavage Excellence',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 235,
          CatalogVehicleSize.m: 250,
          CatalogVehicleSize.l: 265,
        }),
      ),
    ],
  ),
  ServiceCategory(
    id: 'reconditionnement',
    label: 'Reconditionnement',
    services: [
      ServiceCatalogEntry(
        id: 'reconditionnement_purete',
        label: 'Pureté',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 350,
          CatalogVehicleSize.m: 420,
          CatalogVehicleSize.l: 490,
        }),
      ),
      ServiceCatalogEntry(
        id: 'reconditionnement_purete_extreme',
        label: 'Pureté Extrême',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 500,
          CatalogVehicleSize.m: 570,
          CatalogVehicleSize.l: 640,
        }),
      ),
      ServiceCatalogEntry(
        id: 'reconditionnement_brillance',
        label: 'Brillance',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 400,
          CatalogVehicleSize.m: 450,
          CatalogVehicleSize.l: 500,
        }),
      ),
      ServiceCatalogEntry(
        id: 'reconditionnement_renaissance',
        label: 'Renaissance',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 690,
          CatalogVehicleSize.m: 790,
          CatalogVehicleSize.l: 990,
        }),
      ),
      ServiceCatalogEntry(
        id: 'reconditionnement_signature',
        label: 'Signature',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 890,
          CatalogVehicleSize.m: 990,
          CatalogVehicleSize.l: 1190,
        }),
      ),
    ],
  ),
  ServiceCategory(
    id: 'polissage',
    label: 'Polissage',
    services: [
      ServiceCatalogEntry(
        id: 'polissage_medium',
        label: 'Polissage Medium',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 350,
          CatalogVehicleSize.m: 400,
          CatalogVehicleSize.l: 450,
        }),
      ),
      ServiceCatalogEntry(
        id: 'polissage_approfondi',
        label: 'Polissage Approfondi',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 700,
          CatalogVehicleSize.m: 800,
          CatalogVehicleSize.l: 900,
        }),
      ),
      ServiceCatalogEntry(
        id: 'polissage_phares',
        label: 'Polissage des phares',
        price: ServicePrice.fixed(120),
      ),
    ],
  ),
  ServiceCategory(
    id: 'ceramique',
    label: 'Céramique',
    services: [
      ServiceCatalogEntry(
        id: 'ceramique_exterieur_3_ans',
        label: 'Céramique Exterieur 3 ans',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 1000,
          CatalogVehicleSize.m: 1200,
          CatalogVehicleSize.l: 1400,
        }),
      ),
      ServiceCatalogEntry(
        id: 'ceramique_exterieur_5_ans',
        label: 'Céramique Exterieur 5 ans',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 1400,
          CatalogVehicleSize.m: 1600,
          CatalogVehicleSize.l: 1800,
        }),
      ),
      ServiceCatalogEntry(
        id: 'ceramique_exterieur_10_ans',
        label: 'Céramique Exterieur 10 ans',
        price: ServicePrice.bySize({
          CatalogVehicleSize.s: 1600,
          CatalogVehicleSize.m: 1800,
          CatalogVehicleSize.l: 2000,
        }),
      ),
      ServiceCatalogEntry(
        id: 'ceramique_interieur',
        label: 'Céramique Interieur',
        price: ServicePrice.fixed(350),
      ),
      ServiceCatalogEntry(
        id: 'ceramique_jantes',
        label: 'Céramique Jantes',
        price: ServicePrice.fixed(200),
      ),
      ServiceCatalogEntry(
        id: 'ceramique_vitres',
        label: 'Céramique Vitres',
        price: ServicePrice.fixed(150),
      ),
      ServiceCatalogEntry(
        id: 'turbo_ceramique',
        label: 'Turbo céramique 12 mois',
        price: ServicePrice.fixed(250),
      ),
    ],
  ),
  ServiceCategory(
    id: 'supplements',
    label: 'Suppléments',
    services: [
      ServiceCatalogEntry(
        id: 'safety_check',
        label: 'Safety check',
        price: ServicePrice.fixed(25),
      ),
      ServiceCatalogEntry(
        id: 'decontamination_siege_bebe',
        label: 'Décontamination siège bébé',
        price: ServicePrice.fixed(50),
      ),
      ServiceCatalogEntry(
        id: 'moteur_haut',
        label: 'Nettoyage compartiment moteur haut',
        price: ServicePrice.fixed(80),
      ),
      ServiceCatalogEntry(
        id: 'moteur_bas',
        label: 'Nettoyage compartiment moteur bas',
        price: ServicePrice.fixed(80),
      ),
      ServiceCatalogEntry(
        id: 'nourrissant_cuir',
        label: 'Soin nourrissant cuir',
        price: ServicePrice.fixed(80),
      ),
      ServiceCatalogEntry(
        id: 'shampoing_volant',
        label: 'Shampoing du volant',
        price: ServicePrice.fixed(50),
      ),
      ServiceCatalogEntry(
        id: 'shampoing_tapis',
        label: 'Shampoing des tapis',
        price: ServicePrice.fixed(80),
      ),
      ServiceCatalogEntry(
        id: 'shampoing_siege',
        label: "Shampoing d'un siège",
        price: ServicePrice.fixed(70),
      ),
      ServiceCatalogEntry(
        id: 'shampoing_5_sieges',
        label: 'Shampoing des 5 sièges',
        price: ServicePrice.fixed(200),
      ),
      ServiceCatalogEntry(
        id: 'protection_hydrophobe_interieur',
        label: 'Protection hydrophobe intérieur',
        price: ServicePrice.fixed(250),
      ),
      ServiceCatalogEntry(
        id: 'decontamination_vapeur_interieur',
        label: 'Décontamination intérieur vapeur',
        price: ServicePrice.fixed(50),
      ),
      ServiceCatalogEntry(
        id: 'expertise_carrosserie',
        label: 'Expertise de la carrosserie',
        price: ServicePrice.fixed(100),
      ),
      ServiceCatalogEntry(
        id: 'nettoyage_ozone',
        label: 'Nettoyage ozone',
        price: ServicePrice.fixed(80),
      ),
      ServiceCatalogEntry(
        id: 'vehicule_courtoisie',
        label: 'Véhicule de courtoisie / jour',
        price: ServicePrice.fixed(50),
      ),
    ],
  ),
];
