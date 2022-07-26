import 'package:cardboard_bot/tcgplayer_client.dart';

class InclusionRule {
  RegExp categoryMatch;

  // Empty is ALL
  List<RegExp> groupMatch;

  InclusionRule({required this.categoryMatch, this.groupMatch = const []});

  bool matchCategory(Category category) {
    return categoryMatch.hasMatch(category.name) || categoryMatch.hasMatch(category.displayName) || categoryMatch.hasMatch(category.seoCategoryName);
  }

  bool matchGroup(Group group) {
    if (groupMatch.isEmpty) return true;
    return groupMatch.any((regExp) => regExp.hasMatch(group.name) || regExp.hasMatch(group.abbreviation ?? ""));
  }

  bool matchCategoryAndGroup(Category category, Group group) {
    return matchCategory(category) && matchGroup(group);
  }
}