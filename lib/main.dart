import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/http_client.dart';
import 'splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final authProvider = AuthProvider();
        HttpClient.init(authProvider);
        return authProvider;
      },
      child: MaterialApp(
        title: 'UniHub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Poppins',
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}