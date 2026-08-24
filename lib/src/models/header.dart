import '../hex.dart';

/// Canonical chain header as returned by the light client.
class HeaderView {
  const HeaderView({
    required this.hash,
    required this.number,
    required this.parentHash,
    required this.timestamp,
    required this.epoch,
    required this.compactTarget,
    required this.dao,
    required this.nonce,
    required this.transactionsRoot,
    required this.extraHash,
    required this.proposalsHash,
    required this.version,
  });

  factory HeaderView.fromJson(Map<String, dynamic> json) {
    return HeaderView(
      hash: json['hash'] as String,
      number: json['number'] as String,
      parentHash: json['parent_hash'] as String,
      timestamp: json['timestamp'] as String,
      epoch: json['epoch'] as String,
      compactTarget: json['compact_target'] as String,
      dao: json['dao'] as String,
      nonce: json['nonce'] as String,
      transactionsRoot: json['transactions_root'] as String,
      extraHash: json['extra_hash'] as String,
      proposalsHash: json['proposals_hash'] as String,
      version: json['version'] as String,
    );
  }

  final String hash;
  final String number;
  final String parentHash;
  final String timestamp;
  final String epoch;
  final String compactTarget;
  final String dao;
  final String nonce;
  final String transactionsRoot;
  final String extraHash;
  final String proposalsHash;
  final String version;

  int get numberInt => parseHexUint(number);

  DateTime get timestampDate =>
      DateTime.fromMillisecondsSinceEpoch(parseHexUint(timestamp));

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'number': number,
    'parent_hash': parentHash,
    'timestamp': timestamp,
    'epoch': epoch,
    'compact_target': compactTarget,
    'dao': dao,
    'nonce': nonce,
    'transactions_root': transactionsRoot,
    'extra_hash': extraHash,
    'proposals_hash': proposalsHash,
    'version': version,
  };
}
