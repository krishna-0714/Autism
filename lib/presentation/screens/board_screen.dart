import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/context_provider.dart';
import '../../domain/models/symbol_model.dart';

class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutiConnect AAC Board'),
        elevation: 0,
        backgroundColor: Colors.blueAccent, // Avoided Purple per design rules
      ),
      body: Consumer<ContextProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildStatusBar(provider),
              Expanded(
                child: _buildSymbolGrid(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(ContextProvider provider) {
    Color statusColor;
    IconData statusIcon;

    switch (provider.state) {
      case ContextState.scanning:
      case ContextState.analyzing:
        statusColor = Colors.orange;
        statusIcon = Icons.wifi_find;
        break;
      case ContextState.success:
        statusColor = Colors.green;
        statusIcon = Icons.location_on;
        break;
      case ContextState.error:
      case ContextState.offline:
        statusColor = Colors.redAccent;
        statusIcon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: statusColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (provider.state == ContextState.offline || provider.state == ContextState.error)
                  ? provider.errorMessage 
                  : "Location: ${provider.currentRoom}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          if (provider.state == ContextState.scanning || provider.state == ContextState.analyzing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
        ],
      ),
    );
  }

  Widget _buildSymbolGrid(ContextProvider provider) {
    // If AI is unavailable, default to static fallback symbols to ensure user safety.
    // Otherwise, use the dynamically loaded symbols from SQLite.
    final symbols = (provider.state == ContextState.offline || provider.state == ContextState.error)
        ? provider.fallbackSymbols
        : provider.currentSymbols;

    if (symbols.isEmpty) {
      return const Center(
        child: Text(
          'No symbols available yet.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Large buttons for accessibility
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        return _SymbolCard(symbol: symbol);
      },
    );
  }
}

class _SymbolCard extends StatelessWidget {
  final SymbolModel symbol;

  const _SymbolCard({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.read<ContextProvider>().recordSymbolTap(symbol);

        // Text-to-speech integration would fire here
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: ${symbol.label}')),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, size: 64, color: Colors.amber), // Replace with NetworkImage
            const SizedBox(height: 16),
            Text(
              symbol.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
