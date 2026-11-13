// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tagline => 'Versez. Triez. Détendez-vous.';

  @override
  String get play => 'Jouer';

  @override
  String get levels => 'Niveaux';

  @override
  String get challenges => 'Défis';

  @override
  String get stats => 'Statistiques';

  @override
  String get settings => 'Réglages';

  @override
  String get dailyChallenge => 'Défi du jour';

  @override
  String get dailyDone => 'Défi du jour réussi';

  @override
  String dailyTitle(String date) {
    return 'Défi · $date';
  }

  @override
  String get exitTitle => 'Quitter Decant ?';

  @override
  String get exitMessage =>
      'Respirez, votre progression est enregistrée. Quitter l’app ?';

  @override
  String get exit => 'Quitter';

  @override
  String get stay => 'Rester';

  @override
  String get leave => 'Quitter';

  @override
  String get back => 'Retour';

  @override
  String get audio => 'Audio';

  @override
  String get muteAll => 'Tout couper';

  @override
  String get soundEffects => 'Effets sonores';

  @override
  String get ambience => 'Ambiance';

  @override
  String get music => 'Musique';

  @override
  String get ambientLoop => 'Ambiance en fond';

  @override
  String get ambienceSound => 'Son d’ambiance';

  @override
  String soundCount(String category, int count) {
    return '$category · $count sons';
  }

  @override
  String get backgroundMusic => 'Musique de fond';

  @override
  String get backgroundMusicSubtitle =>
      'Une musique douce par-dessus l’ambiance';

  @override
  String get musicTrack => 'Morceau';

  @override
  String trackCount(String category, int count) {
    return '$category · $count morceaux';
  }

  @override
  String get feel => 'Ressenti';

  @override
  String get haptics => 'Retour haptique';

  @override
  String get keepAwake => 'Garder l’écran allumé';

  @override
  String get pourSpeed => 'Vitesse de versement';

  @override
  String get pourRelaxed => 'Calme';

  @override
  String get pourNormal => 'Normale';

  @override
  String get pourQuick => 'Rapide';

  @override
  String get zenMode => 'Mode zen';

  @override
  String get zenModeSubtitle => 'Ni compteur ni étoiles. Versez, simplement.';

  @override
  String get accessibility => 'Accessibilité';

  @override
  String get theme => 'Thème';

  @override
  String get themeTwilight => 'Crépuscule';

  @override
  String get themeMidnight => 'Minuit';

  @override
  String get themeDaylight => 'Lumière du jour';

  @override
  String get highContrast => 'Contraste élevé';

  @override
  String get liquidColors => 'Couleurs des liquides';

  @override
  String get paletteStandard => 'Standard';

  @override
  String get paletteColorblind => 'Adapté au daltonisme';

  @override
  String get colorblindSymbols => 'Symboles daltonisme';

  @override
  String get colorblindSubtitle =>
      'Affiche une forme distincte sur chaque couleur';

  @override
  String get reduceMotion => 'Réduire les animations';

  @override
  String get reduceMotionSubtitle =>
      'Ni bulles, ni inclinaison, ni oscillation';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get timesUp => 'Temps écoulé';

  @override
  String get outOfMoves => 'Plus de coups';

  @override
  String get failMessage => 'Respirez et réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get dailySolved => 'Défi du jour réussi';

  @override
  String stageCleared(int stage) {
    return 'Étape $stage réussie';
  }

  @override
  String levelSolved(int level) {
    return 'Niveau $level résolu';
  }

  @override
  String get beautifullyDone => 'Magnifique.';

  @override
  String streakBeautifullyDone(int days) {
    return 'Série de $days jours. Magnifique.';
  }

  @override
  String moveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coups',
      one: '1 coup',
    );
    return '$_temp0';
  }

  @override
  String perfectTarget(String moves) {
    return 'Parfait : $moves, sans aide';
  }

  @override
  String get perfect => 'Parfait';

  @override
  String get done => 'Terminé';

  @override
  String get nextStage => 'Étape suivante';

  @override
  String get nextLevel => 'Niveau suivant';

  @override
  String get replay => 'Rejouer';

  @override
  String get leaveLevelTitle => 'Quitter ce niveau ?';

  @override
  String get leaveLevelMessage =>
      'Votre progression dans ce niveau n’est pas enregistrée : vous recommencerez à zéro.';

  @override
  String get keepPlaying => 'Continuer';

  @override
  String get noMovesHint => 'Plus de coups : annulez ou recommencez';

  @override
  String get noHintsLeft =>
      'Plus d’indices. Résolvez un niveau pour en gagner un.';

  @override
  String get noExtraTubes => 'Plus de tubes en plus';

  @override
  String levelHeader(int level, String chapter) {
    return 'Niveau $level · $chapter';
  }

  @override
  String difficulty(String dots) {
    return 'Difficulté $dots';
  }

  @override
  String threeStarsIn(int moves) {
    return '★★★ en $moves';
  }

  @override
  String get undo => 'Annuler';

  @override
  String get hint => 'Indice';

  @override
  String get addTube => 'Ajouter un tube vide';

  @override
  String get howToPlay => 'Comment jouer';

  @override
  String get stuckBanner =>
      'Plus de coups. Annulez, recommencez ou ajoutez un tube vide.';

  @override
  String stageTitle(String mode, int stage) {
    return '$mode · Étape $stage';
  }

  @override
  String get tutorialTapTitle => 'Touchez le tube lumineux';

  @override
  String get tutorialTapBody => 'Cela prend la couleur du dessus.';

  @override
  String get tutorialPourTitle => 'Touchez maintenant l’autre tube lumineux';

  @override
  String get tutorialPourBody =>
      'Les couleurs se versent sur la même couleur ou dans un tube vide.';

  @override
  String get skip => 'Passer';

  @override
  String get tutorialGoal => 'Triez chaque tube en une seule couleur';

  @override
  String get tutorialStars =>
      'Moins de coups, plus d’étoiles. Si vous bloquez :';

  @override
  String get tutorialUndo => 'Annuler un versement';

  @override
  String get tutorialHint => 'Voir un indice (coûte une étoile)';

  @override
  String get tutorialAddTube => 'Ajouter un tube vide';

  @override
  String get gotIt => 'Compris';

  @override
  String get levelsSolved => 'Niveaux résolus';

  @override
  String nextUp(int level) {
    return 'Prochain : niveau $level';
  }

  @override
  String get stars => 'Étoiles';

  @override
  String get perfectLevels => 'Niveaux parfaits';

  @override
  String get perfectLevelsDetail => 'Coups minimum, sans indice';

  @override
  String get wins => 'Victoires';

  @override
  String get winsDetail => 'Parties rejouées incluses';

  @override
  String get starsPerLevel => 'Étoiles par niveau';

  @override
  String get noStreak => 'Pas encore de série';

  @override
  String streak(int days) {
    return 'Série de $days jours';
  }

  @override
  String get streakStart =>
      'Gagnez un niveau aujourd’hui pour en commencer une.';

  @override
  String get streakDone => 'La victoire du jour est là. À demain.';

  @override
  String get streakKeep => 'Gagnez un niveau aujourd’hui pour la prolonger.';

  @override
  String get statsEmpty => 'Résolvez un niveau pour voir vos étoiles.';

  @override
  String bestStage(int stage) {
    return 'Record : étape $stage';
  }

  @override
  String get notPlayed => 'Pas encore joué';

  @override
  String playStage(int stage) {
    return 'Jouer l’étape $stage';
  }

  @override
  String get modeMoves => 'Coups limités';

  @override
  String get modeMovesBlurb =>
      'Résolvez sans dépasser la limite. Pas d’annulation.';

  @override
  String get modeTimed => 'Contre la montre';

  @override
  String get modeTimedBlurb =>
      'Battez le chrono. Il démarre au premier versement.';

  @override
  String levelShort(int level) {
    return 'Niv $level';
  }

  @override
  String chapterTitle(int number, String name) {
    return 'Chapitre $number · $name';
  }

  @override
  String chapterSolved(int solved, int total) {
    return '$solved/$total résolus';
  }

  @override
  String get chapterDawn => 'Aube';

  @override
  String get chapterTide => 'Marée';

  @override
  String get chapterEmber => 'Braise';

  @override
  String get chapterGrove => 'Bosquet';

  @override
  String get chapterDusk => 'Crépuscule';

  @override
  String get chapterAurora => 'Aurore';

  @override
  String get dailyNew => 'Un nouveau puzzle chaque jour';

  @override
  String get streakReminders => 'Rappels de série';

  @override
  String get streakRemindersSubtitle =>
      'Un petit rappel si le défi du jour n’est pas fait';

  @override
  String get reminderTime => 'Heure du rappel';

  @override
  String get notificationsBlocked =>
      'Les notifications de Decant sont désactivées. Activez-les dans les réglages du système.';

  @override
  String reminderStreakTitle(int days) {
    return 'Gardez votre série de $days jours';
  }

  @override
  String get reminderStreakBody => 'Le puzzle du jour vous attend.';

  @override
  String get reminderTitle => 'Un nouveau puzzle du jour est prêt';

  @override
  String get reminderBody => 'Prenez une minute de calme et versez.';

  @override
  String get reminderOfferTitle => 'Garder votre série ?';

  @override
  String reminderOfferMessage(String time) {
    return 'Decant peut vous envoyer un petit rappel à $time les jours où le défi du jour n’est pas fait. Modifiable dans les Réglages.';
  }

  @override
  String get remindMe => 'Me le rappeler';

  @override
  String get notNow => 'Plus tard';

  @override
  String get outOfHintsTitle => 'Plus d’indices';

  @override
  String get watchForHintMessage =>
      'Regardez une courte vidéo pour obtenir un indice maintenant, ou résolvez un niveau pour en gagner un.';

  @override
  String get watchVideo => 'Voir la vidéo';

  @override
  String get noVideoReady =>
      'Aucune vidéo n’est prête pour le moment. Réessayez dans un instant.';

  @override
  String get videoNotFinished =>
      'La vidéo s’est arrêtée avant la fin : pas d’indice cette fois.';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get adPrivacyChoices => 'Choix de confidentialité des annonces';

  @override
  String get adPrivacySubtitle =>
      'Modifier l’usage de vos données par les annonces';

  @override
  String levelTitle(int level) {
    return 'Niveau $level';
  }

  @override
  String get cloudSave => 'Sauvegarde cloud';

  @override
  String get cloudSaveSubtitle =>
      'Sauvegardez votre progression et reprenez-la sur n’importe quel appareil.';

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String cloudSignedInAs(String account) {
    return 'Connecté en tant que $account';
  }

  @override
  String get cloudSyncing => 'Synchronisation…';

  @override
  String get cloudSynced => 'Progression sauvegardée';

  @override
  String get cloudSyncFailed =>
      'Impossible de joindre le cloud. Nouvel essai plus tard.';

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signedOutNotice =>
      'Déconnecté. Votre progression reste sur ce téléphone.';

  @override
  String get signInFailed =>
      'Connexion impossible. Vérifiez votre connexion et réessayez.';

  @override
  String get deleteCloudSave => 'Supprimer la sauvegarde cloud';

  @override
  String get deleteCloudSaveMessage =>
      'Votre progression sauvegardée dans le cloud et votre compte Decant seront supprimés. La progression sur ce téléphone est conservée.';

  @override
  String get delete => 'Supprimer';

  @override
  String get cloudDeleted => 'Sauvegarde cloud supprimée.';

  @override
  String get cloudDeleteFailed =>
      'Suppression impossible. Vérifiez votre connexion et réessayez.';
}
