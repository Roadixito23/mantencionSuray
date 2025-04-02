import 'package:flutter/material.dart';
import 'import_document_screen.dart';
import 'export_document_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkModeEnabled = false;
  bool _datosImportados = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraciones'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de respaldo y restauración
          const Text(
            'Respaldo y Restauración',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Importa o exporta datos para crear copias de seguridad',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
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
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                color: Colors.blue,
                size: 28,
              ),
              title: const Text('Exportar Documento'),
              subtitle: const Text('Crear una copia de seguridad de tus datos'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
          const Text(
            'Configuraciones Generales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
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
                  subtitle: const Text('Cambiar la apariencia de la aplicación'),
                  value: _darkModeEnabled,
                  secondary: Icon(
                    _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                    color: _darkModeEnabled ? Colors.deepPurple : Colors.amber,
                  ),
                  onChanged: (bool value) {
                    setState(() {
                      _darkModeEnabled = value;
                    });
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
              leading: const Icon(Icons.restore, color: Colors.orange),
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
                          setState(() {
                            _darkModeEnabled = false;
                          });

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
          const Text(
            'Información',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
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
                children: const [
                  Text(
                    'Mantenimiento Buses Suray',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Versión 1.0.0'),
                  SizedBox(height: 4),
                  Text(
                    'Aplicación para gestión de mantenimiento de flota de buses',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}