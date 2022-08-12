import 'dart:convert';

import 'package:yaml/yaml.dart';
import 'package:googleapis/compute/v1.dart' as gce show Metadata;
import 'package:googleapis/secretmanager/v1.dart' as secret_manager show SecretManagerApi;

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

  static Future<TcgPlayerApiConfig> fromSecretManager(String googleProjectId, secret_manager.SecretManagerApi secretManagerApi) async {
    const secretName = "TcgplayerApiKey";
    var secret = await secretManagerApi.projects.secrets.versions.access("projects/$googleProjectId/secrets/$secretName/versions/latest");
    // secret.payload!.data is decoded incorrectly, so we decode it from bytes
    String string = String.fromCharCodes(secret.payload!.dataAsBytes);
    var json = jsonDecode(string) as Map<String, dynamic>;
    return TcgPlayerApiConfig(
      json["publicKey"] as String,
      json["privateKey"] as String,
    );
  }
}
