/// Error talking to a CKB light-client JSON-RPC endpoint.
class CkbRpcException implements Exception {
  CkbRpcException(this.message, {this.code, this.data, this.statusCode});

  factory CkbRpcException.http(int statusCode, String body) {
    return CkbRpcException(
      'HTTP $statusCode from light-client RPC',
      statusCode: statusCode,
      data: body,
    );
  }

  factory CkbRpcException.fromRpc(Object? error) {
    if (error is Map<String, dynamic>) {
      return CkbRpcException(
        error['message']?.toString() ?? 'RPC error',
        code: error['code'] is int ? error['code'] as int : null,
        data: error['data'],
      );
    }
    return CkbRpcException(error.toString());
  }

  final String message;
  final int? code;
  final Object? data;
  final int? statusCode;

  bool get isMethodNotFound {
    final lowered = message.toLowerCase();
    return code == -32601 || code == -3 || lowered.contains('method not found');
  }

  @override
  String toString() {
    final buffer = StringBuffer('CkbRpcException: $message');
    if (code != null) buffer.write(' (code $code)');
    if (statusCode != null) buffer.write(' [HTTP $statusCode]');
    return buffer.toString();
  }
}
