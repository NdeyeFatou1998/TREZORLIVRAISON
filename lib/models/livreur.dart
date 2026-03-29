/// Modèle Livreur — représente le compte livreur connecté.
/// Contient TOUS les champs retournés par le backend (Livreur.java).
class LivreurModel {
  final String id;
  final String prenom;
  final String nom;
  final String email;
  final String phone;
  final String? typeEngin;
  final String statut;
  final bool disponible;
  final bool abonnementActif;
  final String? dateAbonnementExpiration;
  final String? numeroCin;
  final String? photoCinRecto;
  final String? photoCinVerso;
  final String? photoSelfie;
  final String? photoEngin;
  final String? notesAdmin;
  final String? createdAt;
  /// Nombre de jours d'essai accordés par l'admin
  final int joursEssaiAccordes;
  /// Nombre de jours d'essai restants (calculé par le backend)
  final int joursEssaiRestants;
  /// Date de début de la période d'essai
  final String? dateDebutEssai;
  /// Période d'essai active (calculé par le backend)
  final bool periodeEssaiActive;
  /// Peut activer la disponibilité (abonnement actif OU essai actif)
  final bool peutEtreDisponible;

  const LivreurModel({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.email,
    required this.phone,
    this.typeEngin,
    required this.statut,
    required this.disponible,
    required this.abonnementActif,
    this.dateAbonnementExpiration,
    this.numeroCin,
    this.photoCinRecto,
    this.photoCinVerso,
    this.photoSelfie,
    this.photoEngin,
    this.notesAdmin,
    this.createdAt,
    this.joursEssaiAccordes = 0,
    this.joursEssaiRestants = 0,
    this.dateDebutEssai,
    this.periodeEssaiActive = false,
    this.peutEtreDisponible = false,
  });

  factory LivreurModel.fromJson(Map<String, dynamic> json) => LivreurModel(
        id: json['id']?.toString() ?? '',
        prenom: json['prenom']?.toString() ?? '',
        nom: json['nom']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        typeEngin: json['typeEngin']?.toString(),
        statut: json['statut']?.toString() ?? 'EN_ATTENTE_VALIDATION',
        disponible: json['disponible'] as bool? ?? false,
        abonnementActif: json['abonnementActif'] as bool? ?? false,
        dateAbonnementExpiration: json['dateAbonnementExpiration']?.toString(),
        numeroCin: json['numeroCin']?.toString(),
        photoCinRecto: json['photoCinRecto']?.toString(),
        photoCinVerso: json['photoCinVerso']?.toString(),
        photoSelfie: json['photoSelfie']?.toString(),
        photoEngin: json['photoEngin']?.toString(),
        notesAdmin: json['notesAdmin']?.toString(),
        createdAt: json['createdAt']?.toString(),
        joursEssaiAccordes: (json['joursEssaiAccordes'] as num?)?.toInt() ?? 0,
        joursEssaiRestants: (json['joursEssaiRestants'] as num?)?.toInt() ?? 0,
        dateDebutEssai: json['dateDebutEssai']?.toString(),
        periodeEssaiActive: json['periodeEssaiActive'] as bool? ?? false,
        peutEtreDisponible: json['peutEtreDisponible'] as bool? ?? false,
      );

  /// Nom complet du livreur
  String get fullName => '$prenom $nom'.trim();

  /// Vérifie si le compte est validé
  bool get isValide => statut == 'VALIDE';

  /// Copie avec modification de certains champs
  LivreurModel copyWith({bool? disponible, bool? abonnementActif, String? statut,
      bool? peutEtreDisponible, bool? periodeEssaiActive, int? joursEssaiRestants}) => LivreurModel(
        id: id, prenom: prenom, nom: nom, email: email, phone: phone,
        typeEngin: typeEngin, statut: statut ?? this.statut,
        disponible: disponible ?? this.disponible,
        abonnementActif: abonnementActif ?? this.abonnementActif,
        dateAbonnementExpiration: dateAbonnementExpiration,
        numeroCin: numeroCin, photoCinRecto: photoCinRecto,
        photoCinVerso: photoCinVerso, photoSelfie: photoSelfie,
        photoEngin: photoEngin, notesAdmin: notesAdmin,
        createdAt: createdAt,
        joursEssaiAccordes: joursEssaiAccordes,
        joursEssaiRestants: joursEssaiRestants ?? this.joursEssaiRestants,
        dateDebutEssai: dateDebutEssai,
        periodeEssaiActive: periodeEssaiActive ?? this.periodeEssaiActive,
        peutEtreDisponible: peutEtreDisponible ?? this.peutEtreDisponible,
      );
}
