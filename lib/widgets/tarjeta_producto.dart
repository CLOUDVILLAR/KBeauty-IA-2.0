import 'package:flutter/material.dart';

import '../utilidades/formato.dart';
import 'tarjeta_base.dart';

Widget tarjetaProducto(Map<String, dynamic> producto) {
  final ubicaciones = listaMapas(
    producto['ubicaciones_odoo'] ?? producto['ubicaciones'],
  );

  final idOdoo = textoSeguro(producto['id_odoo'], 'N/D');
  final categoria = textoSeguro(producto['categoria'], 'Sin categoria');
  final subtipo = textoSeguro(producto['subtipo'], '');
  final frecuencia = textoSeguro(producto['frecuencia']);

  return tarjetaBase(
    hijo: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.spa_outlined, size: 20, color: Color(0xFFDC1015)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtipo.isEmpty ? categoria : '$categoria · $subtipo',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        if (frecuencia.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Frecuencia: $frecuencia',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
        const SizedBox(height: 8),
        Theme(
          data: ThemeData().copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            initiallyExpanded: false,
            title: Text(
              ubicaciones.isEmpty ? 'Ubicacion Odoo' : 'Ubicaciones Odoo (${ubicaciones.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text('Toca para ver ID, almacen y cantidad', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded),
            children: [
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _filaDatoOdoo(icono: Icons.tag_outlined, titulo: 'ID Odoo', valor: idOdoo),
                    const SizedBox(height: 10),
                    if (ubicaciones.isEmpty)
                      const Text('Sin ubicacion disponible en Odoo', style: TextStyle(fontSize: 13))
                    else
                      ...ubicaciones.map((ubicacion) => _filaUbicacion(ubicacion)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _filaDatoOdoo({required IconData icono, required String titulo, required String valor}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icono, size: 18, color: const Color(0xFFE89AB4)),
      const SizedBox(width: 8),
      Text('$titulo: ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      Expanded(child: Text(valor, style: const TextStyle(fontSize: 13))),
    ],
  );
}

Widget _filaUbicacion(Map<String, dynamic> ubicacion) {
  final nombreUbicacion = textoSeguro(
    ubicacion['ubicacion'] ?? ubicacion['nombre_ubicacion'] ?? ubicacion['location_name'] ?? ubicacion['location_id'],
    'Ubicacion',
  );

  final cantidad = textoSeguro(
    ubicacion['cantidad'] ?? ubicacion['quantity'] ?? ubicacion['available_quantity'],
    '',
  );

  final almacen = textoSeguro(
    ubicacion['almacen'] ?? ubicacion['warehouse'] ?? ubicacion['warehouse_id'],
    '',
  );

  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warehouse_outlined, size: 18, color: Color(0xFFE89AB4)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombreUbicacion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (almacen.isNotEmpty)
                Text(almacen, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        if (cantidad.isNotEmpty)
          Text(cantidad, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
