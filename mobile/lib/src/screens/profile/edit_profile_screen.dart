import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../../providers/auth_provider.dart';
import '../../config/theme_config.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;
  String? _avatarPreviewUrl; // en caso de que el backend retorne nueva URL

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40.r,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      backgroundImage: _avatarPreviewUrl != null
                          ? NetworkImage(_avatarPreviewUrl!)
                          : null,
                      child: _avatarPreviewUrl == null
                          ? const Icon(Icons.person, size: 36)
                          : null,
                    ),
                    SizedBox(height: 8.h),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: _saving ? null : _pickAndUploadAvatar,
                      label: const Text('Cambiar foto (limpia y comprimida)'),
                    )
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Información Personal',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingrese su nombre';
                  }
                  if (value.trim().length < 2) {
                    return 'Nombre demasiado corto';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.close),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? AppColors.primaryLight : AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: BorderSide(
                          color: isDark ? AppColors.grey700 : AppColors.grey300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      onPressed: _saving
                          ? null
                          : () {
                              context.pop();
                            },
                      label: const Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: _saving ? null : _onSave,
                      label: _saving
                          ? const Text('Guardando...')
                          : const Text('Guardar cambios'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await ref.read(authProvider.notifier).updateProfile(
        _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim());
    setState(() => _saving = false);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Perfil actualizado'),
        backgroundColor: AppColors.success,
      ));
      context.pop();
    } else {
      final err = ref.read(authProvider).error ?? 'No se pudo guardar';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      // Importaciones diferidas para no romper otras plataformas
      // ignore: avoid_dynamic_calls
      final picker = await _loadPicker();
      final file = await picker();
      if (file == null) return;

      // Re-encode y compresión en cliente por seguridad adicional
      final processed = await _reencodeJpeg(await file.readAsBytes());
      final resultUrl = await ref
          .read(authProvider.notifier)
          .uploadAvatarBytes(processed, filename: 'avatar.jpg');
      if (!mounted) return;
      if (resultUrl != null) {
        await ref.read(authProvider.notifier).refreshUser();
        setState(() {
          _avatarPreviewUrl = null; // se actualizará desde profile si existe
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Avatar actualizado'),
          backgroundColor: AppColors.success,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo actualizar el avatar'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Error seleccionando imagen'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // Carga del file_picker directamente
  Future<Future<_MemoryFile?> Function()> _loadPicker() async {
    return () async {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        withData: true,
      );
      if (res == null || res.files.isEmpty || res.files.first.bytes == null) {
        return null;
      }
      return _MemoryFile(res.files.first.bytes!);
    };
  }

  // Re-encodifica a JPEG de forma simple con el paquete image
  Future<List<int>> _reencodeJpeg(List<int> data) async {
    final decoded = img.decodeImage(Uint8List.fromList(data));
    if (decoded == null) return data;
    final resized = img.copyResize(decoded, width: 512, height: 512);
    return img.encodeJpg(resized, quality: 82);
  }
}

// Pequeña clase helper para leer bytes uniformemente
class _MemoryFile {
  final List<int> _bytes;
  _MemoryFile(this._bytes);
  Future<List<int>> readAsBytes() async => _bytes;
}

// (sin references perezosas; importamos directamente los paquetes)
