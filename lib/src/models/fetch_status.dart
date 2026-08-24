enum FetchState { added, fetching, fetched, notFound }

/// Status of a remote `fetch_header` / `fetch_transaction` request.
class FetchStatus<T> {
  const FetchStatus._({
    required this.status,
    this.data,
    this.timestamp,
    this.firstSent,
  });

  factory FetchStatus.fetched(T data) =>
      FetchStatus._(status: FetchState.fetched, data: data);

  factory FetchStatus.fetching(String firstSent) =>
      FetchStatus._(status: FetchState.fetching, firstSent: firstSent);

  factory FetchStatus.added(String timestamp) =>
      FetchStatus._(status: FetchState.added, timestamp: timestamp);

  factory FetchStatus.notFound() =>
      const FetchStatus._(status: FetchState.notFound);

  factory FetchStatus.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) parse,
  ) {
    switch (json['status']) {
      case 'fetched':
        return FetchStatus.fetched(parse(json['data'] as Map<String, dynamic>));
      case 'fetching':
        return FetchStatus.fetching(json['first_sent'] as String);
      case 'added':
        return FetchStatus.added(json['timestamp'] as String);
      case 'not_found':
        return FetchStatus.notFound();
      default:
        throw FormatException('Unknown fetch status: ${json['status']}');
    }
  }

  final FetchState status;
  final T? data;
  final String? timestamp;
  final String? firstSent;

  bool get isFetched => status == FetchState.fetched;
}
