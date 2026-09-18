import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfilingOption {
  const ProfilingOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}
