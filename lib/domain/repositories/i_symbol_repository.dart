import '../models/symbol_model.dart';

abstract class ISymbolRepository {
  Future<List<SymbolModel>> getSymbols({String? category, String? roomId});
  Future<SymbolModel?> getSymbolById(String id);
  Future<void> addSymbol(SymbolModel symbol);
  Future<void> updateSymbol(SymbolModel symbol);
  Future<void> deleteSymbol(String id);
  Future<void> incrementUsageCount(String id);
}
