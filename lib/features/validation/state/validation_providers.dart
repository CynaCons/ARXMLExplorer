import 'package:flutter_riverpod/flutter_riverpod.dart';

// Text filter for validation issues list
final validationFilterProvider = StateProvider<String>((ref) => '');
