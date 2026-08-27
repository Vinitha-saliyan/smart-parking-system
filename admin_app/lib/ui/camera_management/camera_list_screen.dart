import 'package:flutter/material.dart';

class CameraListScreen extends StatelessWidget {
  const CameraListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Management')),
      body: const Center(child: Text('Camera List UI')),
    );
  }
}
