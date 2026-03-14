import 'package:flutter/material.dart';
import '../../domain/models/symbol_model.dart';
import '../../domain/repositories/i_context_repository.dart';
import '../../domain/repositories/i_symbol_repository.dart';

enum ContextState { scanning, analyzing, success, error, offline }

class ContextProvider extends ChangeNotifier {
  final IContextRepository _contextRepository;
  final ISymbolRepository _symbolRepository;
  
  String _currentRoom = "Loading Context...";
  ContextState _state = ContextState.scanning;
  String _errorMessage = "";
  List<SymbolModel> _currentSymbols = [];

  String get currentRoom => _currentRoom;
  ContextState get state => _state;
  String get errorMessage => _errorMessage;
  List<SymbolModel> get currentSymbols => _currentSymbols;

  // Static fallback symbols if AI is offline
  final List<SymbolModel> fallbackSymbols = const [
    SymbolModel(id: 'home', label: 'I want to go home', category: 'general'),
    SymbolModel(id: 'help', label: 'I need help', category: 'general'),
    SymbolModel(id: 'eat', label: 'I want food', category: 'needs'),
  ];

  ContextProvider({
    required IContextRepository contextRepository,
    required ISymbolRepository symbolRepository,
  }) : _contextRepository = contextRepository, 
       _symbolRepository = symbolRepository {
    _startContextLoop();
  }

  bool _isDisposed = false;

  Future<void> _startContextLoop() async {
    while (!_isDisposed) {
      await _analyzeCurrentContext();
      if (_isDisposed) break;
      await Future.delayed(const Duration(seconds: 15)); // Scan every 15s
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _analyzeCurrentContext() async {
    try {
      if (_state != ContextState.error) {
         _setState(ContextState.scanning);
      }
     
      final fingerprints = await _contextRepository.scanWifiNetworks();
      
      _setState(ContextState.analyzing);
      
      final room = await _contextRepository.determineCurrentRoom(fingerprints);
      
      if (room != null && room != "Unknown Context") {
        _currentRoom = room;
        _currentSymbols = await _symbolRepository.getSymbols(roomId: _currentRoom);
        await _contextRepository.saveRoomFingerprints(_currentRoom, fingerprints);
        _errorMessage = '';
        _setState(ContextState.success);
      } else {
        _currentRoom = "Unknown Room";
        _currentSymbols = fallbackSymbols;
        _errorMessage = "AI could not determine location.";
        _setState(ContextState.error);
      }
    } catch (e) {
      _errorMessage = "Offline. Using Fallback Board.";
      _currentSymbols = fallbackSymbols;
      _setState(ContextState.offline);
    }
  }

  Future<void> recordSymbolTap(SymbolModel symbol) async {
    try {
      await _symbolRepository.incrementUsageCount(symbol.id);
    } catch (e) {
      debugPrint('Unable to queue symbol tap for sync: $e');
    }
  }

  void _setState(ContextState newState) {
    if (_isDisposed) return;
    _state = newState;
    notifyListeners();
  }
}
