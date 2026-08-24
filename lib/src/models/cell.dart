import '../hex.dart';
import 'script.dart';

class OutPoint {
  const OutPoint({required this.txHash, required this.index});

  factory OutPoint.fromJson(Map<String, dynamic> json) {
    return OutPoint(
      txHash: json['tx_hash'] as String,
      index: json['index'] as String,
    );
  }

  final String txHash;
  final String index;

  Map<String, dynamic> toJson() => {'tx_hash': txHash, 'index': index};
}

class CellOutput {
  const CellOutput({required this.capacity, required this.lock, this.type});

  factory CellOutput.fromJson(Map<String, dynamic> json) {
    return CellOutput(
      capacity: json['capacity'] as String,
      lock: CkbScript.fromJson(json['lock'] as Map<String, dynamic>),
      type: json['type'] == null
          ? null
          : CkbScript.fromJson(json['type'] as Map<String, dynamic>),
    );
  }

  final String capacity;
  final CkbScript lock;
  final CkbScript? type;

  int get capacityShannons => parseHexUint(capacity);

  Map<String, dynamic> toJson() => {
    'capacity': capacity,
    'lock': lock.toJson(),
    'type': type?.toJson(),
  };
}

class IndexedCell {
  const IndexedCell({
    required this.output,
    required this.outPoint,
    required this.blockNumber,
    required this.txIndex,
    this.outputData,
  });

  factory IndexedCell.fromJson(Map<String, dynamic> json) {
    return IndexedCell(
      output: CellOutput.fromJson(json['output'] as Map<String, dynamic>),
      outPoint: OutPoint.fromJson(json['out_point'] as Map<String, dynamic>),
      blockNumber: json['block_number'] as String,
      txIndex: json['tx_index'] as String,
      outputData: json['output_data'] as String?,
    );
  }

  final CellOutput output;
  final OutPoint outPoint;
  final String blockNumber;
  final String txIndex;
  final String? outputData;

  int get blockNumberInt => parseHexUint(blockNumber);
}

class CellsCapacity {
  const CellsCapacity({
    required this.capacity,
    required this.blockHash,
    required this.blockNumber,
  });

  factory CellsCapacity.fromJson(Map<String, dynamic> json) {
    return CellsCapacity(
      capacity: json['capacity'] as String,
      blockHash: json['block_hash'] as String,
      blockNumber: json['block_number'] as String,
    );
  }

  final String capacity;
  final String blockHash;
  final String blockNumber;

  int get capacityShannons => parseHexUint(capacity);

  /// Capacity in CKB (1 CKB = 10^8 shannons).
  double get capacityCkb => capacityShannons / 100000000;
}

class Pagination<T> {
  const Pagination({required this.objects, required this.lastCursor});

  factory Pagination.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) parse,
  ) {
    final objects = (json['objects'] as List<dynamic>)
        .map((item) => parse(item as Map<String, dynamic>))
        .toList();
    return Pagination(
      objects: objects,
      lastCursor: json['last_cursor'] as String? ?? '',
    );
  }

  final List<T> objects;
  final String lastCursor;

  bool get isEmpty => objects.isEmpty;
}
