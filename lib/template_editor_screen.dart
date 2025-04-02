import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({Key? key}) : super(key: key);

  @override
  _TemplateEditorScreenState createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _campos = [];
  bool _cargando = true;

  // Controlador para el nombre del nuevo campo
  final TextEditingController _nombreCampoController = TextEditingController();

  // Tipo de campo seleccionado para el nuevo campo
  String _tipoCampoSeleccionado = 'Texto';

  // Indica si el campo es obligatorio
  bool _campoObligatorio = false;

  @override
  void initState() {
    super.initState();
    _cargarPlantilla();
  }

  @override
  void dispose() {
    _nombreCampoController.dispose();
    super.dispose();
  }

  // Cargar la plantilla existente o crear una por defecto
  Future<void> _cargarPlantilla() async {
    setState(() {
      _cargando = true;
    });

    try {
      final file = await _localFile;
      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> camposJson = jsonDecode(contenido);
        setState(() {
          _campos = camposJson.cast<Map<String, dynamic>>();
        });
      } else {
        // Crear campos predeterminados
        setState(() {
          _campos = [
            {
              'id': 'maquina',
              'nombre': 'N°Maquina',
              'tipo': 'Texto',
              'obligatorio': true,
              'orden': 0,
            },
            {
              'id': 'patente',
              'nombre': 'Patente',
              'tipo': 'Texto',
              'obligatorio': true,
              'orden': 1,
            },
            {
              'id': 'capacidad',
              'nombre': 'Cantidad de Pasajeros',
              'tipo': 'Número',
              'obligatorio': true,
              'orden': 2,
            },
          ];
        });
        // Guardar plantilla predeterminada
        await _guardarPlantilla();
      }
    } catch (e) {
      print('Error al cargar plantilla: $e');
      // En caso de error, cargar campos predeterminados
      setState(() {
        _campos = [
          {
            'id': 'maquina',
            'nombre': 'N°Maquina',
            'tipo': 'Texto',
            'obligatorio': true,
            'orden': 0,
          },
          {
            'id': 'patente',
            'nombre': 'Patente',
            'tipo': 'Texto',
            'obligatorio': true,
            'orden': 1,
          },
          {
            'id': 'capacidad',
            'nombre': 'Cantidad de Pasajeros',
            'tipo': 'Número',
            'obligatorio': true,
            'orden': 2,
          },
        ];
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  // Obtener el archivo de plantilla
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/plantilla.json');
  }

  // Guardar la plantilla en el almacenamiento
  Future<void> _guardarPlantilla() async {
    try {
      final file = await _localFile;
      // Actualizar el orden de los campos
      for (int i = 0; i < _campos.length; i++) {
        _campos[i]['orden'] = i;
      }
      await file.writeAsString(jsonEncode(_campos));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plantilla guardada con éxito'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al guardar plantilla: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Agregar un nuevo campo a la plantilla
  void _agregarCampo() {
    if (_campos.length >= 23) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Has alcanzado el límite de 23 campos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_nombreCampoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes ingresar un nombre para el campo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generar un ID único basado en el nombre
    String id = _nombreCampoController.text
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    // Verificar si ya existe un campo con ese ID
    if (_campos.any((campo) => campo['id'] == id)) {
      // Agregar un sufijo numérico para hacerlo único
      int sufijo = 1;
      while (_campos.any((campo) => campo['id'] == '${id}_$sufijo')) {
        sufijo++;
      }
      id = '${id}_$sufijo';
    }

    setState(() {
      _campos.add({
        'id': id,
        'nombre': _nombreCampoController.text,
        'tipo': _tipoCampoSeleccionado,
        'obligatorio': _campoObligatorio,
        'orden': _campos.length,
      });

      // Limpiar controles
      _nombreCampoController.clear();
      _tipoCampoSeleccionado = 'Texto';
      _campoObligatorio = false;
    });
  }

  // Editar un campo existente
  void _editarCampo(int index) {
    final campo = _campos[index];

    TextEditingController editNombreController = TextEditingController(text: campo['nombre']);
    String editTipoCampo = campo['tipo'];
    bool editObligatorio = campo['obligatorio'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Campo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editNombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Campo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: editTipoCampo,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Campo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Texto', child: Text('Texto')),
                  DropdownMenuItem(value: 'Número', child: Text('Número')),
                  DropdownMenuItem(value: 'Fecha', child: Text('Fecha')),
                  DropdownMenuItem(value: 'Booleano', child: Text('Sí/No')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    editTipoCampo = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Campo Obligatorio'),
                value: editObligatorio,
                onChanged: (value) {
                  if (value != null) {
                    editObligatorio = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (editNombreController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre no puede estar vacío'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() {
                _campos[index]['nombre'] = editNombreController.text;
                _campos[index]['tipo'] = editTipoCampo;
                _campos[index]['obligatorio'] = editObligatorio;
              });

              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Eliminar un campo
  void _eliminarCampo(int index) {
    final campo = _campos[index];

    // Mostrar confirmación antes de eliminar
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Campo'),
        content: Text('¿Estás seguro de que deseas eliminar el campo "${campo['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _campos.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Mover un campo hacia arriba en la lista
  void _moverArriba(int index) {
    if (index > 0) {
      setState(() {
        final campo = _campos.removeAt(index);
        _campos.insert(index - 1, campo);
      });
    }
  }

  // Mover un campo hacia abajo en la lista
  void _moverAbajo(int index) {
    if (index < _campos.length - 1) {
      setState(() {
        final campo = _campos.removeAt(index);
        _campos.insert(index + 1, campo);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Plantilla'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Guardar Plantilla',
            onPressed: _guardarPlantilla,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Información sobre la plantilla
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración de Plantilla',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Campos actuales: ${_campos.length}/23',
                  style: TextStyle(
                    color: _campos.length >= 23 ? Colors.red : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Arrastra los campos para reordenarlos. Los campos con * son obligatorios.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Formulario para agregar nuevos campos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del campo
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nombreCampoController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Campo',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese un nombre';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Tipo de campo
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _tipoCampoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Texto', child: Text('Texto')),
                        DropdownMenuItem(value: 'Número', child: Text('Número')),
                        DropdownMenuItem(value: 'Fecha', child: Text('Fecha')),
                        DropdownMenuItem(value: 'Booleano', child: Text('Sí/No')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _tipoCampoSeleccionado = value;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Campo obligatorio
                  Expanded(
                    flex: 2,
                    child: CheckboxListTile(
                      title: const Text('Obligatorio'),
                      value: _campoObligatorio,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _campoObligatorio = value;
                          });
                        }
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  // Botón para agregar
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    color: Colors.green,
                    onPressed: _campos.length < 23 ? _agregarCampo : null,
                    tooltip: 'Agregar Campo',
                    iconSize: 40,
                  ),
                ],
              ),
            ),
          ),

          // Lista de campos actuales
          Expanded(
            child: ListView.builder(
              itemCount: _campos.length,
              itemBuilder: (context, index) {
                final campo = _campos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      campo['obligatorio']
                          ? '${campo['nombre']} *'
                          : campo['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Tipo: ${campo['tipo']} - ID: ${campo['id']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón para mover arriba
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: index > 0 ? () => _moverArriba(index) : null,
                          tooltip: 'Mover Arriba',
                        ),
                        // Botón para mover abajo
                        IconButton(
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: index < _campos.length - 1
                              ? () => _moverAbajo(index)
                              : null,
                          tooltip: 'Mover Abajo',
                        ),
                        // Botón para editar
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editarCampo(index),
                          tooltip: 'Editar Campo',
                        ),
                        // Botón para eliminar
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarCampo(index),
                          tooltip: 'Eliminar Campo',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade200,
        child: ElevatedButton(
          onPressed: () {
            _guardarPlantilla().then((_) {
              Navigator.pop(context);
            });
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Guardar y Salir', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}