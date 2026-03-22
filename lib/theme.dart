import 'package:flutter/material.dart';

//
// Colors
//
const Color kAppBackgroundColor = Color(0xFFF5F1EB);

//
// Fonts
//
const String kAppSansFont = 'Segoe UI';
const List<String> kAppSansFallback = <String>['Helvetica', 'Arial'];
const String kAppSerifFont = 'Georgia';
const List<String> kAppSerifFallback = <String>['Times New Roman'];

//
// Font weights
//
const FontWeight kWeightNormal = FontWeight.w500;
const FontWeight kWeightBold = FontWeight.w700;

TextTheme applyTextWeights(TextTheme base) => base.copyWith(
  displayLarge: base.displayLarge?.copyWith(fontWeight: kWeightNormal),
  displayMedium: base.displayMedium?.copyWith(fontWeight: kWeightNormal),
  displaySmall: base.displaySmall?.copyWith(fontWeight: kWeightNormal),
  headlineLarge: base.headlineLarge?.copyWith(fontWeight: kWeightNormal),
  headlineMedium: base.headlineMedium?.copyWith(fontWeight: kWeightNormal),
  headlineSmall: base.headlineSmall?.copyWith(fontWeight: kWeightNormal),
  titleLarge: base.titleLarge?.copyWith(fontWeight: kWeightNormal),
  titleMedium: base.titleMedium?.copyWith(fontWeight: kWeightNormal),
  titleSmall: base.titleSmall?.copyWith(fontWeight: kWeightNormal),
  bodyLarge: base.bodyLarge?.copyWith(fontWeight: kWeightNormal),
  bodyMedium: base.bodyMedium?.copyWith(fontWeight: kWeightNormal),
  bodySmall: base.bodySmall?.copyWith(fontWeight: kWeightNormal),
  labelLarge: base.labelLarge?.copyWith(fontWeight: kWeightNormal),
  labelMedium: base.labelMedium?.copyWith(fontWeight: kWeightNormal),
  labelSmall: base.labelSmall?.copyWith(fontWeight: kWeightNormal),
);
