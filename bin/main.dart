import 'dart:io';

import 'package:cardboard_bot/cardboard_bot.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:yaml/yaml.dart';

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

  ///////////////
  // Setup Nyxx Bot
  ////////////////

  INyxxWebsocket bot = NyxxFactory.createNyxxWebsocket(
    CardboardBotConfigYaml.nyxx.token,
    CardboardBot.intents,
  )
    ..registerPlugin(IgnoreExceptions())
    ..registerPlugin(CliIntegration());

  IInteractions interactions = IInteractions.create(WebsocketInteractionBackend(bot));

  // Connect bot
  await bot.connect();

  /////////////////////////
  // Setup CardboardBot
  //////////////////////////

  //TODO: Refactor the service/caching service initialization, preferably pass it into CardboardBot

  initializeTcgPlayerClient(
    publicKey: CardboardBotConfigYaml.tcgPlayerApiConfig.publicKey,
    privateKey: CardboardBotConfigYaml.tcgPlayerApiConfig.privateKey,
  );

  await CardboardBot.boot(
    bot: bot,
    interactions: interactions,
    tcgplayerInclusionRules: [
      InclusionRule(categoryMatch: RegExp("pokemon", caseSensitive: false)),
      InclusionRule(categoryMatch: RegExp("flesh and blood", caseSensitive: false)),
      InclusionRule(categoryMatch: RegExp("final fantasy", caseSensitive: false)),
      InclusionRule(categoryMatch: RegExp("weiss schwarz", caseSensitive: false)),
    ],
  );

  /////////////////////////////
  // Sync Interactions
  /////////////////////////
  interactions.sync();
}

abstract class CardboardBotConfigYaml {
  static NyxxConfig? _nyxxConfig;

  static NyxxConfig get nyxx {
    _nyxxConfig ??= NyxxConfig.fromYaml(_getYamlDocument());
    return _nyxxConfig!;
  }

  static TcgPlayerApiConfig? _tcgPlayerApiConfig;

  static TcgPlayerApiConfig get tcgPlayerApiConfig {
    _tcgPlayerApiConfig ??= TcgPlayerApiConfig.fromYaml(_getYamlDocument());
    return _tcgPlayerApiConfig!;
  }

  static YamlDocument _getYamlDocument() => loadYamlDocument(File("configs/cardboard_bot_config.yaml").readAsStringSync());
}

class NyxxConfig {
  final String token;

  NyxxConfig(
      this.token,
      );

  factory NyxxConfig.fromYaml(YamlDocument yaml) {
    dynamic node = yaml.contents.value["discordBot"];
    return NyxxConfig(
      node["token"] as String,
    );
  }
}

class TcgPlayerApiConfig {
  final String publicKey;
  final String privateKey;

  TcgPlayerApiConfig(
      this.publicKey,
      this.privateKey,
      );

  factory TcgPlayerApiConfig.fromYaml(YamlDocument yaml) {
    dynamic node = yaml.contents.value["tcgPlayerApi"];
    return TcgPlayerApiConfig(
      node["publicKey"] as String,
      node["privateKey"] as String,
    );
  }
}
