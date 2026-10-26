class RecentSearchModel {
  final String id;
  final String query;
  final DateTime? searchedAt;

  const RecentSearchModel({
    required this.id,
    required this.query,
    this.searchedAt,
  });

  factory RecentSearchModel.fromMap(Map<String, dynamic> map) {
    return RecentSearchModel(
      id: map['id']?.toString() ?? '',
      query: map['query']?.toString() ?? '',
      searchedAt: DateTime.tryParse(map['searched_at']?.toString() ?? ''),
    );
  }
}
