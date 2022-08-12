import 'dart:convert';

import 'package:yaml/yaml.dart';
import 'package:googleapis/compute/v1.dart' as gce show Metadata;
import 'package:googleapis/secretmanager/v1.dart' as secret_manager show SecretManagerApi;

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
    return NyxxConfig(metadata.items!.firstWhere((element) => element.key == "discord_bot_token").value!);
  }

  static Future<NyxxConfig> fromSecretManager(String googleProjectId, secret_manager.SecretManagerApi secretManagerApi) async {
    const secretName = "DiscordBotToken";
    var secret = await secretManagerApi.projects.secrets.versions.access("projects/$googleProjectId/secrets/$secretName/versions/latest");
    // secret.payload!.data is decoded incorrectly, so we decode it from bytes
    String string = String.fromCharCodes(secret.payload!.dataAsBytes);
    var json = jsonDecode(string) as Map<String, dynamic>;
    return NyxxConfig(
      json["token"] as String,
    );
  }
}
