import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/maquinas_provider.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maquinasProvider = Provider.of<MaquinasProvider>(context);
    final theme = Theme.of(context);

    if (maquinasProvider.sincronizando) {
      return Tooltip(
        message: 'Sincronizando con Firebase...',
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sincronizando',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!maquinasProvider.hayConexion) {
      return GestureDetector(
        onTap: () => maquinasProvider.verificarConexion(),
        child: Tooltip(
          message: 'Sin conexión a Firebase. Toque para reintentar.',
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sin conexión',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Sincronizado con Firebase',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_done,
              color: Colors.green,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Sincronizado',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}