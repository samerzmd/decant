// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tagline => 'Vierte. Ordena. Relájate.';

  @override
  String get play => 'Jugar';

  @override
  String get levels => 'Niveles';

  @override
  String get challenges => 'Desafíos';

  @override
  String get stats => 'Estadísticas';

  @override
  String get settings => 'Ajustes';

  @override
  String get dailyChallenge => 'Desafío diario';

  @override
  String get dailyDone => 'Diario hecho';

  @override
  String dailyTitle(String date) {
    return 'Diario · $date';
  }

  @override
  String get exitTitle => '¿Salir de Decant?';

  @override
  String get exitMessage =>
      'Respira: tu progreso está guardado. ¿Salir de la app?';

  @override
  String get exit => 'Salir';

  @override
  String get stay => 'Quedarme';

  @override
  String get leave => 'Salir';

  @override
  String get back => 'Atrás';

  @override
  String get audio => 'Audio';

  @override
  String get muteAll => 'Silenciar todo';

  @override
  String get soundEffects => 'Efectos de sonido';

  @override
  String get ambience => 'Ambiente';

  @override
  String get music => 'Música';

  @override
  String get ambientLoop => 'Sonido ambiente de fondo';

  @override
  String get ambienceSound => 'Sonido ambiente';

  @override
  String soundCount(String category, int count) {
    return '$category · $count sonidos';
  }

  @override
  String get backgroundMusic => 'Música de fondo';

  @override
  String get backgroundMusicSubtitle => 'Música tranquila sobre el ambiente';

  @override
  String get musicTrack => 'Pista de música';

  @override
  String trackCount(String category, int count) {
    return '$category · $count pistas';
  }

  @override
  String get feel => 'Sensación';

  @override
  String get haptics => 'Vibración';

  @override
  String get keepAwake => 'Mantener pantalla encendida';

  @override
  String get pourSpeed => 'Velocidad de vertido';

  @override
  String get pourRelaxed => 'Tranquila';

  @override
  String get pourNormal => 'Normal';

  @override
  String get pourQuick => 'Rápida';

  @override
  String get zenMode => 'Modo zen';

  @override
  String get zenModeSubtitle => 'Sin contador ni estrellas. Solo vierte.';

  @override
  String get accessibility => 'Accesibilidad';

  @override
  String get theme => 'Tema';

  @override
  String get themeTwilight => 'Crepúsculo';

  @override
  String get themeMidnight => 'Medianoche';

  @override
  String get themeDaylight => 'Luz del día';

  @override
  String get highContrast => 'Alto contraste';

  @override
  String get liquidColors => 'Colores del líquido';

  @override
  String get paletteStandard => 'Estándar';

  @override
  String get paletteColorblind => 'Apto para daltonismo';

  @override
  String get colorblindSymbols => 'Símbolos para daltonismo';

  @override
  String get colorblindSubtitle => 'Muestra una forma distinta en cada color';

  @override
  String get reduceMotion => 'Reducir movimiento';

  @override
  String get reduceMotionSubtitle => 'Sin burbujas, inclinación ni vaivén';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get timesUp => 'Se acabó el tiempo';

  @override
  String get outOfMoves => 'Sin movimientos';

  @override
  String get failMessage => 'Respira y vuelve a intentarlo.';

  @override
  String get retry => 'Reintentar';

  @override
  String get dailySolved => 'Desafío diario resuelto';

  @override
  String stageCleared(int stage) {
    return 'Etapa $stage superada';
  }

  @override
  String levelSolved(int level) {
    return 'Nivel $level resuelto';
  }

  @override
  String get beautifullyDone => 'Precioso.';

  @override
  String streakBeautifullyDone(int days) {
    return 'Racha de $days días. Precioso.';
  }

  @override
  String moveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos',
      one: '1 movimiento',
    );
    return '$_temp0';
  }

  @override
  String perfectTarget(String moves) {
    return 'Perfecto: $moves, sin ayuda';
  }

  @override
  String get perfect => 'Perfecto';

  @override
  String get done => 'Hecho';

  @override
  String get nextStage => 'Siguiente etapa';

  @override
  String get nextLevel => 'Siguiente nivel';

  @override
  String get replay => 'Repetir';

  @override
  String get leaveLevelTitle => '¿Salir de este nivel?';

  @override
  String get leaveLevelMessage =>
      'Tu progreso en este nivel no se guarda: la próxima vez empezarás de cero.';

  @override
  String get keepPlaying => 'Seguir jugando';

  @override
  String get noMovesHint => 'No quedan movimientos: deshaz o reinicia';

  @override
  String get noHintsLeft =>
      'No quedan pistas. Resuelve un nivel para ganar una.';

  @override
  String get noExtraTubes => 'No quedan tubos extra';

  @override
  String levelHeader(int level, String chapter) {
    return 'Nivel $level · $chapter';
  }

  @override
  String difficulty(String dots) {
    return 'Dificultad $dots';
  }

  @override
  String threeStarsIn(int moves) {
    return '★★★ en $moves';
  }

  @override
  String get undo => 'Deshacer';

  @override
  String get hint => 'Pista';

  @override
  String get addTube => 'Añadir tubo vacío';

  @override
  String get howToPlay => 'Cómo jugar';

  @override
  String get stuckBanner =>
      'No quedan movimientos. Deshaz, reinicia o añade un tubo vacío.';

  @override
  String stageTitle(String mode, int stage) {
    return '$mode · Etapa $stage';
  }

  @override
  String get tutorialTapTitle => 'Toca el tubo que brilla';

  @override
  String get tutorialTapBody => 'Así tomas el color de arriba.';

  @override
  String get tutorialPourTitle => 'Ahora toca el otro tubo que brilla';

  @override
  String get tutorialPourBody =>
      'Los colores se vierten sobre el mismo color o en un tubo vacío.';

  @override
  String get skip => 'Saltar';

  @override
  String get tutorialGoal => 'Deja cada tubo de un solo color';

  @override
  String get tutorialStars =>
      'Menos movimientos dan más estrellas. Si te atascas:';

  @override
  String get tutorialUndo => 'Deshacer un vertido';

  @override
  String get tutorialHint => 'Ver una pista (cuesta una estrella)';

  @override
  String get tutorialAddTube => 'Añadir un tubo vacío';

  @override
  String get gotIt => 'Entendido';

  @override
  String get levelsSolved => 'Niveles resueltos';

  @override
  String nextUp(int level) {
    return 'Siguiente: nivel $level';
  }

  @override
  String get stars => 'Estrellas';

  @override
  String get perfectLevels => 'Niveles perfectos';

  @override
  String get perfectLevelsDetail => 'Movimientos justos, sin pistas';

  @override
  String get wins => 'Victorias';

  @override
  String get winsDetail => 'Repeticiones incluidas';

  @override
  String get starsPerLevel => 'Estrellas por nivel';

  @override
  String get noStreak => 'Aún sin racha';

  @override
  String streak(int days) {
    return 'Racha de $days días';
  }

  @override
  String get streakStart => 'Gana un nivel hoy para empezar una.';

  @override
  String get streakDone => 'La victoria de hoy ya está. Hasta mañana.';

  @override
  String get streakKeep => 'Gana un nivel hoy para mantenerla.';

  @override
  String get statsEmpty => 'Resuelve un nivel para ver tus estrellas.';

  @override
  String bestStage(int stage) {
    return 'Mejor: etapa $stage';
  }

  @override
  String get notPlayed => 'Aún sin jugar';

  @override
  String playStage(int stage) {
    return 'Jugar etapa $stage';
  }

  @override
  String get modeMoves => 'Límite de movimientos';

  @override
  String get modeMovesBlurb => 'Resuelve dentro del límite. Sin deshacer.';

  @override
  String get modeTimed => 'Contrarreloj';

  @override
  String get modeTimedBlurb => 'Gana al reloj. Empieza con tu primer vertido.';

  @override
  String levelShort(int level) {
    return 'Nv $level';
  }

  @override
  String chapterTitle(int number, String name) {
    return 'Capítulo $number · $name';
  }

  @override
  String chapterSolved(int solved, int total) {
    return '$solved/$total resueltos';
  }

  @override
  String get chapterDawn => 'Alba';

  @override
  String get chapterTide => 'Marea';

  @override
  String get chapterEmber => 'Brasa';

  @override
  String get chapterGrove => 'Arboleda';

  @override
  String get chapterDusk => 'Ocaso';

  @override
  String get chapterAurora => 'Aurora';

  @override
  String get dailyNew => 'Un puzle nuevo cada día';

  @override
  String get streakReminders => 'Recordatorios de racha';

  @override
  String get streakRemindersSubtitle =>
      'Un aviso suave si no has hecho el desafío de hoy';

  @override
  String get reminderTime => 'Hora del recordatorio';

  @override
  String get notificationsBlocked =>
      'Las notificaciones de Decant están desactivadas. Actívalas en los ajustes del sistema.';

  @override
  String reminderStreakTitle(int days) {
    return 'Mantén tu racha de $days días';
  }

  @override
  String get reminderStreakBody => 'El puzle diario de hoy te espera.';

  @override
  String get reminderTitle => 'Hay un nuevo puzle diario';

  @override
  String get reminderBody => 'Tómate un minuto tranquilo y vierte.';

  @override
  String get reminderOfferTitle => '¿Mantener tu racha?';

  @override
  String reminderOfferMessage(String time) {
    return 'Decant puede enviarte un aviso suave a las $time los días que no hayas resuelto el desafío diario. Puedes cambiarlo en Ajustes.';
  }

  @override
  String get remindMe => 'Recuérdamelo';

  @override
  String get notNow => 'Ahora no';

  @override
  String get outOfHintsTitle => 'Sin pistas';

  @override
  String get watchForHintMessage =>
      'Mira un vídeo corto para obtener una pista ahora, o resuelve un nivel para ganar una.';

  @override
  String get watchVideo => 'Ver vídeo';

  @override
  String get noVideoReady =>
      'Ahora no hay ningún vídeo listo. Inténtalo de nuevo en un momento.';

  @override
  String get videoNotFinished =>
      'El vídeo terminó antes de tiempo, así que esta vez no hay pista.';

  @override
  String get privacy => 'Privacidad';

  @override
  String get adPrivacyChoices => 'Opciones de privacidad de anuncios';

  @override
  String get adPrivacySubtitle => 'Cambia cómo usan tus datos los anuncios';

  @override
  String levelTitle(int level) {
    return 'Nivel $level';
  }
}
