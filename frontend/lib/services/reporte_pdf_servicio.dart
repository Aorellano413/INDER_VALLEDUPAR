// lib/services/reporte_pdf_servicio.dart
//
// Genera el PDF del reporte de reservas con los MISMOS datos que muestra la
// pantalla (misma lista, mismo período y misma sede) y abre el diálogo de
// impresión / guardado del sistema (paquetes pdf y printing, ya incluidos
// en pubspec.yaml).
//
// Los colores son los de la marca definidos en lib/theme/inder_tema.dart
// (InderColors.ink y InderColors.gold). Se repiten aquí como PdfColor porque
// el paquete pdf no usa los Color de Flutter.
//
// Nota: el PDF usa la fuente estándar (Helvetica), que cubre el español
// (tildes, ñ). Caracteres fuera de Latin-1 (p. ej. emojis en un nombre) podrían
// no dibujarse.
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/reporte_reserva_modelo.dart';
import '../utils/reporte_periodo.dart';
import '../utils/reserva_estado.dart';

final PdfColor _ink = PdfColor.fromInt(0xFF0A1219);
final PdfColor _gold = PdfColor.fromInt(0xFFF9CB07);
final PdfColor _goldTint = PdfColor.fromInt(0xFFFFF6D6);
final PdfColor _borde = PdfColor.fromInt(0xFFE3E6EB);
final PdfColor _muted = PdfColor.fromInt(0xFF5B6572);

class ReportePdfServicio {
  ReportePdfServicio._();

  static Future<void> exportar({
    required List<ReporteReservaModel> reservas,
    required String sedeNombre,
    required PeriodoReporte periodo,
  }) async {
    final pdf = pw.Document(
      title: 'Reporte de reservas - INDER Valledupar',
      author: 'INDER Valledupar',
    );

    final formatoFecha = DateFormat('dd/MM/yyyy');
    final generado = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final logo = await _cargarLogo();

    final total = reservas.length;
    final confirmadas = reservas.where((r) => r.estaConfirmada).length;
    final pendientes = reservas.where((r) => r.estaPendiente).length;
    final canceladas = reservas.where((r) => r.estaCancelada).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null) ...[
                  pw.Image(logo, height: 38),
                  pw.SizedBox(width: 12),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INDER VALLEDUPAR',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      pw.Text(
                        'Reporte de reservas',
                        style: pw.TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Sede: $sedeNombre',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Período: ${periodo.texto}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Container(height: 2, color: _gold),
            pw.SizedBox(height: 14),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado el $generado',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
        build: (context) => [
          pw.Row(
            children: [
              _indicador('Total de reservas', total),
              pw.SizedBox(width: 12),
              _indicador('Confirmadas (pagadas)', confirmadas),
              pw.SizedBox(width: 12),
              _indicador('Pendientes', pendientes),
              pw.SizedBox(width: 12),
              _indicador('Canceladas', canceladas),
            ],
          ),
          pw.SizedBox(height: 18),
          if (reservas.isEmpty)
            pw.Text(
              'No hay reservas para los filtros seleccionados.',
              style: pw.TextStyle(fontSize: 11, color: _muted),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Fecha',
                'Hora',
                'Cliente',
                'Sede',
                'Cancha',
                'Estado',
              ],
              data: reservas
                  .map(
                    (r) => [
                      r.fecha != null ? formatoFecha.format(r.fecha!) : '--',
                      r.hora.isEmpty ? '--' : r.hora,
                      r.cliente,
                      r.sede,
                      r.cancha,
                      r.estado.label,
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: _ink,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(color: _borde),
              headerDecoration: pw.BoxDecoration(color: _goldTint),
            ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name:
          'reporte_reservas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  /// Logotipo institucional (el mismo asset que usa el encabezado de la app).
  /// Si no se puede cargar, el PDF se genera igualmente, sin logotipo.
  static Future<pw.MemoryImage?> _cargarLogo() async {
    try {
      final datos = await rootBundle.load('lib/images/inder.png');
      return pw.MemoryImage(
        datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes),
      );
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _indicador(String titulo, int valor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _borde),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(titulo, style: pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 4),
            pw.Text(
              valor.toString(),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
