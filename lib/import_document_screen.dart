import 'package:flutter/material.dart';
import 'custom_document_handler.dart';

class ImportDocumentScreen extends StatefulWidget {
  const ImportDocumentScreen({Key? key}) : super(key: key);

  @override
  _ImportDocumentScreenState createState() => _ImportDocumentScreenState();
}

class _ImportDocumentScreenState extends State<ImportDocumentScreen> {
  bool _importando = false;
  bool _archivoSeleccionado = false;
  List<Map<String, dynamic>> _datosImportados = [];
  bool _mostrarVistaPrevia = false;

  // Seleccionar y cargar archivo
  Future<void> _seleccionarArchivo() async {
    try {
      setState(() {
        _importando = true;
        _archivoSeleccionado = false;
        _mostrarVistaPrevia = false;
        _datosImportados = [];
      });

      // Usar handler para importar documento
      final datos = await CustomDocumentHandler.importarDocumento();

      if (datos != null && datos.isNotEmpty) {
        setState(() {
          _datosImportados = datos;
          _archivoSeleccionado = true;
          _mostrarVistaPrevia = true;
        });
      } else if (datos != null) {
        // Archivo seleccionado pero sin datos
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo seleccionado no contiene datos válidos'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _archivoSeleccionado = true;
          _mostrarVistaPrevia = false;
        });
      } else {
        // Operación cancelada o error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operación cancelada o archivo no válido'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar el archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _importando = false;
      });
    }
  }

  // Importar los datos seleccionados
  Future<void> _importarDatos() async {
    if (_datosImportados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos para importar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _importando = true;
    });

    try {
      // Guardar datos importados
      final exito = await CustomDocumentHandler.guardarDatosImportados(_datosImportados);

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_datosImportados.length} registros importados exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Regresar a la pantalla anterior con resultado de éxito
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context, true);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar los datos'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _importando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar Documento'),
        centerTitle: true,
      ),
      body: _importando
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Procesando archivo...'),
          ],
        ),
      )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icono y título
          Icon(
            Icons.file_upload,
            size: 80,
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Importar Datos desde Archivo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Selecciona un archivo de respaldo (.suray) para restaurar sus datos en la aplicación',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Botón para seleccionar archivo
          ElevatedButton.icon(
            onPressed: _seleccionarArchivo,
            icon: const Icon(Icons.file_open),
            label: const Text('Seleccionar Archivo'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mostrar archivo seleccionado
          if (_archivoSeleccionado) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archivo seleccionado',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mostrarVistaPrevia ? 'Contiene ${_datosImportados.length} registros' : 'No contiene datos válidos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _mostrarVistaPrevia ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Vista previa de los datos
          if (_mostrarVistaPrevia && _datosImportados.isNotEmpty) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista previa de datos (${_datosImportados.length} registros):',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _datosImportados.length,
                        itemBuilder: (context, index) {
                          final maquina = _datosImportados[index];
                          return ListTile(
                            title: Text('${maquina['placa'] ?? 'Sin placa'} - ${maquina['modelo'] ?? 'Sin modelo'}'),
                            subtitle: Text('ID: ${maquina['id'] ?? 'Sin ID'}'),
                            leading: const Icon(Icons.directions_bus),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _importarDatos,
                    icon: const Icon(Icons.save),
                    label: const Text('Importar Datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}