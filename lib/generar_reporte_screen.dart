import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class GenerarReporteScreen extends StatefulWidget {
  const GenerarReporteScreen({Key? key}) : super(key: key);

  @override
  _GenerarReporteScreenState createState() => _GenerarReporteScreenState();
}

enum TipoFiltro {
  todas,
  proximas,
  vencidas,
  activas,
  enMantenimiento,
  fueraDeServicio
}

class _GenerarReporteScreenState extends State<GenerarReporteScreen> {
  List<Map<String, dynamic>> _maquinas = [];
  List<Map<String, dynamic>> _maquinasFiltradas = [];
  bool _cargando = true;

  // Lista para controlar los estados de expansión
  List<bool> _expandedList = [];
  TipoFiltro _filtroActual = TipoFiltro.todas;

  // Colores estándar
  final Color _colorPrimario = Colors.blue;
  final Color _colorAlerta = Colors.red;
  final Color _colorTextoSecundario = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _cargarMaquinas();
  }

  Future<void> _cargarMaquinas() async {
    setState(() { _cargando = true; });
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/maquinas.json');

      if (await file.exists()) {
        final contenido = await file.readAsString();
        final List<dynamic> maquinasJson = jsonDecode(contenido);
        setState(() {
          _maquinas = maquinasJson.cast<Map<String, dynamic>>();

          // Aplicar filtro actual
          _aplicarFiltro();
        });
      }
    } catch (e) {
      print('Error al cargar máquinas: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: _colorAlerta),
      );
    }
    setState(() { _cargando = false; });
  }

  // Función para aplicar el filtro seleccionado
  void _aplicarFiltro() {
    switch (_filtroActual) {
      case TipoFiltro.todas:
        _maquinasFiltradas = List.from(_maquinas);
        break;
      case TipoFiltro.proximas:
        _maquinasFiltradas = _maquinas.where((maquina) {
          final dias = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
          // Solo máquinas con días restantes positivos (aún no vencidas)
          return dias != null && dias > 0 && dias <= 30;
        }).toList();
        break;
      case TipoFiltro.vencidas:
        _maquinasFiltradas = _maquinas.where((maquina) {
          final dias = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
          // Máquinas con 0 días o menos (vencidas hoy o en el pasado)
          return dias != null && dias <= 0;
        }).toList();
        break;
      case TipoFiltro.activas:
        _maquinasFiltradas = _maquinas.where((maquina) =>
        maquina['estado'] == 'Activo'
        ).toList();
        break;
      case TipoFiltro.enMantenimiento:
        _maquinasFiltradas = _maquinas.where((maquina) =>
        maquina['estado'] == 'En Taller'
        ).toList();
        break;
      case TipoFiltro.fueraDeServicio:
        _maquinasFiltradas = _maquinas.where((maquina) =>
        maquina['estado'] == 'Fuera de Servicio'
        ).toList();
        break;
    }

    // Reiniciar estados de expansión para el nuevo conjunto filtrado
    _expandedList = List.generate(_maquinasFiltradas.length, (_) => false);
  }

  // Función para cambiar el filtro actual
  void _cambiarFiltro(TipoFiltro nuevoFiltro) {
    setState(() {
      _filtroActual = nuevoFiltro;
      _aplicarFiltro();
    });
  }

  // Formatear fecha para mostrar
  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) {
      return 'No registrada';
    }
    try {
      final DateTime fecha = DateTime.parse(fechaIso);
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  // Calcular días restantes para la revisión técnica
  int? _calcularDiasRestantes(String? fechaIso) {
    if (fechaIso == null) {
      return null;
    }
    try {
      final DateTime fechaRevision = DateTime.parse(fechaIso);
      final DateTime ahora = DateTime.now();
      final diferencia = fechaRevision.difference(ahora);
      return diferencia.inDays;
    } catch (e) {
      return null;
    }
  }

  // Función para mostrar la información de días restantes
  Widget _buildDiasRestantes(int? dias) {
    if (dias == null) {
      return Text(
        'Sin fecha programada',
        style: TextStyle(
          color: _colorTextoSecundario,
          fontSize: 12,
        ),
      );
    }

    String textoMostrar;
    Color colorTexto;

    if (dias < 0) {
      // Ya vencido hace días
      textoMostrar = 'Vencido hace ${-dias} días';
      colorTexto = _colorAlerta;
    } else if (dias == 0) {
      // Vencido hoy
      textoMostrar = 'Vence hoy';
      colorTexto = _colorAlerta;
    } else if (dias <= 30) {
      // Próximo a vencer
      textoMostrar = 'Faltan $dias días';
      colorTexto = Colors.orange;
    } else {
      // Normal
      textoMostrar = 'Faltan $dias días';
      colorTexto = Colors.green;
    }

    return Text(
      textoMostrar,
      style: TextStyle(
        color: colorTexto,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  // Ver una foto en pantalla completa
  void _verFoto(String fotoPath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Visualizar Foto'),
            backgroundColor: _colorPrimario,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                File(fotoPath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 80, color: _colorTextoSecundario),
                      const SizedBox(height: 16),
                      Text('No se pudo cargar la imagen', style: TextStyle(color: _colorTextoSecundario)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isHorizontal = mediaQuery.size.width > mediaQuery.size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Máquinas'),
        centerTitle: true,
        backgroundColor: _colorPrimario,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: _colorPrimario))
          : _maquinas.isEmpty
          ? const Center(child: Text('No hay máquinas registradas.'))
          : isHorizontal
          ? _buildHorizontalLayout()
          : _buildVerticalLayout(),
    );
  }

  // Diseño horizontal para Windows
  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        // Panel lateral con filtros y opciones
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtros de Reporte',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _colorPrimario,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Utilice estas opciones para filtrar la información del reporte',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Opciones de filtrado - Estado del mantenimiento
              ListTile(
                leading: Icon(Icons.directions_bus, color: _colorPrimario),
                title: const Text('Todas las máquinas'),
                selected: _filtroActual == TipoFiltro.todas,
                selectedTileColor: _colorPrimario.withOpacity(0.1),
                onTap: () {
                  _cambiarFiltro(TipoFiltro.todas);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: const Text('Próximas a vencer (1-30 días)'),
                selected: _filtroActual == TipoFiltro.proximas,
                selectedTileColor: Colors.orange.withOpacity(0.1),
                onTap: () {
                  _cambiarFiltro(TipoFiltro.proximas);
                },
              ),
              ListTile(
                leading: Icon(Icons.dangerous, color: _colorAlerta),
                title: const Text('Vencidas (hoy o antes)'),
                selected: _filtroActual == TipoFiltro.vencidas,
                selectedTileColor: _colorAlerta.withOpacity(0.1),
                onTap: () {
                  _cambiarFiltro(TipoFiltro.vencidas);
                },
              ),

              const Divider(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Estado de operación',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              // Opciones de filtrado - Estado de operación
              ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Activas'),
                selected: _filtroActual == TipoFiltro.activas,
                selectedTileColor: Colors.green.withOpacity(0.1),
                onTap: () {
                  _cambiarFiltro(TipoFiltro.activas);
                },
              ),
              ListTile(
                leading: Icon(Icons.engineering, color: Colors.amber),
                title: const Text('En Taller'),
                selected: _filtroActual == TipoFiltro.enMantenimiento,
                selectedTileColor: Colors.amber.withOpacity(0.1),
                onTap: () {
                  _cambiarFiltro(TipoFiltro.enMantenimiento);
                },
              ),
              ListTile(
                leading: Icon(Icons.do_not_disturb_on, color: Colors.grey),
                title: const Text('Fuera de Servicio'),
                selected: _filtroActual == TipoFiltro.fueraDeServicio,
                selectedTileColor: Colors.grey.withOpacity(0.1),
                onTap: () {
                  _cambiarFiltro(TipoFiltro.fueraDeServicio);
                },
              ),

              const Divider(height: 1),

              // Estadísticas rápidas
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estadísticas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colorPrimario,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      Icons.directions_bus,
                      'Total de Máquinas',
                      _maquinas.length.toString(),
                      _colorPrimario,
                    ),
                    const SizedBox(height: 8),
                    _buildStatCard(
                      Icons.warning,
                      'Próximas a vencer',
                      _maquinas.where((m) {
                        final dias = _calcularDiasRestantes(m['fechaRevisionTecnica']);
                        return dias != null && dias > 0 && dias <= 30;
                      }).length.toString(),
                      Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildStatCard(
                      Icons.dangerous,
                      'Vencidas',
                      _maquinas.where((m) {
                        final dias = _calcularDiasRestantes(m['fechaRevisionTecnica']);
                        return dias != null && dias <= 0;
                      }).length.toString(),
                      _colorAlerta,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Estado de operación',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _colorPrimario,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildStatCard(
                      Icons.check_circle,
                      'Activas',
                      _maquinas.where((m) => m['estado'] == 'Activo').length.toString(),
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildStatCard(
                      Icons.engineering,
                      'En Taller',
                      _maquinas.where((m) => m['estado'] == 'En Taller').length.toString(),
                      Colors.amber,
                    ),
                    const SizedBox(height: 8),
                    _buildStatCard(
                      Icons.do_not_disturb_on,
                      'Fuera de Servicio',
                      _maquinas.where((m) => m['estado'] == 'Fuera de Servicio').length.toString(),
                      Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista de máquinas (panel principal)
        Expanded(
          child: _maquinasFiltradas.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _filtroActual == TipoFiltro.proximas ? Icons.warning :
                    _filtroActual == TipoFiltro.vencidas ? Icons.dangerous : Icons.search,
                    size: 64,
                    color: Colors.grey.shade400
                ),
                const SizedBox(height: 16),
                Text(
                  _filtroActual == TipoFiltro.todas
                      ? 'No hay máquinas registradas'
                      : 'No hay máquinas que coincidan con el filtro',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _maquinasFiltradas.length,
            itemBuilder: (context, index) {
              final maquina = _maquinasFiltradas[index];
              final diasRestantes = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
              final bool hayAlerta = diasRestantes != null && diasRestantes >= 0 && diasRestantes <= 30;
              final bool tieneComentarios = maquina['comentario'] != null &&
                  maquina['comentario'].toString().isNotEmpty;
              final List<String> fotos = maquina['imagenMaquina'] != null ?
              [maquina['imagenMaquina']] : [];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: hayAlerta ? _colorAlerta.withOpacity(0.5) : Colors.transparent,
                    width: hayAlerta ? 1 : 0,
                  ),
                ),
                child: Column(
                  children: [
                    // Parte principal siempre visible
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: hayAlerta ? _colorAlerta.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: const Radius.circular(8),
                          bottom: _expandedList[index] ? Radius.zero : const Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado con información principal
                          Row(
                            children: [
                              // Icono de máquina
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (maquina['estado'] == 'Activo' ? _colorPrimario : Colors.orange).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.directions_bus,
                                  color: maquina['estado'] == 'Activo' ? _colorPrimario : Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Información principal
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          maquina['patente'] ?? 'Sin patente',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: maquina['estado'] == 'Activo'
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: maquina['estado'] == 'Activo'
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                          child: Text(
                                            maquina['estado'] ?? 'Sin estado',
                                            style: TextStyle(
                                              color: maquina['estado'] == 'Activo'
                                                  ? Colors.green
                                                  : Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Modelo: ${maquina['modelo']}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'ID: ${maquina['id']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _colorTextoSecundario,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Revisión técnica con alerta
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Revisión Técnica:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: hayAlerta ? _colorAlerta : _colorPrimario,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatearFecha(maquina['fechaRevisionTecnica']),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: hayAlerta ? _colorAlerta : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildDiasRestantes(diasRestantes),
                                ],
                              ),
                            ],
                          ),

                          // Botón para expandir/colapsar
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _expandedList[index] = !_expandedList[index];
                                });
                              },
                              icon: Icon(
                                _expandedList[index]
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                              ),
                              label: Text(
                                _expandedList[index] ? 'Menos detalles' : 'Más detalles',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: _colorTextoSecundario,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sección expandible
                    if (_expandedList[index])
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Información adicional
                            Row(
                              children: [
                                _buildInfoField(
                                  'Capacidad',
                                  '${maquina['capacidad'] ?? 0} pasajeros',
                                  Icons.people,
                                ),
                                const SizedBox(width: 24),
                                _buildInfoField(
                                  'Kilometraje',
                                  '${maquina['kilometraje'] ?? 0} km',
                                  Icons.speed,
                                ),
                                if (maquina['vin'] != null && maquina['vin'].toString().isNotEmpty) ...[
                                  const SizedBox(width: 24),
                                  _buildInfoField(
                                    'Número VIN',
                                    maquina['vin'] ?? '',
                                    Icons.numbers,
                                  ),
                                ],
                              ],
                            ),

                            // Comentarios e imagen
                            if (tieneComentarios || fotos.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Icon(Icons.comment, color: _colorPrimario),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Comentarios e Imagen',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (tieneComentarios) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    maquina['comentario'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Imagen adjunta
                              if (fotos.isNotEmpty) ...[
                                const Text(
                                  'Imagen adjunta:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                InkWell(
                                  onTap: () => _verFoto(fotos.first),
                                  child: Container(
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(fotos.first),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.broken_image),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget para tarjeta de estadística
  Widget _buildStatCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: _colorTextoSecundario,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Diseño vertical original
  Widget _buildVerticalLayout() {
    return Column(
      children: [
        // Barra de filtro para vista vertical
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtros:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _colorPrimario,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              // Filtros de revisión
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _filtroActual == TipoFiltro.todas,
                    onSelected: (selected) {
                      if (selected) {
                        _cambiarFiltro(TipoFiltro.todas);
                      }
                    },
                    selectedColor: _colorPrimario.withOpacity(0.2),
                  ),
                  ChoiceChip(
                    label: const Text('Por vencer'),
                    selected: _filtroActual == TipoFiltro.proximas,
                    onSelected: (selected) {
                      if (selected) {
                        _cambiarFiltro(TipoFiltro.proximas);
                      }
                    },
                    selectedColor: Colors.orange.withOpacity(0.2),
                  ),
                  ChoiceChip(
                    label: const Text('Vencidas'),
                    selected: _filtroActual == TipoFiltro.vencidas,
                    onSelected: (selected) {
                      if (selected) {
                        _cambiarFiltro(TipoFiltro.vencidas);
                      }
                    },
                    selectedColor: _colorAlerta.withOpacity(0.2),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 4),

              // Filtros de estado operativo
              Text(
                'Estado de operación:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _colorPrimario,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Activas'),
                    selected: _filtroActual == TipoFiltro.activas,
                    onSelected: (selected) {
                      if (selected) {
                        _cambiarFiltro(TipoFiltro.activas);
                      }
                    },
                    selectedColor: Colors.green.withOpacity(0.2),
                    avatar: Icon(Icons.check_circle, color: Colors.green, size: 16),
                  ),
                  ChoiceChip(
                    label: const Text('En Taller'),
                    selected: _filtroActual == TipoFiltro.enMantenimiento,
                    onSelected: (selected) {
                      if (selected) {
                        _cambiarFiltro(TipoFiltro.enMantenimiento);
                      }
                    },
                    selectedColor: Colors.amber.withOpacity(0.2),
                    avatar: Icon(Icons.engineering, color: Colors.amber, size: 16),
                  ),
                  ChoiceChip(
                    label: const Text('Fuera de servicio'),
                    selected: _filtroActual == TipoFiltro.fueraDeServicio,
                    onSelected: (selected) {
                      if (selected) {
                        _cambiarFiltro(TipoFiltro.fueraDeServicio);
                      }
                    },
                    selectedColor: Colors.grey.withOpacity(0.2),
                    avatar: Icon(Icons.do_not_disturb_on, color: Colors.grey, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Lista de máquinas filtradas
        Expanded(
          child: _maquinasFiltradas.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _filtroActual == TipoFiltro.proximas ? Icons.warning :
                    _filtroActual == TipoFiltro.vencidas ? Icons.dangerous : Icons.search,
                    size: 64,
                    color: Colors.grey.shade400
                ),
                const SizedBox(height: 16),
                Text(
                  _filtroActual == TipoFiltro.todas
                      ? 'No hay máquinas registradas'
                      : 'No hay máquinas que coincidan con el filtro',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _maquinasFiltradas.length,
            itemBuilder: (context, index) {
              final maquina = _maquinasFiltradas[index];
              final diasRestantes = _calcularDiasRestantes(maquina['fechaRevisionTecnica']);
              final bool hayAlerta = diasRestantes != null && diasRestantes >= 0 && diasRestantes <= 30;
              final bool tieneComentarios = maquina['comentario'] != null &&
                  maquina['comentario'].toString().isNotEmpty;
              final List<String> fotos = maquina['imagenMaquina'] != null ?
              [maquina['imagenMaquina']] : [];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedList[index] = !_expandedList[index];
                    });
                  },
                  child: Column(
                    children: [
                      // Parte principal siempre visible
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: hayAlerta ? _colorAlerta.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: const Radius.circular(8),
                            bottom: _expandedList[index] ? Radius.zero : const Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Primera fila: ID, Patente y estado
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  color: maquina['estado'] == 'Activo' ? _colorPrimario : Colors.orange,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ID y Patente
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'ID: ${maquina['id']} | ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'Patente: ${maquina['patente']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Modelo
                                      Text(
                                        'Modelo: ${maquina['modelo']}',
                                        style: TextStyle(
                                          color: _colorTextoSecundario,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: maquina['estado'] == 'Activo'
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: maquina['estado'] == 'Activo'
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  child: Text(
                                    maquina['estado'] ?? 'Sin estado',
                                    style: TextStyle(
                                      color: maquina['estado'] == 'Activo'
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Segunda fila: Revisión técnica
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hayAlerta ? _colorAlerta.withOpacity(0.05) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: hayAlerta ? _colorAlerta.withOpacity(0.3) : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: hayAlerta ? _colorAlerta : _colorPrimario,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Revisión Técnica: ${_formatearFecha(maquina['fechaRevisionTecnica'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hayAlerta ? _colorAlerta : null,
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildDiasRestantes(diasRestantes),
                                ],
                              ),
                            ),

                            // Indicador visual para mostrar que se puede expandir
                            Center(
                              child: Icon(
                                _expandedList[index]
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.grey,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Sección expandible para comentarios e imagen
                      if (_expandedList[index])
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mostrar comentarios si existen
                              if (tieneComentarios) ...[
                                Row(
                                  children: [
                                    Icon(Icons.comment, color: _colorPrimario),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Comentarios:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    maquina['comentario'] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'No hay comentarios para esta máquina.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: _colorTextoSecundario,
                                    fontSize: 14,
                                  ),
                                ),
                              ],

                              // Mostrar imagen si existe
                              if (fotos.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'Imagen adjunta:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => _verFoto(fotos.first),
                                  child: Container(
                                    height: 100,
                                    width: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(fotos.first),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.broken_image),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              // Información adicional
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoField(
                                      'Capacidad',
                                      '${maquina['capacidad'] ?? 0} pasajeros',
                                      Icons.people,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildInfoField(
                                      'Kilometraje',
                                      '${maquina['kilometraje'] ?? 0} km',
                                      Icons.speed,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget para mostrar campos de información adicional
  Widget _buildInfoField(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _colorPrimario),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _colorTextoSecundario,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}