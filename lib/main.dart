// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// import 'core/constants/colors.dart';
// import 'core/router/app_router.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final appRouter = AppRouter();
//     final router = appRouter.router;
//     return MaterialApp.router(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
//         textTheme: GoogleFonts.dmSansTextTheme(
//           Theme.of(context).textTheme,
//         ),
//         appBarTheme: AppBarTheme(
//           color: AppColors.white,
//           titleTextStyle: GoogleFonts.quicksand(
//             color: AppColors.primary,
//             fontSize: 18.0,
//             fontWeight: FontWeight.w700,
//           ),
//           iconTheme: const IconThemeData(
//             color: AppColors.black,
//           ),
//           centerTitle: true,
//           shape: Border(
//             bottom: BorderSide(
//               color: AppColors.black.withOpacity(0.05),
//             ),
//           ),
//         ),
//       ),
//       routerDelegate: router.routerDelegate,
//       routeInformationParser: router.routeInformationParser,
//       routeInformationProvider: router.routeInformationProvider,
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TestFirebase(),
    );
  }
}

class TestFirebase extends StatefulWidget {
  @override
  _TestFirebaseState createState() => _TestFirebaseState();
}

class _TestFirebaseState extends State<TestFirebase> {
  String _status = 'Checking connection...';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      // Test write to Firestore
      await FirebaseFirestore.instance
          .collection('test')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'test': 'Hello Firebase!'
          });
      
      setState(() {
        _status = 'Connected to Firebase successfully! ✅';
      });
    } catch (e) {
      setState(() {
        _status = 'Connection failed: ${e.toString()} ❌';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Connection Test'),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkConnection,
                child: Text('Test Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}