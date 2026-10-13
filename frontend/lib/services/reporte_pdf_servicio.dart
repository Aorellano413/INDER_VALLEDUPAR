import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/reporte_reserva_modelo.dart';

class ReportePdfServicio {
  static Future<void> exportar({
    required List<ReporteReservaModel> reservas,
    required String sedeNombre,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final pdf = pw.Document();

    final formatoFecha = DateFormat('dd/MM/yyyy');

    final total = reservas.length;

    final confirmadas =
        reservas.where((r) => r.estaConfirmada).length;

    final pendientes =
        reservas.where((r) => r.estaPendiente).length;

    final canceladas =
        reservas.where((r) => r.estaCancelada).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'INDER VALLEDUPAR',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Reporte de reservas',
                style: const pw.TextStyle(
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Sede: $sedeNombre',
              ),
              pw.Text(
                'Período: ${formatoFecha.format(fechaInicio)} - ${formatoFecha.format(fechaFin.subtract(const Duration(days: 1)))}',
              ),
              pw.SizedBox(height: 16),
            ],
          );
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 9,
              ),
            ),
          );
        },
        build: (context) {
          return [
            pw.Row(
              children: [
                _indicador('Total', total),
                pw.SizedBox(width: 12),
                _indicador('Confirmadas', confirmadas),
                pw.SizedBox(width: 12),
                _indicador('Pendientes', pendientes),
                pw.SizedBox(width: 12),
                _indicador('Canceladas', canceladas),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Fecha',
                'Hora',
                'Cliente',
                'Sede',
                'Cancha',
                'Estado',
              ],
              data: reservas.map((reserva) {
                return [
                  reserva.fecha != null
                      ? formatoFecha.format(reserva.fecha!)
                      : '--',
                  reserva.hora,
                  reserva.cliente,
                  reserva.sede,
                  reserva.cancha,
                  reserva.estadoVisual,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 8,
              ),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(
                color: PdfColors.grey400,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'reporte_reservas_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _indicador(
    String titulo,
    int valor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColors.grey400,
          ),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              titulo,
              style: const pw.TextStyle(
                fontSize: 9,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              valor.toString(),
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}