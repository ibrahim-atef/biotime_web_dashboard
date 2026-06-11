import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/session_storage.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit(this._storage) : super(const Locale('ar'));

  final SessionStorage _storage;

  Future<void> load() async {
    final code = await _storage.getLocale();
    if (code == 'en' || code == 'ar') {
      emit(Locale(code!));
    }
  }

  Future<void> setLocale(Locale locale) async {
    await _storage.saveLocale(locale.languageCode);
    emit(locale);
  }

  Future<void> toggle() async {
    final next = state.languageCode == 'ar' ? const Locale('en') : const Locale('ar');
    await setLocale(next);
  }
}
