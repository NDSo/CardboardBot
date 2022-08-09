import 'package:yaml/yaml.dart';
import 'package:googleapis/compute/v1.dart' as gce show Metadata;

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