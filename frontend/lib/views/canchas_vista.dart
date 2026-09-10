// lib/views/canchas_vista.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/canchas_controlador.dart';
import '../controllers/reserva_controlador.dart';
import '../models/cancha_modelo.dart';
import '../routes/app_rutas.dart';

class CanchasView extends StatefulWidget {
  final String sedeId;
  final String sedeNombre;

  const CanchasView({
    super.key,
    required this.sedeId,
    required this.sedeNombre,
  });

  @override
  State<CanchasView> createState() => _CanchasViewState();
}

class _CanchasViewState extends State<CanchasView> {
  late CanchasController _canchasController;

  @override
  void initState() {
    super.initState();
    _canchasController = CanchasController();
    _canchasController.cargarCanchasPorSede(widget.sedeId);
  }

  @override
  void dispose() {
    _canchasController.dispose();
    super.dispose();
  }

  String _formatearMoneda(String precioOriginal) {
    String soloNumeros = precioOriginal.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloNumeros.isEmpty) return precioOriginal;

    int numero = int.parse(soloNumeros);
    String formateado = numero.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.'
    );

    return '$formateado COP';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final isDesktop = width > 900;
    final isTablet = width > 600 && width <= 900;

    return ChangeNotifierProvider.value(
      value: _canchasController,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset("lib/images/fondo.jpg", fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildCustomAppBar()),

                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40 : 20,
                      vertical: 20,
                    ),
                    sliver: Consumer2<CanchasController, ReservaController>(
                      builder: (context, canchasController, reservaController, child) {
                        if (canchasController.isLoading) {
                          return const SliverToBoxAdapter(
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          );
                        }

                        if (canchasController.error != null) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Text(
                                "Error al cargar canchas",
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ),
                          );
                        }

                        if (canchasController.canchas.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Text(
                                "No hay canchas disponibles",
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ),
                          );
                        }

                        return SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final cancha = canchasController.canchas[index];
                              return _buildCanchaCard(
                                context,
                                cancha,
                                reservaController,
                              );
                            },
                            childCount: canchasController.canchas.length,
                          ),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1),
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio:
                                isDesktop ? 1.15 : (isTablet ? 1.05 : 0.90),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanchaCard(
    BuildContext context,
    CanchaModel cancha,
    ReservaController reservaController,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCanchaImage(cancha.image),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cancha.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 16, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  cancha.horario,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Row(
                              children: [
                                const Icon(Icons.sports_soccer,
                                    size: 16, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  "Jugadores: ${cancha.jugadores}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(204, 12, 15, 172).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _formatearMoneda(cancha.price), // <--- Precio formateado con puntos
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                reservaController.setTipoCancha(cancha.tipo);
                                reservaController.setCanchaId(cancha.id);
                                reservaController.setSedeId(widget.sedeId);

                                Navigator.pushNamed(context, AppRoutes.reserva);
                              },
                              icon: const Icon(Icons.event_available, size: 18),
                              label: const Text("Reservar"),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanchaImage(String imagePath) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        child: imagePath.startsWith('http')
            ? Image.network(
                imagePath,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Image.asset(
                imagePath,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.sedeNombre,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}