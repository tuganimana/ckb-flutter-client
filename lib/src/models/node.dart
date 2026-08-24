import 'header.dart';

class NodeAddress {
  const NodeAddress({required this.address, required this.score});

  factory NodeAddress.fromJson(Map<String, dynamic> json) {
    return NodeAddress(
      address: json['address'] as String,
      score: json['score']?.toString() ?? '0x0',
    );
  }

  final String address;
  final String score;
}

class LocalNodeProtocol {
  const LocalNodeProtocol({
    required this.id,
    required this.name,
    required this.supportVersions,
  });

  factory LocalNodeProtocol.fromJson(Map<String, dynamic> json) {
    return LocalNodeProtocol(
      id: json['id']?.toString() ?? '0x0',
      name: json['name'] as String? ?? '',
      supportVersions: (json['support_versions'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final String id;
  final String name;
  final List<String> supportVersions;
}

class LocalNode {
  const LocalNode({
    required this.version,
    required this.nodeId,
    required this.active,
    required this.addresses,
    required this.protocols,
    required this.connections,
  });

  factory LocalNode.fromJson(Map<String, dynamic> json) {
    return LocalNode(
      version: json['version'] as String? ?? '',
      nodeId: json['node_id'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      addresses: (json['addresses'] as List<dynamic>? ?? [])
          .map((item) => NodeAddress.fromJson(item as Map<String, dynamic>))
          .toList(),
      protocols: (json['protocols'] as List<dynamic>? ?? [])
          .map(
            (item) => LocalNodeProtocol.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      connections: json['connections']?.toString() ?? '0x0',
    );
  }

  final String version;
  final String nodeId;
  final bool active;
  final List<NodeAddress> addresses;
  final List<LocalNodeProtocol> protocols;
  final String connections;
}

class RemoteNodeProtocol {
  const RemoteNodeProtocol({required this.id, required this.version});

  factory RemoteNodeProtocol.fromJson(Map<String, dynamic> json) {
    return RemoteNodeProtocol(
      id: json['id']?.toString() ?? '0x0',
      version: json['version'] as String? ?? '',
    );
  }

  final String id;
  final String version;
}

class RemoteNode {
  const RemoteNode({
    required this.version,
    required this.nodeId,
    required this.addresses,
    required this.connectedDuration,
    required this.protocols,
    this.syncState,
  });

  factory RemoteNode.fromJson(Map<String, dynamic> json) {
    return RemoteNode(
      version: json['version'] as String? ?? '',
      nodeId: json['node_id'] as String? ?? '',
      addresses: (json['addresses'] as List<dynamic>? ?? [])
          .map((item) => NodeAddress.fromJson(item as Map<String, dynamic>))
          .toList(),
      connectedDuration: json['connected_duration']?.toString() ?? '0x0',
      protocols: (json['protocols'] as List<dynamic>? ?? [])
          .map(
            (item) => RemoteNodeProtocol.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      syncState: json['sync_state'] == null
          ? null
          : json['sync_state'] as Map<String, dynamic>,
    );
  }

  final String version;
  final String nodeId;
  final List<NodeAddress> addresses;
  final String connectedDuration;
  final List<RemoteNodeProtocol> protocols;
  final Map<String, dynamic>? syncState;
}

/// Snapshot of light-client header sync progress.
class HeaderSyncStatus {
  const HeaderSyncStatus({
    required this.tip,
    required this.node,
    required this.peers,
  });

  final HeaderView tip;
  final LocalNode node;
  final List<RemoteNode> peers;

  int get peerCount => peers.length;
}
