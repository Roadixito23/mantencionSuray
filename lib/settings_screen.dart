import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'import_document_screen.dart';
import 'export_document_screen.dart';
import 'providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _datosImportados = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraciones'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de respaldo y restauración
          Text(
            'Respaldo y Restauración',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Importa o exporta datos para crear copias de seguridad',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),

          // Opción para importar
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.upload_file,
                color: Colors.green,
                size: 28,
              ),
              title: const Text('Importar Documento'),
              subtitle: const Text('Restaurar datos desde un archivo de respaldo'),
              trailing: Icon(Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              onTap: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportDocumentScreen(),
                  ),
                );

                if (resultado == true) {
                  setState(() {
                    _datosImportados = true;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Datos restaurados con éxito'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 8),

          // Opción para exportar
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.download,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              title: const Text('Exportar Documento'),
              subtitle: const Text('Crear una copia de seguridad de tus datos'),
              trailing: Icon(Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExportDocumentScreen(),
                  ),
                );
              },
            ),
          ),

          if (_datosImportados) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '¡Datos importados correctamente!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Configuraciones generales
          Text(
            'Configuraciones Generales',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Modo Oscuro'),
                  subtitle: Text(
                    isDarkMode
                        ? 'Activado - Tema oscuro para reducir el cansancio visual'
                        : 'Desactivado - Utilizando tema claro',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: isDarkMode,
                  secondary: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: isDarkMode ? Colors.amber : Colors.amber.shade700,
                  ),
                  onChanged: (bool value) {
                    themeProvider.setDarkMode(value);
                  },
                ),
                Divider(height: 1, thickness: 1, indent: 72, endIndent: 16),
                SwitchListTile(
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Recibir alertas sobre mantenimientos próximos'),
                  value: true,
                  secondary: Icon(
                    Icons.notifications_active,
                    color: theme.colorScheme.primary,
                  ),
                  onChanged: (bool value) {
                    // Implementar funcionalidad
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Acciones adicionales
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.restore,
                color: Colors.orange,
              ),
              title: const Text('Restablecer Configuraciones'),
              subtitle: const Text('Volver a la configuración predeterminada'),
              onTap: () {
                // Mostrar diálogo de confirmación
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Restablecer Configuraciones'),
                    content: const Text('¿Estás seguro de que deseas volver a la configuración predeterminada?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Restablecer configuraciones
                          themeProvider.setDarkMode(false);
                          Navigator.pop(context);

                          // Mostrar mensaje
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Configuraciones restablecidas'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text('Restablecer'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Información de la aplicación
          Text(
            'Información',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mantenimiento Buses Suray',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Versión 1.0.0'),
                  const SizedBox(height: 4),
                  Text(
                    'Aplicación para gestión de mantenimiento de flota de buses',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Añadir información adicional
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Desarrollado para Suray',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sistema profesional de gestión de mantenimiento de flotas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Contacto y soporte
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.contact_support,
                color: theme.colorScheme.secondary,
                size: 28,
              ),
              title: const Text('Soporte técnico'),
              subtitle: const Text('¿Necesitas ayuda? Contáctanos'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              onTap: () {
                // Implementar funcionalidad de contacto
              },
            ),
          ),
        ],
      ),
    );
  }
}