import 'package:yaml/yaml.dart';
import 'package:googleapis/compute/v1.dart' as gce show Metadata;

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
}