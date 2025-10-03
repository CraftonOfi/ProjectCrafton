import 'package:flutter/material.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Pantalla en Construcción',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Esta pantalla mostrará:\n'
              '• Formulario de edición de perfil\n'
              '• Campo de nombre\n'
              '• Campo de teléfono\n'
              '• Avatar personalizable\n'
              '• Botones de guardar y cancelar',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}