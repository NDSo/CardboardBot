import 'package:cardboard_bot/nyxx_bot_actions.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nyxx/nyxx.dart';

part 'tcgplayer_alert_action.g.dart';

@JsonSerializable(ignoreUnannotated: true, constructor: "_")
class TcgPlayerAlertAction extends Action {
  @JsonKey()
  final int skuId;
  @JsonKey()
  final int productId;
  @JsonKey()
  final int groupId;
  @JsonKey()
  final int categoryId;
  @JsonKey()
  final num? maxPrice;

  TcgPlayerAlertAction._({
    required Snowflake ownerId,
    required this.skuId,
    required this.productId,
    required this.groupId,
    required this.categoryId,
    required this.maxPrice,
  }) : super(ownerId: ownerId);

  factory TcgPlayerAlertAction.create({
    required Snowflake ownerId,
    required int skuId,
    required int productId,
    required int groupId,
    required int categoryId,
    required num maxPrice,
  }) =>
      TcgPlayerAlertAction._(
        ownerId: ownerId,
        skuId: skuId,
        productId: productId,
        groupId: groupId,
        categoryId: categoryId,
        maxPrice: maxPrice,
      );

  factory TcgPlayerAlertAction.fromJson(Map<String, dynamic> json) => _$TcgPlayerAlertActionFromJson(json);

  @override
  String getId() {
    return "$ownerId|$skuId";
  }

  @override
  Map<String, dynamic> toJson() => _$TcgPlayerAlertActionToJson(this);
}
