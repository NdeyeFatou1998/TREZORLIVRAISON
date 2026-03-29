/// Modèle Livraison — représente une livraison en cours ou terminée.
class LivraisonModel {
  final String id;
  final String commandeId;
  final String typeLivraison;
  final String statut;
  final String? adresseCollecte;
  final String? adresseLivraison;
  final double? latVendeur;
  final double? lonVendeur;
  final double? latAcheteur;
  final double? lonAcheteur;
  final double? latLivreur;
  final double? lonLivreur;
  final String? articleTitre;
  final String? qrCodeToken;
  final double? montantLivraison;
  final String? dateLivraison;
  final String createdAt;
  final Map<String, dynamic>? acheteur;
  final Map<String, dynamic>? vendeur;
  final Map<String, dynamic>? livreur;

  const LivraisonModel({
    required this.id,
    required this.commandeId,
    required this.typeLivraison,
    required this.statut,
    this.adresseCollecte,
    this.adresseLivraison,
    this.latVendeur,
    this.lonVendeur,
    this.latAcheteur,
    this.lonAcheteur,
    this.latLivreur,
    this.lonLivreur,
    this.articleTitre,
    this.qrCodeToken,
    this.montantLivraison,
    this.dateLivraison,
    required this.createdAt,
    this.acheteur,
    this.vendeur,
    this.livreur,
  });

  factory LivraisonModel.fromJson(Map<String, dynamic> json) => LivraisonModel(
        id: json['id']?.toString() ?? '',
        commandeId: json['commandeId']?.toString() ?? '',
        typeLivraison: json['typeLivraison']?.toString() ?? 'DIRECTE',
        statut: json['statut']?.toString() ?? 'CREE',
        adresseCollecte: json['adresseCollecte']?.toString(),
        adresseLivraison: json['adresseLivraison']?.toString(),
        latVendeur: (json['latVendeur'] as num?)?.toDouble(),
        lonVendeur: (json['lonVendeur'] as num?)?.toDouble(),
        latAcheteur: (json['latAcheteur'] as num?)?.toDouble(),
        lonAcheteur: (json['lonAcheteur'] as num?)?.toDouble(),
        latLivreur: (json['latLivreur'] as num?)?.toDouble(),
        lonLivreur: (json['lonLivreur'] as num?)?.toDouble(),
        articleTitre: json['articleTitre']?.toString(),
        qrCodeToken: json['qrCodeToken']?.toString(),
        montantLivraison: (json['montantLivraison'] as num?)?.toDouble(),
        dateLivraison: json['dateLivraison']?.toString(),
        createdAt: json['createdAt']?.toString() ?? '',
        acheteur: json['acheteur'] as Map<String, dynamic>?,
        vendeur: json['vendeur'] as Map<String, dynamic>?,
        livreur: json['livreur'] as Map<String, dynamic>?,
      );

  /// Étiquette lisible du statut
  String get statutLabel {
    switch (statut) {
      case 'CREE': return 'En attente de livreur';
      case 'ACCEPTEE': return 'Livreur assigné';
      case 'EN_ROUTE_COLLECTE': return 'En route vers le vendeur';
      case 'COLLECTE': return 'Colis récupéré';
      case 'EN_ROUTE_LIVRAISON': return 'En route vers l\'acheteur';
      case 'LIVREE': return 'Livrée ✅';
      case 'ECHOUEE': return 'Échec livraison';
      case 'ANNULEE': return 'Annulée';
      default: return statut;
    }
  }

  bool get isActive => ['ACCEPTEE', 'EN_ROUTE_COLLECTE', 'COLLECTE', 'EN_ROUTE_LIVRAISON'].contains(statut);
  bool get isTerminee => statut == 'LIVREE' || statut == 'ECHOUEE' || statut == 'ANNULEE';
}
