import '../abstracts/api_result.dart';
import 'package:json_annotation/json_annotation.dart';

part 'printing.g.dart';

@JsonSerializable(ignoreUnannotated: false)
class Printing extends ApiResult {
  int printingId;
  String name;
  int displayOrder;
  DateTime modifiedOn;

  Printing({
    required this.printingId,
    required this.name,
    required this.displayOrder,
    required this.modifiedOn,
  });

  factory Printing.fromJson(Map<String, dynamic> json) => _$PrintingFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PrintingToJson(this);
}
