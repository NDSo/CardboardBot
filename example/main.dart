import 'package:cardboard_bot/src/cardboard_bot/cardboard_bot.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';

void main() async {
// ignore: unused_local_variable
  final Logger logger = Logger("main");
  Logger.root.onRecord.listen((LogRecord rec) {
    print("[${rec.time}] [${rec.level.name}] [${rec.loggerName}] ${rec.message}");
    if (rec.error != null && (rec.error is Error || rec.error is Exception)) print("${rec.error.toString()}");
    if (rec.stackTrace != null && (rec.level == Level.SEVERE || rec.level == Level.SHOUT)) print("${rec.stackTrace?.toString()}");
  });

  initialize();
}

Future<void> initialize() async {
  // ignore: unused_local_variable
  final Logger logger = Logger("initialize");

  INyxxWebsocket bot = NyxxFactory.createNyxxWebsocket(
    r"$DISCORD_TOKEN",
    CardboardBot.intents,
  )
    ..registerPlugin(IgnoreExceptions())
    ..registerPlugin(CliIntegration());

  IInteractions interactions = IInteractions.create(WebsocketInteractionBackend(bot));

  // Initialize TcgPlayerService
  initializeTcgPlayerClient(
    publicKey: r"$TCGPLAYER_API_PUBLIC_KEY",
    privateKey: r"$TCGPLAYER_API_PRIVATE_KEY",
  );

  CardboardBot.boot(
    bot: bot,
    interactions: interactions,
    tcgplayerInclusionRules: [
      InclusionRule(categoryMatch: RegExp("pokemon", caseSensitive: false)),
    ],
  );

  interactions.syncOnReady();
  bot.connect();
}
