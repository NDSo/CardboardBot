import 'package:nyxx/nyxx.dart';

extension SnowflakeExtension on Snowflake {
  String toJson() => id.toString();
  String toMention() => "<@!$id>";
}
