import 'dart:io';

import 'package:cardboard_bot/cardboard_bot.dart';
import 'package:cardboard_bot/src/google_cloud_services/google_cloud_service.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:googleapis/compute/v1.dart' as gce;
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

  // TODO: make enableGoogleCloud a cli argument
  await initialize(enableGoogleCloud: true);
}

Future<void> initialize({required bool enableGoogleCloud}) async {
  // ignore: unused_local_variable
  final Logger logger = Logger("initialize");

  ///////////////
  // Setup Infrastructure Cloud Api
  ///////////////
  if (enableGoogleCloud) {
    // TODO: There is probably a better google api for getting the projectId that owns the service account
    var googleCloudProjectId = "cardboardbot-f4c69";
    var googleConfigFile = File("cardboard_bot/configs/googleapis_service_account.json");
    if (googleConfigFile.existsSync()) {
      // Local Environment
      await GoogleCloudService.initialize(projectId: googleCloudProjectId, serviceAccountCredentials: googleConfigFile.readAsStringSync());
    } else {
      // Cloud Environment
      await GoogleCloudService.initialize(projectId: googleCloudProjectId);
    }
  }

  ///////////////
  // Get App Configs
  ///////////////
  NyxxConfig nyxxConfig;
  TcgPlayerApiConfig tcgPlayerApiConfig;

  var localAppConfigFile = File("cardboard_bot/configs/app_config.yaml");

  if (localAppConfigFile.existsSync()) {
    var yamlDocument = loadYamlDocument(localAppConfigFile.readAsStringSync());
    nyxxConfig = NyxxConfig.fromYaml(yamlDocument);
    tcgPlayerApiConfig = TcgPlayerApiConfig.fromYaml(yamlDocument);
  } else if (enableGoogleCloud) {
    var metadata = (await GoogleCloudService().getComputeEngineMetadata())!;
    nyxxConfig = NyxxConfig.fromMetadata(metadata);
    tcgPlayerApiConfig = TcgPlayerApiConfig.fromMetadata(metadata);
  } else {
    throw Exception("There needs to be at least one provider of app_config!");
  }


  ///////////////
  // Setup Nyxx Bot
  ////////////////
  INyxxWebsocket bot = NyxxFactory.createNyxxWebsocket(
    nyxxConfig.token,
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
  initializeTcgPlayerClient(
    publicKey: tcgPlayerApiConfig.publicKey,
    privateKey: tcgPlayerApiConfig.privateKey,
  );

  //TODO: Consider abstracting out persistence with a provider.
  TcgPlayerCachingService tcgPlayerService = await TcgPlayerCachingService.initialize([
    // InclusionRule(categoryMatch: RegExp(".+", caseSensitive: false)),
    InclusionRule(categoryMatch: RegExp("pokemon", caseSensitive: false)),
    InclusionRule(categoryMatch: RegExp("flesh and blood", caseSensitive: false)),
    InclusionRule(categoryMatch: RegExp("final fantasy", caseSensitive: false)),
    InclusionRule(categoryMatch: RegExp("weiss schwarz", caseSensitive: false)),
    InclusionRule(categoryMatch: RegExp("YuGiOh", caseSensitive: false)),
    // InclusionRule(categoryMatch: RegExp("Cardfight Vanguard", caseSensitive: false)),
    // InclusionRule(categoryMatch: RegExp("Digimon", caseSensitive: false)),
    // InclusionRule(categoryMatch: RegExp("Dragon Ball", caseSensitive: false)),
    InclusionRule(categoryMatch: RegExp("Force of Will", caseSensitive: false)),
    // InclusionRule(categoryMatch: RegExp("Future Card BuddyFight", caseSensitive: false)),
    // MTG is the gigabyte problem
    // InclusionRule(categoryMatch: RegExp("Magic the Gathering", caseSensitive: false)),
    InclusionRule(categoryMatch: RegExp("MetaZoo", caseSensitive: false)),
    // InclusionRule(categoryMatch: RegExp("My Little Pony", caseSensitive: false)),
    // InclusionRule(categoryMatch: RegExp("Star Wars Destiny", caseSensitive: false)),
    // InclusionRule(categoryMatch: RegExp("WoW", caseSensitive: false)),
  ]);

  //TODO: Consider abstracting out the persistence with a provider.
  await CardboardBot.boot(
    bot: bot,
    interactions: interactions,
    tcgPlayerService: tcgPlayerService,
  );

  ///////////////////////
  // Sync Interactions
  ///////////////////////
  interactions.sync();
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

  factory NyxxConfig.fromMetadata(gce.Metadata metadata) {
    return NyxxConfig(
      metadata.items!.firstWhere((element) => element.key == "discord_bot_token").value!
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

  factory TcgPlayerApiConfig.fromMetadata(gce.Metadata metadata) {
    return TcgPlayerApiConfig(
      metadata.items!.firstWhere((element) => element.key == "tcgplayer_public_key").value!,
      metadata.items!.firstWhere((element) => element.key == "tcgplayer_private_key").value!,
    );
  }
}
