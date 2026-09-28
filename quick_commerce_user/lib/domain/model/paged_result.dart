/// Uniform pagination envelope. The backend returns three different shapes
/// (flat total/page/limit, nested `meta`, or nothing at all) — mappers
/// normalise all of them into this.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  const PagedResult.single(this.items)
      : total = -1,
        page = 1,
        pageSize = -1;

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  /// No endpoint returns `hasMore`, so it is derived.
  bool get hasMore {
    if (total < 0 || pageSize <= 0) return false;
    return page * pageSize < total;
  }

  PagedResult<T> appending(PagedResult<T> next) => PagedResult(
        items: [...items, ...next.items],
        total: next.total,
        page: next.page,
        pageSize: next.pageSize,
      );

  static PagedResult<T> empty<T>() =>
      const PagedResult(items: [], total: 0, page: 1, pageSize: 0);
}
