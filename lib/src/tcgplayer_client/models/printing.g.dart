// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Printing _$PrintingFromJson(Map<String, dynamic> json) => Printing(
      printingId: json['printingId'] as int,
      name: json['name'] as String,
      displayOrder: json['displayOrder'] as int,
      modifiedOn: DateTime.parse(json['modifiedOn'] as String),
    );

Map<String, dynamic> _$PrintingToJson(Printing instance) => <String, dynamic>{
      'printingId': instance.printingId,
      'name': instance.name,
      'displayOrder': instance.displayOrder,
      'modifiedOn': instance.modifiedOn.toIso8601String(),
    };
