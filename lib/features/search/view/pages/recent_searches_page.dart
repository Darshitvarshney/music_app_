import 'package:flutter/material.dart';
import '../../../../core/services/recent_searches_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../model/recent_search_model.dart';
import 'search_page.dart';

class RecentSearchesPage extends StatefulWidget {
  const RecentSearchesPage({super.key});

  @override
  State<RecentSearchesPage> createState() => _RecentSearchesPageState();
}

class _RecentSearchesPageState extends State<RecentSearchesPage> {
  final RecentSearchesService _service = RecentSearchesService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _service.fetch();
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    // Synchronous on purpose: a swiped-away Dismissible must leave the tree in the same frame.
    if (mounted) setState(() {});
  }

  void _openSearch(RecentSearchModel search) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchPage(initialQuery: search.query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searches = _service.searches;

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Pallete.whiteColor,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Recent Searches',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Pallete.whiteColor,
                      ),
                    ),
                  ),
                  if (searches.isNotEmpty)
                    TextButton(
                      onPressed: _service.clear,
                      child: const Text(
                        'Clear all',
                        style: TextStyle(color: Pallete.subtitleText),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody(searches)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<RecentSearchModel> searches) {
    if (_service.isLoading && searches.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Pallete.gradient2),
      );
    }

    if (searches.isEmpty) {
      final error = _service.errorMessage;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error != null ? Icons.wifi_off_rounded : Icons.history_rounded,
              color: error != null ? Pallete.errorColor : Pallete.subtitleText,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              error ?? 'No recent searches yet',
              style: const TextStyle(
                color: Pallete.whiteColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error != null
                  ? 'Pull down to try again.'
                  : 'Songs you search for will show up here.',
              style: const TextStyle(color: Pallete.subtitleText, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Pallete.gradient2,
      backgroundColor: Pallete.cardColor,
      onRefresh: _service.fetch,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: searches.length,
        itemBuilder: (context, index) {
          final search = searches[index];
          return Dismissible(
            key: ValueKey(search.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Pallete.errorColor,
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            onDismissed: (_) => _service.remove(search),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.history_rounded,
                color: Pallete.subtitleText,
              ),
              title: Text(
                search.query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Pallete.whiteColor),
              ),
              trailing: const Icon(
                Icons.north_west_rounded,
                color: Pallete.subtitleText,
                size: 18,
              ),
              onTap: () => _openSearch(search),
            ),
          );
        },
      ),
    );
  }
}
