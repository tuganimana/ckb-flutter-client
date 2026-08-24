enum HashType {
  type,
  data,
  data1,
  data2;

  String get wireName {
    switch (this) {
      case HashType.type:
        return 'type';
      case HashType.data:
        return 'data';
      case HashType.data1:
        return 'data1';
      case HashType.data2:
        return 'data2';
    }
  }

  static HashType fromWire(String value) {
    switch (value) {
      case 'type':
        return HashType.type;
      case 'data':
        return HashType.data;
      case 'data1':
        return HashType.data1;
      case 'data2':
        return HashType.data2;
      default:
        throw FormatException('Unknown hash_type: $value');
    }
  }
}

enum ScriptType {
  lock,
  type;

  String get wireName => name;

  static ScriptType fromWire(String value) {
    switch (value) {
      case 'lock':
        return ScriptType.lock;
      case 'type':
        return ScriptType.type;
      default:
        throw FormatException('Unknown script_type: $value');
    }
  }
}

/// A CKB script (lock or type).
class CkbScript {
  const CkbScript({
    required this.codeHash,
    required this.hashType,
    required this.args,
  });

  factory CkbScript.fromJson(Map<String, dynamic> json) {
    return CkbScript(
      codeHash: json['code_hash'] as String,
      hashType: HashType.fromWire(json['hash_type'] as String),
      args: json['args'] as String,
    );
  }

  /// Default secp256k1 blake160 lock (CKB genesis).
  static const secp256k1Blake160CodeHash =
      '0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8';

  final String codeHash;
  final HashType hashType;
  final String args;

  /// Convenience constructor for a secp256k1-blake160 lock script.
  factory CkbScript.secp256k1Blake160(String args) {
    return CkbScript(
      codeHash: secp256k1Blake160CodeHash,
      hashType: HashType.type,
      args: args,
    );
  }

  Map<String, dynamic> toJson() => {
    'code_hash': codeHash,
    'hash_type': hashType.wireName,
    'args': args,
  };
}

enum SetScriptsCommand {
  all,
  partial,
  delete;

  String get wireName => name;
}

/// A script the light client should filter, plus the start block.
class ScriptStatus {
  const ScriptStatus({
    required this.script,
    required this.scriptType,
    required this.blockNumber,
  });

  factory ScriptStatus.fromJson(Map<String, dynamic> json) {
    return ScriptStatus(
      script: CkbScript.fromJson(json['script'] as Map<String, dynamic>),
      scriptType: ScriptType.fromWire(json['script_type'] as String),
      blockNumber: json['block_number'] as String,
    );
  }

  factory ScriptStatus.lock(CkbScript script, {String blockNumber = '0x0'}) {
    return ScriptStatus(
      script: script,
      scriptType: ScriptType.lock,
      blockNumber: blockNumber,
    );
  }

  final CkbScript script;
  final ScriptType scriptType;
  final String blockNumber;

  Map<String, dynamic> toJson() => {
    'script': script.toJson(),
    'script_type': scriptType.wireName,
    'block_number': blockNumber,
  };
}
