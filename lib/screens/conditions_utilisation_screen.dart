import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConditionsUtilisationScreen extends StatefulWidget {
  const ConditionsUtilisationScreen({super.key});

  @override
  State<ConditionsUtilisationScreen> createState() => _ConditionsUtilisationScreenState();
}

class _ConditionsUtilisationScreenState extends State<ConditionsUtilisationScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Conditions d\'utilisation'),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      'Derniere mise a jour: 13 avril 2026\n\n'
                      'Le present document constitue les Conditions Generales d\'Utilisation et de Services de la plateforme TREZOR. '
                      'Il regit l\'acces aux services numeriques, notamment les tontines, le paiement comptant, le paiement par tranches, '
                      'la livraison, la messagerie, les systemes de verification, les mecanismes de confiance, les obligations de conduite '
                      'et les voies de recours. Toute utilisation de la plateforme implique lecture, comprehension et acceptation integrale '
                      'de ces dispositions. Le texte doit etre interprete dans son ensemble, chaque clause se combinant avec les autres '
                      'pour former une architecture de protection juridique complete, tant pour les utilisateurs que pour l\'editeur de la '
                      'plateforme. L\'utilisateur reconnait egalement que la securite economique de l\'ecosysteme repose sur la discipline '
                      'contractuelle de chacun, la bonne foi des declarations, la tracabilite des paiements, la preuve des livraisons et le '
                      'respect strict des echanges dans les espaces de communication.',
                      style: TextStyle(fontSize: 13, color: text, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: '1. Objet, portee et valeur contractuelle',
                    content:
                        'TREZOR fournit une infrastructure technique de mise en relation, de gestion de communautes, de facilitation de paiements '
                        'et de suivi d\'engagements contractuels entre utilisateurs. Les presentes clauses forment un contrat opposable entre '
                        'l\'utilisateur et l\'editeur de la plateforme. Elles s\'appliquent a tout utilisateur, organisateur, participant, '
                        'vendeur, acheteur, livreur, assistant, representant, ou toute personne agissant pour son compte.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '2. Eligibilite, inscription et sincerite des informations',
                    content:
                        'L\'utilisateur declare disposer de la capacite juridique necessaire. Il s\'engage a fournir des informations exactes, '
                        'a jour et completes. Toute usurpation d\'identite, fausse declaration, dissimulation, usage de documents falsifies, '
                        'ou manoeuvre de contournement peut entrainer suspension immediate, annulation de transactions, conservation de traces '
                        'de preuve, signalement aux autorites competentes et, le cas echeant, action judiciaire.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '3. Verification d\'identite, justificatifs et confiance',
                    content:
                        'TREZOR peut exiger des procedures KYC, des justificatifs de revenu, des documents de domicile, des preuves d\'activite '
                        'ou tout document complementaire necessaire a la securite de l\'ecosysteme. Le refus de cooperer peut limiter '
                        'l\'acces a certains services. Les utilisateurs admettent que la plateforme favorise l\'acceptation des demandes '
                        'par des membres que l\'organisateur estime dignes de confiance, dans le respect de la loi, des regles de non-fraude '
                        'et de non-discrimination. La decision d\'acceptation d\'une participation demeure encadree par les regles internes '
                        'de la tontine et les exigences de securite de la plateforme.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '4. Regles generales des tontines',
                    content:
                        'Toute tontine est regie par ses parametres publies: periodicite, montant, nombre de membres, modalites de tirage, '
                        'criteres d\'admission, obligations de cotisation, sanctions en cas de retard. L\'organisateur s\'engage a decrire '
                        'avec loyaute les regles de fonctionnement. Les participants s\'obligent a payer dans les delais. Tout retard peut '
                        'donner lieu a suspension de privileges, sanctions internes, exclusion, ou autres mesures prevues par les regles. '
                        'Les echanges dans le chat sont probants en cas de litige.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '5. Paiement comptant et paiement par tranches',
                    content:
                        'Pour le paiement comptant, l\'acheteur est tenu de regler immediatement la totalite du prix affiche, frais applicables inclus. '
                        'Pour le paiement par tranches, l\'acheteur accepte un echeancier ferme: dates d\'echeance, montants previsionnels, '
                        'regles de retard, consequences d\'impayes. Tout defaut de paiement peut entrainer limitation de compte, suspension de commandes, '
                        'resiliation du plan de paiement, exigibilite immediate de tout solde restant, et mesures de recouvrement autorisees par la loi.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '6. Livraison, reception et risques logistiques',
                    content:
                        'Les regles de livraison precisent les obligations de l\'acheteur, du vendeur et du livreur: exactitude de l\'adresse, '
                        'presence a la reception, delais de remise, verification du colis, confirmation de reception, reserves eventuelles. '
                        'En cas d\'adresse erronee, d\'absence repetee, de refus abusif ou de comportement menaçant, des frais additionnels '
                        'peuvent etre appliques dans les limites legales. L\'utilisateur reconnait que la logistique peut etre affectee par '
                        'des causes externes (meteo, circulation, force majeure, indisponibilite technique).',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '7. Interdictions strictes et lutte contre la fraude',
                    content:
                        'Sont strictement interdits: blanchiment, financement illicite, fraude documentaire, double paiement malveillant, '
                        'chargeback abusif, manipulation de preuves, extorsion, harcelement, menaces, collusion, faux comptes, scripts '
                        'd\'automatisation non autorises, extraction non permise de donnees, denigrement diffamatoire et toute violation '
                        'des lois applicables. TREZOR se reserve le droit de bloquer, enqueter, conserver les journaux, cooperer avec les '
                        'autorites et poursuivre tout auteur de manquement grave.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '8. Responsabilites, garanties et limites',
                    content:
                        'TREZOR agit en qualite de plateforme technologique. Sauf disposition legale imperative contraire, la responsabilite '
                        'de TREZOR est limitee aux dommages directs, previsibles et prouvees, dans la limite des plafonds legaux ou contractuels '
                        'admissibles. Les utilisateurs demeurent responsables de leurs engagements, declarations, paiements, livraisons, '
                        'communications et contenus. Aucune disposition ne prive l\'utilisateur de ses droits legaux d\'ordre public.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '9. Suspension, restriction et cloture de compte',
                    content:
                        'En cas de risque, incoherence documentaire, signalement credible, incident de securite ou non-respect des presentes '
                        'conditions, TREZOR peut suspendre temporairement l\'acces, restreindre certaines fonctionnalites, demander des '
                        'elements justificatifs, ou proceder a la cloture definitive du compte selon la gravite. Les obligations financieres '
                        'anterieures restent dues et exigibles.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '10. Donnees personnelles, preuves et audit',
                    content:
                        'Les donnees sont traitees conformement aux regles applicables de protection des donnees. Les journaux techniques, '
                        'horodatages, confirmations de paiement, traces de livraison et echanges de messagerie peuvent etre utilises pour '
                        'securiser la plateforme, prevenir les abus, instruire un litige et satisfaire aux obligations legales.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '11. Reglement des litiges',
                    content:
                        'En cas de desaccord, les parties privilegient d\'abord une resolution amiable via les outils de support de la plateforme. '
                        'A defaut, le litige est soumis aux juridictions competentes selon la loi applicable et les regles de competence '
                        'territoriale. Les preuves numeriques de la plateforme peuvent etre produites dans les limites du droit de la preuve.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '12. Clauses finales',
                    content:
                        'TREZOR peut mettre a jour les presentes conditions pour tenir compte des evolutions legales, techniques et operationnelles. '
                        'La poursuite de l\'utilisation apres mise a jour vaut acceptation des nouvelles clauses. Si une clause etait declaree nulle, '
                        'les autres demeurent pleinement applicables. Pour une protection juridique maximale, il est recommande de consulter '
                        'un conseil juridique independant pour les cas sensibles ou complexes.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '13. Regles detaillees de paiement et irrevocabilite operationnelle',
                    content:
                        'En validant un paiement, l\'utilisateur reconnait avoir verifie le montant, le beneficiaire, le mode et les references de '
                        'transaction. Sauf erreur technique manifeste imputable a la plateforme ou obligation legale imperative, les paiements confirmes '
                        'sont reputes fermes et engages. L\'utilisateur accepte que les delais interbancaires, les retards operateur, les incidents reseau '
                        'ou les controles anti-fraude puissent retarder l\'affichage effectif d\'un statut de paiement. Les obligations de paiement restent '
                        'cependant dues, et la charge de la preuve des contestations incombe prioritairement a la partie qui les invoque.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '14. Echeanciers, penalites et recouvrement amiable',
                    content:
                        'Le paiement par tranches implique un engagement temporel ferme. Chaque echeance constitue une obligation autonome. En cas de retard, '
                        'la plateforme peut appliquer des restrictions fonctionnelles, demander des justificatifs, suspendre certains avantages, et declencher '
                        'des procedures de rappel graduelles. Avant toute mesure contentieuse, une tentative de recouvrement amiable est privilegiee. '
                        'L\'utilisateur reconnait que la repetition des impayes peut affecter son score de confiance, sa capacite future a souscrire des '
                        'engagements et sa priorite dans certains flux operationnels.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '15. Livraison: transfert des risques, reserves et preuve de remise',
                    content:
                        'La livraison est executee selon les informations renseignees par les parties. Le transfert des risques suit les principes applicables '
                        'du droit local et les modalites du service utilise. A la reception, l\'acheteur doit verifier l\'integrite apparente, la conformite '
                        'du colis et signaler sans delai toute reserve utile. L\'absence de reserve motivee dans le delai raisonnable peut valoir presomption '
                        'de reception conforme. Les photos, signatures, traces GPS, horodatages et confirmations dans l\'application peuvent etre utilises '
                        'comme elements de preuve pour etablir la realite de la remise.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '16. Gouvernance des tontines, discipline collective et confiance',
                    content:
                        'Les organisateurs disposent d\'un pouvoir de moderation et d\'admission encadre par les regles publiees de la tontine. Il leur revient '
                        'de selectionner des profils juges fiables, en priorisant les personnes de confiance, tout en respectant les normes de conduite et la '
                        'legislation applicable. Les membres admettent qu\'une tontine repose sur un principe de reciprocite et de loyautes successives: un '
                        'comportement reputee abusif, trompeur ou destabilisateur peut justifier des mesures internes allant jusqu\'a l\'exclusion, sans prejudice '
                        'des recours legaux ouverts aux parties.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '17. Propriete intellectuelle, marque et contenus utilisateurs',
                    content:
                        'Les elements distinctifs de TREZOR (marques, logos, interfaces, textes, structure applicative, elements graphiques et techniques) '
                        'sont proteges par les droits de propriete intellectuelle. Toute reproduction, extraction substantielle, adaptation, diffusion ou '
                        'reutilisation non autorisee est interdite. L\'utilisateur reste proprietaire de ses contenus licites, mais consent a la plateforme '
                        'une licence non exclusive et necessaire a l\'execution des services, notamment pour l\'hebergement, l\'affichage, la moderation, '
                        'la securisation et l\'archivage probatoire.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '18. Force majeure, indisponibilite et continuite de service',
                    content:
                        'Aucune partie ne pourra etre tenue pour responsable d\'un manquement exclusivement cause par un evenement de force majeure ou une '
                        'cause exterieure irresistible et imprevisible: catastrophe naturelle, panne majeure operateur, perturbation reseau globale, acte '
                        'd\'autorite, cyberattaque d\'ampleur, indisponibilite systemique tierce. TREZOR s\'engage a deployer des efforts raisonnables de '
                        'continuite et de reprise, sans garantie absolue de disponibilite ininterrompue.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '19. Compliance, anti-blanchiment et cooperation institutionnelle',
                    content:
                        'La plateforme applique une politique de conformite stricte incluant verification d\'identite, surveillance transactionnelle, '
                        'detection de comportements atypiques et conservation de journaux techniques conformement a la loi. En presence d\'indices serieux '
                        'de blanchiment, financement illicite, fraude structuree ou usage de documents alteres, TREZOR peut geler temporairement certains '
                        'flux, exiger des justificatifs additionnels et cooperer avec les autorites competentes, dans le respect du cadre juridique applicable.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  _sectionCard(
                    title: '20. Droit applicable, interpretation et survie des obligations',
                    content:
                        'Les presentes conditions sont interpretees de bonne foi et selon les principes generaux du droit des obligations et du commerce '
                        'electronique applicables. Toute clause invalidee n\'affecte pas la validite des autres stipulations, qui conservent plein effet. '
                        'Les obligations relatives a la preuve, a la confidentialite, aux paiements dus, a la responsabilite et au reglement des litiges '
                        'survivent a la suspension ou a la cloture du compte. Le present dispositif est voulu comme un cadre complet de securite juridique '
                        'destine a proteger durablement l\'ecosysteme TREZOR.',
                    card: card,
                    border: border,
                    textColor: text,
                    muted: muted,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: card,
                border: Border(top: BorderSide(color: border)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _accepted,
                        onChanged: (v) => setState(() => _accepted = v ?? false),
                        activeColor: AppColors.deepPurple,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Je reconnais avoir lu, compris et accepte sans reserve les Conditions d\'utilisation de TREZOR.',
                            style: TextStyle(fontSize: 12.5, color: text, height: 1.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _accepted ? () => Navigator.pop(context, true) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPurple,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.deepPurple.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'J\'accepte',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String content,
    required Color card,
    required Color border,
    required Color muted,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.deepPurple,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.8,
              height: 1.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ces dispositions sont appliquees avec diligence pour la securite juridique de toutes les parties.',
            style: TextStyle(
              fontSize: 11.5,
              color: muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
