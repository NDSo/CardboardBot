import 'dart:math';

import 'package:nyxx/nyxx.dart';

extension EmbedMessageCopy on IEmbed {
  EmbedBuilder copy() {
    return EmbedBuilder()
      ..title = title
      ..type = type
      ..description = description
      ..url = url
      ..timestamp = timestamp
      ..color = color
      ..thumbnailUrl = thumbnail?.url;
  }
}

extension EmbedBuilderExtension on EmbedBuilder {
  static final int _maxTitle = 256;
  static final int _maxDescription = 4096;
  static final int _maxFields = 25;
  static final int _maxFieldName = 256;
  static final int _maxFieldValue = 1024;
  static final int _maxFooterText = 2048;
  static final int _maxAuthorName = 256;
  static final int _maxCombinedLength = 6000; // title, description, field.name, field.value, footer.text, and author.name

  int getCombinedLength() {
    int combined = (title?.length ?? 0) +
        (description?.length ?? 0) +
        fields.fold<int>(
            0, (previousValue, element) => previousValue + ((element.name as String?)?.length ?? 0) + ((element.content as String?)?.length ?? 0)) +
        (footer?.text?.length ?? 0) +
        (author?.name?.length ?? 0);
    return combined;
  }

  void trimToMaxLength() {
    // Trim each to max size
    title = title?.substring(0, min(_maxTitle, title!.length));
    description = description?.substring(0, min(_maxDescription, description!.length));
    fields = fields.sublist(0, min(_maxFields, fields.length));
    for (var field in fields) {
      (field.name as String).substring(0, min(_maxFieldName, (field.name as String).length));
    }
    for (var field in fields) {
      (field.content as String).substring(0, min(_maxFieldValue, (field.content as String).length));
    }
    if (footer != null) footer!.text = footer!.text?.substring(0, min(_maxFooterText, footer!.text!.length));
    if (author != null) author!.name = author!.name?.substring(0, min(_maxAuthorName, author!.name!.length));

    // Trim description by total combined adjustment
    int adjustment = _maxCombinedLength - getCombinedLength();

    description = description?.substring(0, min(description!.length + adjustment, description!.length));
  }

  static List<List<EmbedBuilder>> toChunksOfMaxLength(Iterable<EmbedBuilder> embeds) {
    List<List<EmbedBuilder>> chunks = [];
    List<EmbedBuilder> thisList = List.of(embeds);

    // Trim individual
    for (var element in thisList) {
      element.trimToMaxLength();
    }

    // Create Max Chunks
    for (EmbedBuilder embed in thisList) {
      if (chunks.isEmpty ||
          chunks.last.length >= 10 ||
          embed.getCombinedLength() +
                  chunks.last.fold(
                    0,
                    (previousValue, element) => previousValue + element.getCombinedLength(),
                  ) >
              _maxCombinedLength) chunks.add([]);
      chunks.last.add(embed);
    }

    return chunks;
  }
}

extension EmbedBuilderList on Iterable<EmbedBuilder> {
  List<List<EmbedBuilder>> toChunksOfMaxLength() {
    return EmbedBuilderExtension.toChunksOfMaxLength(this);
  }
}
