import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:cardboard_bot/cardboard_bot.dart';
import 'package:cardboard_bot/repository.dart';
import 'package:cardboard_bot/src/cardboard_bot/actions/tcgplayer_alert_action/tcgplayer_alert_action.dart';
import 'package:cardboard_bot/src/cardboard_bot/actions/tcgplayer_alert_action/tcgplayer_alert_action_service.dart';
import 'package:cardboard_bot/src/tcgplayer_caching_service/models/product_info_cache.dart';
import 'package:cardboard_bot/src/tcgplayer_caching_service/services/price_cache_service.dart';
import 'package:cardboard_bot/src/tcgplayer_caching_service/services/product_cache_service.dart';
import 'package:cardboard_bot/tcgplayer_caching_service.dart';
import 'package:cardboard_bot/tcgplayer_client.dart';
import 'package:googleapis/compute/v1.dart' as compute show ComputeApi;
import 'package:googleapis/firestore/v1.dart' as firestore show FirestoreApi;
import 'package:googleapis/storage/v1.dart' as storage show StorageApi;
import 'package:kiwi/kiwi.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_interactions/nyxx_interactions.dart';
import 'package:yaml/yaml.dart';

import 'google_cloud_initializer.dart';
import 'nyxx_config.dart';
import 'tcgplayer_api_config.dart';

void main(List<String> arguments) async {
// ignore: unused_local_variable
  final Logger logger = Logger("main");
  Logger.root.onRecord.listen((LogRecord rec) {
    print("[${rec.time}] [${rec.level.name}] [${rec.loggerName}] ${rec.message}");
    if (rec.error != null && (rec.error is Error || rec.error is Exception)) print("${rec.error.toString()}");
    if (rec.stackTrace != null && (rec.level == Level.SEVERE || rec.level == Level.SHOUT)) print("${rec.stackTrace?.toString()}");
  });

  String? googleCloudProjectId;
  var argParser = ArgParser()..addOption("google_cloud_project_id", callback: (value) => googleCloudProjectId = value);
  var argResults = argParser.parse(arguments);

  await initialize(googleCloudProjectId: googleCloudProjectId);
}

Future<void> initialize({String? googleCloudProjectId}) async {
  // ignore: unused_local_variable
  final Logger logger = Logger("initialize");

  ///////////////
  // Setup Infrastructure Cloud Api
  ///////////////
  if (googleCloudProjectId != null) {
    // Initialize cloud clients
    await GoogleCloudInitializer.initialize(projectId: googleCloudProjectId);

    // Get keys from compute metadata
    // TODO Move TO GOOGLE SECRETS
    var metadata = (await KiwiContainer().resolve<compute.ComputeApi>().projects.get(googleCloudProjectId)).commonInstanceMetadata!;
    KiwiContainer().registerInstance(NyxxConfig.fromMetadata(metadata));
    KiwiContainer().registerInstance(TcgPlayerApiConfig.fromMetadata(metadata));

    // Register Storage Layer
    KiwiContainer().registerSingleton<Repository<CategoryInfoCache>>((container) => CloudStorageRepository<CategoryInfoCache>(
          objectFromJson: CategoryInfoCache.fromJson,
          compressionCodec: Utf8Codec().fuse(GZipCodec()),
          storageApi: container.resolve<storage.StorageApi>(),
          googleProjectId: googleCloudProjectId,
          documentName: "TcgPlayerProductCache",
        ));

    KiwiContainer().registerSingleton<Repository<ProductInfoCache>>((container) => FirestoreRepository<ProductInfoCache>(
          objectFromJson: ProductInfoCache.fromJson,
          compressionCodec: Utf8Codec().fuse(GZipCodec()).fuse(Base64Codec()),
          firestoreApi: container.resolve<firestore.FirestoreApi>(),
          googleProjectId: googleCloudProjectId,
          collectionId: "productsByGroup",
        ));

    KiwiContainer().registerSingleton<Repository<TcgPlayerAlertAction>>((container) => CloudStorageRepository<TcgPlayerAlertAction>(
          objectFromJson: TcgPlayerAlertAction.fromJson,
          compressionCodec: Utf8Codec(),
          storageApi: container.resolve<storage.StorageApi>(),
          googleProjectId: googleCloudProjectId,
          documentName: "TcgplayerAlertAction",
        ));

    KiwiContainer().registerSingleton<Repository<SkuPriceCache>>((container) => CloudStorageRepository<SkuPriceCache>(
          objectFromJson: SkuPriceCache.fromJson,
          compressionCodec: Utf8Codec().fuse(GZipCodec()),
          storageApi: container.resolve<storage.StorageApi>(),
          googleProjectId: googleCloudProjectId,
          documentName: "TcgplayerSkuPriceCache",
        ));

    KiwiContainer().registerSingleton((container) => TcgPlayerCachingClient(
          ProductCacheServiceLowMemory(
            productInfoCacheLifespan: const Duration(seconds: 10),
            inclusionRules: [
              InclusionRule(categoryMatch: RegExp(".+", caseSensitive: false)),
            ],
            tier2CategoryInfoCacheRepository: container.resolve<Repository<CategoryInfoCache>>(),
            tier2ProductInfoCacheRepository: container.resolve<Repository<ProductInfoCache>>(),
          ),
          PriceCacheService(),
        ));
  } else {
    // Get Keys from Local Files
    var localAppConfigFile = File("cardboard_bot/configs/app_config.yaml");
    var yamlDocument = loadYamlDocument(localAppConfigFile.readAsStringSync());
    KiwiContainer().registerInstance(NyxxConfig.fromYaml(yamlDocument));
    KiwiContainer().registerInstance(TcgPlayerApiConfig.fromYaml(yamlDocument));

    // Register Storage Layer
    KiwiContainer().registerSingleton<Repository<CategoryInfoCache>>((container) => LocalFileRepository<CategoryInfoCache>(
          objectFromJson: CategoryInfoCache.fromJson,
          compressionCodec: Utf8Codec().fuse(GZipCodec()),
          filePath: "cardboard_bot/data/tcgplayer/category_info_cache.gzip",
        ));

    KiwiContainer().registerSingleton<Repository<ProductInfoCache>>((container) => LocalFileRepository<ProductInfoCache>(
          objectFromJson: ProductInfoCache.fromJson,
          compressionCodec: Utf8Codec().fuse(GZipCodec()),
          filePath: "cardboard_bot/data/tcgplayer/product_info_cache.gzip",
        ));

    KiwiContainer().registerSingleton<Repository<TcgPlayerAlertAction>>((container) => LocalFileRepository<TcgPlayerAlertAction>(
          objectFromJson: TcgPlayerAlertAction.fromJson,
          compressionCodec: Utf8Codec().fuse(GZipCodec()),
          filePath: "cardboard_bot/data/actions/tcgplayer_alert.gzip",
        ));

    KiwiContainer().registerSingleton<Repository<SkuPriceCache>>((container) => LocalFileRepository<SkuPriceCache>(
          objectFromJson: SkuPriceCache.fromJson,
          compressionCodec: Utf8Codec().fuse(GZipCodec()),
          filePath: "cardboard_bot/data/tcgplayer/price_cache.gzip",
        ));

    KiwiContainer().registerSingleton((container) => TcgPlayerCachingClient(
          ProductCacheServiceHighMemory(
            inclusionRules: [
              InclusionRule(categoryMatch: RegExp(".+", caseSensitive: false)),
            ],
            tier2CategoryInfoCacheRepository: container.resolve<Repository<CategoryInfoCache>>(),
            tier2ProductInfoCacheRepository: container.resolve<Repository<ProductInfoCache>>(),
          ),
          PriceCacheService(),
        ));
  }

  ///////////////
  // Setup Nyxx Bot
  ////////////////
  INyxxWebsocket bot = NyxxFactory.createNyxxWebsocket(
    KiwiContainer().resolve<NyxxConfig>().token,
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
    publicKey: KiwiContainer().resolve<TcgPlayerApiConfig>().publicKey,
    privateKey: KiwiContainer().resolve<TcgPlayerApiConfig>().privateKey,
  );

  await CardboardBot.boot(
    bot: bot,
    interactions: interactions,
    tcgPlayerService: KiwiContainer().resolve<TcgPlayerCachingClient>(),
    tcgPlayerAlertActionService: TcgPlayerAlertActionService(
      bot,
      KiwiContainer().resolve<Repository<TcgPlayerAlertAction>>(),
      KiwiContainer().resolve<TcgPlayerCachingClient>(),
      KiwiContainer().resolve<Repository<SkuPriceCache>>(),
    ),
  );

  ///////////////////////
  // Sync Interactions
  ///////////////////////
  interactions.sync();
}
