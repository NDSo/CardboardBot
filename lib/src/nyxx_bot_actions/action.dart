import 'package:json_annotation/json_annotation.dart';
import 'package:nyxx/nyxx.dart';

@JsonSerializable(createFactory: false, createToJson: false)
abstract class Action {
  static int snowflakeToJson(Snowflake snowflake) => snowflake.id;
  static Snowflake snowflakeFromJson(int id) => Snowflake(id);
  @JsonKey(fromJson: snowflakeFromJson, toJson: snowflakeToJson)
  Snowflake ownerId;

  Action({required this.ownerId});

  String getId();

  Map<String, dynamic> toJson();
}
