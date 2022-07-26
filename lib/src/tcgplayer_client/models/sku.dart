import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sku.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Sku extends ApiResult {
  final int skuId;
  final int productId;
  final int languageId;
  final int printingId;
  final int? conditionId;

  Sku({
    required this.skuId,
    required this.productId,
    required this.languageId,
    required this.printingId,
    required this.conditionId,
  });

  factory Sku.fromJson(Map<String, dynamic> json) => _$SkuFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$SkuToJson(this);
}
