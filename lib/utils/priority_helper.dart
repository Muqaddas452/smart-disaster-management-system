import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Priority ka EK hi hisaab-kitaab poori app mein.
//
// Pehle har screen apna default aur apna field parhti thi (list: 'medium',
// details: 'high', home: sirf exact 'high'), is liye ek hi task kahin Medium
// aur kahin High dikhta tha. Ab sab screens yahi helper use karti hain.
//
// Priority citizen ki report (severity_level) se aati hai ya admin ke alert
// (priority / riskLevel / severity) se — jis field mein bhi ho, yahan se
// guzar kar 'high' | 'medium' | 'low' ban jati hai.
// ─────────────────────────────────────────────────────────────

/// In fields mein se jo pehla khali na ho wo priority maani jati hai.
const List<String> kPriorityFields = [
  'priority',
  'severity_level',
  'severityLevel',
  'severity',
  'riskLevel',
  'risk_level',
  'risk',
  'alertPriority',
];

/// Kisi bhi likhawat ("High", "HIGH", "critical", "Severe"...) ko
/// 'high' | 'medium' | 'low' mein badalta hai. Pehchan na ho to '' deta hai.
String normalizePriority(dynamic raw) {
  final String v = (raw ?? '').toString().trim().toLowerCase();
  if (v.isEmpty) return '';
  if (v.contains('high') ||
      v.contains('critical') ||
      v.contains('severe') ||
      v.contains('urgent') ||
      v.contains('extreme') ||
      v.contains('emergency') ||
      v.contains('danger') ||
      v == 'red' ||
      v == '3') {
    return 'high';
  }
  if (v.contains('med') || v.contains('moderate') || v == 'orange' || v == 'yellow' || v == '2') {
    return 'medium';
  }
  if (v.contains('low') || v.contains('minor') || v == 'green' || v == '1') {
    return 'low';
  }
  return '';
}

/// Task / alert document se priority nikalta hai. Top-level fields ke baad
/// nested `report` / `alert` maps bhi dekhta hai (agar admin ne wahan rakhi ho).
String resolvePriority(Map<String, dynamic> data, {String fallback = 'medium'}) {
  String pick(Map src) {
    for (final f in kPriorityFields) {
      final p = normalizePriority(src[f]);
      if (p.isNotEmpty) return p;
    }
    return '';
  }

  String p = pick(data);
  if (p.isNotEmpty) return p;

  for (final nested in ['report', 'alert', 'source']) {
    final n = data[nested];
    if (n is Map) {
      p = pick(n);
      if (p.isNotEmpty) return p;
    }
  }
  return fallback;
}

/// Task ka type — admin report-task mein `emergencyType`/`type`, purane mein `title`.
String taskType(Map<String, dynamic> d, {String fallback = 'Task'}) {
  for (final k in ['type', 'emergencyType', 'incident_type', 'title']) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return fallback;
}

/// Task ka address — `address`, warna `location`, warna `city`.
String taskAddress(Map<String, dynamic> d, {String fallback = 'Address not available'}) {
  for (final k in ['address', 'location', 'city']) {
    final v = (d[k] ?? '').toString().trim();
    if (v.isNotEmpty && v.toLowerCase() != 'unknown') return v;
  }
  return fallback;
}

bool isHighPriority(Map<String, dynamic> data) => resolvePriority(data, fallback: '') == 'high';

String priorityLabel(String p) =>
    p.isEmpty ? 'Medium' : '${p[0].toUpperCase()}${p.substring(1)}';

/// [background, text] colours — list aur details dono mein same.
List<Color> priorityColors(String p) {
  switch (p) {
    case 'high':
      return const [Color(0xFFFCEBEB), Color(0xFF791F1F)];
    case 'low':
      return const [Color(0xFFE6F1FB), Color(0xFF042C53)];
    default:
      return const [Color(0xFFFAEEDA), Color(0xFF633806)];
  }
}


