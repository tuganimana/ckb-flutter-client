import 'dart:typed_data';

import '../hex.dart';
import '../models/cell.dart';
import 'address.dart';
import 'ckb_hash.dart';
import 'hd_wallet.dart';
import 'molecule.dart';
import 'secp256k1_sign.dart';

/// Genesis secp256k1-blake160 dep group (mainnet and testnet).
const secp256k1DepGroupTxHash =
    '0x71a7ba8fc96349fea0ed3a5c47992e3b4084b031a210b7b3509f637918d4df0f';

class CkbTransferException implements Exception {
  CkbTransferException(this.message);
  final String message;

  @override
  String toString() => 'CkbTransferException: $message';
}

class CkbSignedTransaction {
  const CkbSignedTransaction({required this.raw, required this.txHash});

  final Map<String, dynamic> raw;
  final String txHash;

  Map<String, dynamic> toJson() => raw;
}

/// Builds and signs a secp256k1-blake160 CKB transfer.
class CkbSecp256k1Transfer {
  CkbSecp256k1Transfer._();

  static const feeRateShannonsPerByte = 1000;

  static CkbSignedTransaction build({
    required CkbDerivedAccount from,
    required String toAddress,
    required int amountShannons,
    required List<IndexedCell> cells,
    int feeShannons = 0,
  }) {
    if (amountShannons <= 0) {
      throw CkbTransferException('Amount must be positive');
    }
    if (amountShannons < minCellCapacityShannons) {
      throw CkbTransferException(
        'Recipient needs at least ${shannonsToCkb(minCellCapacityShannons)} CKB',
      );
    }

    final to = CkbAddress.decode(toAddress);
    final spendable = cells.where(_isSpendableCkb).toList()
      ..sort(
        (a, b) =>
            b.output.capacityShannons.compareTo(a.output.capacityShannons),
      );
    if (spendable.isEmpty) {
      throw CkbTransferException('No spendable CKB cells for this lock');
    }

    final selected = <IndexedCell>[];
    var inputCapacity = 0;
    final tentativeFee = feeShannons > 0 ? feeShannons : 200000;
    final needed = amountShannons + tentativeFee;
    for (final cell in spendable) {
      selected.add(cell);
      inputCapacity += cell.output.capacityShannons;
      if (inputCapacity >= needed + minCellCapacityShannons ||
          inputCapacity >= needed &&
              inputCapacity - needed < minCellCapacityShannons) {
        break;
      }
    }

    var change = inputCapacity - amountShannons - tentativeFee;
    final hasChange = change >= minCellCapacityShannons;
    if (!hasChange) {
      change = 0;
    }
    if (inputCapacity < amountShannons + tentativeFee + (hasChange ? 0 : 0)) {
      throw CkbTransferException(
        'Insufficient balance: have ${shannonsToCkb(inputCapacity)} CKB',
      );
    }
    if (!hasChange && inputCapacity < amountShannons + tentativeFee) {
      throw CkbTransferException(
        'Insufficient balance after fee: have ${shannonsToCkb(inputCapacity)} CKB',
      );
    }

    var outputs = <CellOutput>[
      CellOutput(capacity: toHexUint(amountShannons), lock: to.script),
      if (hasChange) CellOutput(capacity: toHexUint(change), lock: from.lock),
    ];
    var outputsData = List<String>.filled(outputs.length, '0x');

    var unsigned = _rawJson(
      inputs: selected,
      outputs: outputs,
      outputsData: outputsData,
      witnesses: [
        bytesToHex(Molecule.witnessArgs(lock: List.filled(65, 0))),
        ...List.filled(selected.length - 1, '0x'),
      ],
    );
    var fee = feeShannons > 0 ? feeShannons : _estimateFee(unsigned);
    if (fee < 1000) fee = 1000;

    change = inputCapacity - amountShannons - fee;
    if (change > 0 && change < minCellCapacityShannons) {
      fee += change;
      change = 0;
    }
    if (inputCapacity < amountShannons + fee) {
      throw CkbTransferException(
        'Insufficient balance after fee: need ${shannonsToCkb(amountShannons + fee)} CKB',
      );
    }

    outputs = [
      CellOutput(capacity: toHexUint(amountShannons), lock: to.script),
      if (change >= minCellCapacityShannons)
        CellOutput(capacity: toHexUint(change), lock: from.lock),
    ];
    outputsData = List<String>.filled(outputs.length, '0x');
    final placeholderWitness = Molecule.witnessArgs(lock: List.filled(65, 0));
    final witnesses = [
      placeholderWitness,
      ...List<Uint8List>.generate(selected.length - 1, (_) => Uint8List(0)),
    ];

    unsigned = _rawJson(
      inputs: selected,
      outputs: outputs,
      outputsData: outputsData,
      witnesses: witnesses.map(bytesToHex).toList(),
    );
    final txHash = bytesToHex(_rawTxHash(selected, outputs, outputsData));
    final message = _signMessage(txHash, witnesses);
    final signature = signRecoverable(message, from.privateKey);
    final signedWitness = Molecule.witnessArgs(lock: signature);

    final raw = _rawJson(
      inputs: selected,
      outputs: outputs,
      outputsData: outputsData,
      witnesses: [
        bytesToHex(signedWitness),
        ...List.filled(selected.length - 1, '0x'),
      ],
    );
    return CkbSignedTransaction(raw: raw, txHash: txHash);
  }

  static bool _isSpendableCkb(IndexedCell cell) {
    if (cell.output.type != null) return false;
    final data = cell.outputData;
    return data == null || data == '0x' || data == '0X';
  }

  static int _estimateFee(Map<String, dynamic> tx) {
    final size = tx.toString().length + 16;
    return size * feeRateShannonsPerByte;
  }

  static Uint8List _rawTxHash(
    List<IndexedCell> inputs,
    List<CellOutput> outputs,
    List<String> outputsData,
  ) {
    return CkbHash.blake2b(_serializeRawTx(inputs, outputs, outputsData));
  }

  static Uint8List _signMessage(String txHash, List<Uint8List> witnesses) {
    final chunks = <int>[...hexToBytes(txHash)];
    for (final witness in witnesses) {
      chunks.addAll(Molecule.u64le(witness.length));
      chunks.addAll(witness);
    }
    return CkbHash.blake2b(chunks);
  }

  static Uint8List _serializeRawTx(
    List<IndexedCell> inputs,
    List<CellOutput> outputs,
    List<String> outputsData,
  ) {
    return Molecule.table([
      Molecule.u32le(0),
      Molecule.fixvec([_serializeCellDep()]),
      Molecule.fixvec(const []),
      Molecule.dynvec([
        for (final cell in inputs) _serializeInput(cell.outPoint),
      ]),
      Molecule.dynvec([for (final output in outputs) _serializeOutput(output)]),
      Molecule.dynvec([
        for (final data in outputsData) Molecule.bytes(hexToBytes(data)),
      ]),
    ]);
  }

  static Uint8List _serializeCellDep() {
    return Uint8List.fromList([
      ...hexToBytes(secp256k1DepGroupTxHash),
      ...Molecule.u32le(0),
      1, // dep_group
    ]);
  }

  static Uint8List _serializeInput(OutPoint outPoint) {
    return Molecule.table([
      Molecule.u64le(0),
      Uint8List.fromList([
        ...hexToBytes(outPoint.txHash),
        ...Molecule.u32le(parseHexUint(outPoint.index)),
      ]),
    ]);
  }

  static Uint8List _serializeOutput(CellOutput output) {
    return Molecule.table([
      Molecule.u64le(output.capacityShannons),
      Molecule.script(output.lock),
      Molecule.option(
        output.type == null ? null : Molecule.script(output.type!),
      ),
    ]);
  }

  static Map<String, dynamic> _rawJson({
    required List<IndexedCell> inputs,
    required List<CellOutput> outputs,
    required List<String> outputsData,
    required List<String> witnesses,
  }) {
    return {
      'version': '0x0',
      'cell_deps': [
        {
          'out_point': {'tx_hash': secp256k1DepGroupTxHash, 'index': '0x0'},
          'dep_type': 'dep_group',
        },
      ],
      'header_deps': <String>[],
      'inputs': [
        for (final cell in inputs)
          {'previous_output': cell.outPoint.toJson(), 'since': '0x0'},
      ],
      'outputs': [for (final output in outputs) output.toJson()],
      'outputs_data': outputsData,
      'witnesses': witnesses,
    };
  }
}
