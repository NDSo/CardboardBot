extension UriExtension on Uri {
  String? toDiscordString() {
    return hasAbsolutePath ? toString() : null;
  }

  List<Uri> replicatePages({required String pageParam, int minPage = 1, required int maxPage}) {
    List<Uri> urls = [];
    for (int i = minPage; i <= maxPage; i++) {
      urls.add(
        replace(
          queryParameters: Map.of(queryParameters)
            ..update(
              pageParam,
              (value) => i.toString(),
              ifAbsent: () => i.toString(),
            ),
        ),
      );
    }
    return urls;
  }
}
