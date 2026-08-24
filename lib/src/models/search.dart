import 'script.dart';

enum Order {
  asc,
  desc;

  String get wireName => name;
}

enum ScriptSearchMode {
  prefix,
  exact;

  String get wireName => name;
}

class SearchKeyFilter {
  const SearchKeyFilter({
    this.script,
    this.scriptLenRange,
    this.outputDataLenRange,
    this.outputCapacityRange,
    this.blockRange,
  });

  final CkbScript? script;
  final List<String>? scriptLenRange;
  final List<String>? outputDataLenRange;
  final List<String>? outputCapacityRange;
  final List<String>? blockRange;

  Map<String, dynamic> toJson() {
    return {
      if (script != null) 'script': script!.toJson(),
      if (scriptLenRange != null) 'script_len_range': scriptLenRange,
      if (outputDataLenRange != null)
        'output_data_len_range': outputDataLenRange,
      if (outputCapacityRange != null)
        'output_capacity_range': outputCapacityRange,
      if (blockRange != null) 'block_range': blockRange,
    };
  }
}

class SearchKey {
  const SearchKey({
    required this.script,
    required this.scriptType,
    this.scriptSearchMode,
    this.filter,
    this.withData,
    this.groupByTransaction,
  });

  factory SearchKey.byLock(
    CkbScript lock, {
    bool withData = false,
    ScriptSearchMode? scriptSearchMode,
    SearchKeyFilter? filter,
  }) {
    return SearchKey(
      script: lock,
      scriptType: ScriptType.lock,
      scriptSearchMode: scriptSearchMode,
      filter: filter,
      withData: withData,
    );
  }

  final CkbScript script;
  final ScriptType scriptType;
  final ScriptSearchMode? scriptSearchMode;
  final SearchKeyFilter? filter;
  final bool? withData;
  final bool? groupByTransaction;

  Map<String, dynamic> toJson() {
    return {
      'script': script.toJson(),
      'script_type': scriptType.wireName,
      if (scriptSearchMode != null)
        'script_search_mode': scriptSearchMode!.wireName,
      if (filter != null) 'filter': filter!.toJson(),
      if (withData != null) 'with_data': withData,
      if (groupByTransaction != null)
        'group_by_transaction': groupByTransaction,
    };
  }
}
