import 'package:InderApp/controllers/tema_controlador.dart';
import 'package:InderApp/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';


void main() {
  testWidgets('Carga LoginView y muestra botones clave', (WidgetTester tester) async {

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const InderApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('INDER - Valledupar'), findsOneWidget);
    expect(find.text('Reservar Cancha'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
  });
}

