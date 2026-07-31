import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/scada/presentation/providers/scada_provider.dart';
import 'features/scada/presentation/screens/scada_shell_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ScadaProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tân Ân Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const ScadaShellScreen(),
    );
  }
}
