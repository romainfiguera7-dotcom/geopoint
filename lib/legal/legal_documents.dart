class PointGeoLegalSection {
  const PointGeoLegalSection({required this.title, required this.body});

  final String title;
  final String body;
}

class PointGeoLegalDocument {
  const PointGeoLegalDocument({
    required this.title,
    required this.updatedAt,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final List<PointGeoLegalSection> sections;
}

abstract final class PointGeoLegalDocuments {
  static const String publisherName = 'Romain Figuera';
  static const String publisherAddress =
      '3B rue du Salaison, 34740 Vendargues, France';
  static const String contactEmail = 'vipers34170@gmail.com';
  static const String privacyUrl =
      'https://geopoint-dev.web.app/confidentialite';
  static const String accountDeletionUrl =
      'https://geopoint-dev.web.app/supprimer-compte';

  static const PointGeoLegalDocument legalNotice = PointGeoLegalDocument(
    title: 'Mentions légales',
    updatedAt: '8 septembre 2026',
    sections: <PointGeoLegalSection>[
      PointGeoLegalSection(
        title: 'Éditeur de l’application',
        body: 'PointGeo est éditée à titre individuel par Romain Figuera.\n'
            'Adresse : 3B rue du Salaison, 34740 Vendargues, France.\n'
            'Contact : vipers34170@gmail.com.',
      ),
      PointGeoLegalSection(
        title: 'Direction de la publication',
        body: 'Le directeur de la publication est Romain Figuera.',
      ),
      PointGeoLegalSection(
        title: 'Hébergement',
        body: 'Les services en ligne et les pages légales sont hébergés par '
            'Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, '
            'Irlande, au moyen des services Firebase et Google Cloud.',
      ),
      PointGeoLegalSection(
        title: 'Propriété intellectuelle',
        body: 'Le nom PointGeo, son interface, ses textes, ses illustrations '
            'et son code sont protégés. Toute reproduction ou réutilisation '
            'non autorisée est interdite, sous réserve des licences des '
            'composants tiers et des données cartographiques.',
      ),
      PointGeoLegalSection(
        title: 'Contact',
        body: 'Toute question juridique, technique ou relative aux données '
            'personnelles peut être envoyée à vipers34170@gmail.com.',
      ),
    ],
  );

  static const PointGeoLegalDocument privacyPolicy = PointGeoLegalDocument(
    title: 'Politique de confidentialité',
    updatedAt: '8 septembre 2026',
    sections: <PointGeoLegalSection>[
      PointGeoLegalSection(
        title: 'Responsable du traitement',
        body: 'Romain Figuera, 3B rue du Salaison, 34740 Vendargues, France. '
            'Contact : vipers34170@gmail.com.',
      ),
      PointGeoLegalSection(
        title: 'Public concerné',
        body: 'La version 1 de PointGeo est destinée aux personnes âgées de '
            '16 ans ou plus. Le module enfant est désactivé. La création et '
            'l’utilisation d’un compte sont réservées aux utilisateurs de '
            '16 ans ou plus.',
      ),
      PointGeoLegalSection(
        title: 'Données traitées',
        body: 'Selon les fonctions utilisées, PointGeo traite : un '
            'identifiant Firebase, l’adresse e-mail liée au compte, le '
            'pseudonyme, l’avatar, la progression, les scores, les '
            'classements, le code ami et les relations sociales ; les '
            'sessions de jeu nécessaires à la sécurité et à la lutte contre '
            'la triche ; les informations indispensables à la validation '
            'd’un achat ; ainsi que les choix de consentement et données '
            'techniques traitées par Google pour la publicité.',
      ),
      PointGeoLegalSection(
        title: 'Finalités et bases juridiques',
        body: 'Les données de compte et de progression sont utilisées pour '
            'fournir le jeu, synchroniser la sauvegarde, gérer les amis, les '
            'classements et les achats. Les contrôles techniques servent '
            'l’intérêt légitime de sécuriser le service et de prévenir la '
            'fraude. La publicité personnalisée et l’accès aux identifiants '
            'publicitaires reposent sur le consentement lorsqu’il est requis.',
      ),
      PointGeoLegalSection(
        title: 'Destinataires et prestataires',
        body: 'Les données sont accessibles à l’éditeur et, uniquement pour '
            'leurs missions, aux services Google Firebase, Google Cloud, '
            'Google Play et Google AdMob. Ces prestataires peuvent traiter '
            'des données hors de l’Espace économique européen avec les '
            'garanties prévues par leurs conditions et la réglementation.',
      ),
      PointGeoLegalSection(
        title: 'Durée de conservation',
        body: 'Les données utiles au compte sont conservées pendant son '
            'utilisation. Elles sont supprimées à la demande, sauf '
            'informations devant être conservées temporairement pour la '
            'sécurité, la preuve d’un achat, la prévention de la fraude ou '
            'une obligation légale. Les données locales disparaissent lors '
            'de la suppression depuis l’application ou de sa désinstallation.',
      ),
      PointGeoLegalSection(
        title: 'Publicité et consentement',
        body: 'PointGeo utilise Google AdMob. Lorsqu’il est requis, un écran '
            'de consentement est présenté avant toute demande publicitaire. '
            'Le choix peut être modifié depuis Paramètres > Informations '
            'légales > Choix publicitaires. L’achat sans publicité empêche '
            'l’affichage des annonces dans PointGeo.',
      ),
      PointGeoLegalSection(
        title: 'Vos droits',
        body: 'Vous pouvez demander l’accès, la rectification, l’effacement, '
            'la limitation, l’opposition ou la portabilité de vos données en '
            'écrivant à vipers34170@gmail.com. Vous pouvez aussi introduire '
            'une réclamation auprès de la CNIL sur www.cnil.fr.',
      ),
      PointGeoLegalSection(
        title: 'Suppression du compte',
        body: 'La suppression est accessible depuis Paramètres > Mon compte '
            '> Supprimer mon compte. Elle efface le compte Firebase et les '
            'données de jeu associées. Une demande externe peut également '
            'être effectuée depuis geopoint-dev.web.app/supprimer-compte.',
      ),
    ],
  );

  static const PointGeoLegalDocument terms = PointGeoLegalDocument(
    title: 'Conditions d’utilisation',
    updatedAt: '8 septembre 2026',
    sections: <PointGeoLegalSection>[
      PointGeoLegalSection(
        title: 'Objet',
        body: 'PointGeo est un jeu de géographie proposant des entraînements, '
            'des expéditions, des défis et des classements. L’utilisation de '
            'la version 1 implique l’acceptation des présentes conditions.',
      ),
      PointGeoLegalSection(
        title: 'Âge minimum',
        body: 'PointGeo V1 et ses fonctions de compte sont réservées aux '
            'personnes âgées de 16 ans ou plus.',
      ),
      PointGeoLegalSection(
        title: 'Compte et sécurité',
        body: 'L’utilisateur est responsable de ses identifiants et des '
            'informations fournies. Il s’engage à ne pas contourner les '
            'contrôles, falsifier ses résultats, perturber le service ou '
            'utiliser un pseudonyme illicite ou portant atteinte à autrui.',
      ),
      PointGeoLegalSection(
        title: 'Classements et modération',
        body: 'Les résultats classés sont vérifiés automatiquement. PointGeo '
            'peut mettre en attente, corriger ou retirer un résultat '
            'manifestement invalide, ainsi que modérer un pseudonyme public.',
      ),
      PointGeoLegalSection(
        title: 'Publicités et achat sans publicité',
        body: 'La version gratuite peut afficher des publicités. L’achat '
            'ponctuel sans publicité est traité par Google Play et peut être '
            'restauré avec le compte ayant réalisé l’achat. Les conditions de '
            'paiement et de remboursement de Google Play s’appliquent.',
      ),
      PointGeoLegalSection(
        title: 'Disponibilité et contenu géographique',
        body: 'L’éditeur s’efforce de fournir un service fiable et des '
            'informations géographiques exactes, sans garantir une '
            'disponibilité permanente ni l’absence totale d’erreurs. Le '
            'service peut évoluer, être suspendu ou être mis à jour.',
      ),
      PointGeoLegalSection(
        title: 'Résiliation',
        body: 'L’utilisateur peut arrêter d’utiliser le service et supprimer '
            'son compte à tout moment. Un compte peut être restreint en cas '
            'de fraude, d’abus ou de violation grave des présentes conditions.',
      ),
      PointGeoLegalSection(
        title: 'Droit applicable',
        body: 'Les présentes conditions sont régies par le droit français, '
            'sans priver le consommateur des protections impératives '
            'applicables. Contact : vipers34170@gmail.com.',
      ),
    ],
  );
}
