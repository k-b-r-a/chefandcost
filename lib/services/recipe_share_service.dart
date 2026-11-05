import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../utils/recipe_utils.dart';
import 'file_share_helper.dart';
import 'web_file_download.dart';

class RecipeImportPreview {
  final String name;
  final String? description;
  final double defaultYield;
  final String yieldName;
  final double targetProfitMargin;
  final double targetPricePerPortion;
  final int ingredientsCount;
  final int stepsCount;
  final int timersCount;
  final bool hasExistingRecipeWithSameName;
  final String suggestedName;

  RecipeImportPreview({
    required this.name,
    this.description,
    required this.defaultYield,
    required this.yieldName,
    required this.targetProfitMargin,
    required this.targetPricePerPortion,
    required this.ingredientsCount,
    required this.stepsCount,
    required this.timersCount,
    required this.hasExistingRecipeWithSameName,
    required this.suggestedName,
  });
}

class RecipeImportResult {
  final Recipe recipe;
  final int ingredientsCount;
  final int stepsCount;
  final int newIngredientsCreated;
  final int newUnitsCreated;
  final bool wasRenamed;

  RecipeImportResult({
    required this.recipe,
    required this.ingredientsCount,
    required this.stepsCount,
    required this.newIngredientsCreated,
    required this.newUnitsCreated,
    required this.wasRenamed,
  });
}

class RecipeShareService {
  static const String chefyFormatIdentifier = 'chefy_recipe';
  static const int currentFormatVersion = 1;
  static const Uuid _uuid = Uuid();

  /// Cleans strings to be safe for filenames across OSes.
  /// Removes emojis, symbols, and punctuation while preserving letters in any script,
  /// numbers, spaces, hyphens, and underscores.
  static String sanitizeFileName(String name) {
    final filtered = name
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s_-]', unicode: true), ' ')
        .trim();

    final clean = filtered
        .replaceAll(RegExp(r'[\s_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return clean.isEmpty ? 'recipe' : clean;
  }

  /// Exports recipe to standard Chef&Cost .chefy (JSON) bytes
  static Uint8List exportAsChefy(RecipeDetail detail, List<Unit> allUnits) {
    final unitMap = {for (final u in allUnits) u.unitPk: u};

    final ingredientsList = detail.ingredients.map((item) {
      final unit = unitMap[item.ingredient.unitFk];
      return {
        'name': item.ingredient.name,
        'cost': item.ingredient.cost,
        'quantityForCost': item.ingredient.quantityForCost,
        'amountNeeded': item.entry.amountNeeded,
        'unit': unit != null
            ? {
                'name': unit.name,
                'symbol': unit.symbol,
                'category': unit.category,
                'factorToBase': unit.factorToBase,
              }
            : null,
      };
    }).toList();

    final stepsList = detail.steps.map((s) {
      return {
        'stepNumber': s.stepNumber,
        'instruction': s.instruction,
      };
    }).toList();

    final exportData = {
      'format': chefyFormatIdentifier,
      'version': currentFormatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'recipe': {
        'name': detail.recipe.name,
        'description': detail.recipe.description,
        'defaultYield': detail.recipe.defaultYield,
        'yieldName': detail.recipe.yieldName,
        'targetProfitMargin': detail.recipe.targetProfitMargin,
        'targetPricePerPortion': detail.recipe.targetPricePerPortion,
        'fixedOverheadCost': detail.recipe.fixedOverheadCost,
        'colour': detail.recipe.colour,
      },
      'ingredients': ingredientsList,
      'steps': stepsList,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// Exports recipe to CSV with UTF-8 BOM for Microsoft Excel compatibility
  static Uint8List exportAsCsv({
    required RecipeDetail detail,
    required List<Unit> allUnits,
    required String currency,
    required AppLocalizations l10n,
    bool includeCosts = true,
  }) {
    final unitMap = {for (final u in allUnits) u.unitPk: u};
    final financials = RecipeUtils.calculateSummaryFromDetail(detail);

    final List<List<dynamic>> rows = [];

    // Header section: Recipe info
    rows.add([l10n.recipe_name, detail.recipe.name]);
    if (detail.recipe.description != null &&
        detail.recipe.description!.trim().isNotEmpty) {
      rows.add([l10n.recipe_description, detail.recipe.description!.trim()]);
    }
    rows.add([
      l10n.recipe_yield,
      '${RecipeUtils.formatQuantity(detail.recipe.defaultYield)} ${detail.recipe.yieldName}',
    ]);
    if (includeCosts) {
      rows.add([
        l10n.target_profit_margin,
        '${RecipeUtils.formatNumber(detail.recipe.targetProfitMargin, decimalDigits: 1)}%',
      ]);
      rows.add([
        l10n.target_price_portion,
        '$currency ${RecipeUtils.formatNumber(detail.recipe.targetPricePerPortion, decimalDigits: 2)}',
      ]);
      rows.add([
        l10n.cost_per_portion,
        '$currency ${RecipeUtils.formatNumber(financials.costPerPortion, decimalDigits: 2)}',
      ]);
      rows.add([
        l10n.total_cost,
        '$currency ${RecipeUtils.formatNumber(financials.totalCost, decimalDigits: 2)}',
      ]);
    }

    rows.add([]); // empty line separator

    // Ingredients section
    rows.add([
      includeCosts
          ? l10n.share_recipe_pdf_ingredients_title
          : l10n.ingredients_title,
    ]);

    if (includeCosts) {
      rows.add([
        l10n.ingredient_name,
        l10n.share_recipe_pdf_amount,
        l10n.share_recipe_pdf_unit,
        l10n.share_recipe_pdf_cost_per_unit,
        l10n.share_recipe_pdf_subtotal,
      ]);

      for (final item in detail.ingredients) {
        final unit = unitMap[item.ingredient.unitFk];
        final unitSymbol = unit?.symbol ?? '';
        final unitCost =
            item.ingredient.cost / (item.ingredient.quantityForCost > 0 ? item.ingredient.quantityForCost : 1.0);
        final subtotal = unitCost * item.entry.amountNeeded;

        rows.add([
          item.ingredient.name,
          RecipeUtils.formatQuantity(item.entry.amountNeeded),
          unitSymbol,
          '$currency ${RecipeUtils.formatNumber(unitCost, decimalDigits: 2)}',
          '$currency ${RecipeUtils.formatNumber(subtotal, decimalDigits: 2)}',
        ]);
      }

      rows.add([
        'TOTAL',
        '',
        '',
        '',
        '$currency ${RecipeUtils.formatNumber(financials.totalCost, decimalDigits: 2)}',
      ]);
    } else {
      rows.add([
        l10n.ingredient_name,
        l10n.share_recipe_pdf_amount,
        l10n.share_recipe_pdf_unit,
      ]);

      for (final item in detail.ingredients) {
        final unit = unitMap[item.ingredient.unitFk];
        final unitSymbol = unit?.symbol ?? '';

        rows.add([
          item.ingredient.name,
          RecipeUtils.formatQuantity(item.entry.amountNeeded),
          unitSymbol,
        ]);
      }
    }

    rows.add([]); // empty line separator

    // Steps section
    if (detail.steps.isNotEmpty) {
      rows.add([l10n.share_recipe_pdf_instructions_title]);
      rows.add([
        l10n.recipe_steps,
        l10n.step_instruction,
      ]);
      for (final step in detail.steps) {
        // Clean step text by removing timer tags for clean spreadsheet reading
        final cleanInstruction =
            step.instruction.replaceAll(RegExp(r'\[timer:[^\]]+\]'), '').trim();
        rows.add([
          step.stepNumber,
          cleanInstruction,
        ]);
      }
    }

    final csvContent = Csv(addBom: true).encode(rows);
    return Uint8List.fromList(utf8.encode(csvContent));
  }

  /// Exports recipe to printable, formatted PDF document
  static Future<Uint8List> exportAsPdf({
    required RecipeDetail detail,
    required List<Unit> allUnits,
    required String currency,
    required AppLocalizations l10n,
    bool includeCosts = true,
  }) async {
    final unitMap = {for (final u in allUnits) u.unitPk: u};
    final financials = RecipeUtils.calculateSummaryFromDetail(detail);

    // Load fonts with unicode support
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    final pdf = pw.Document();

    // Extract timers from instructions if present
    final timerRegExp = RegExp(r'\[timer:([^\|]+)\|(\d+)\]');
    final List<Map<String, dynamic>> timers = [];
    for (final step in detail.steps) {
      for (final match in timerRegExp.allMatches(step.instruction)) {
        final name = match.group(1) ?? 'Timer';
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        if (seconds > 0) {
          timers.add({'name': name, 'seconds': seconds});
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Chef&Cost',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepOrange700,
                  ),
                ),
                pw.Text(
                  detail.recipe.name,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${l10n.share_recipe_pdf_footer} - ${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Recipe Header Title & Description
            pw.Text(
              detail.recipe.name,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            if (detail.recipe.description != null &&
                detail.recipe.description!.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                detail.recipe.description!.trim(),
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
              ),
            ],
            pw.SizedBox(height: 14),

            // Financial & Yield Cards Row (or Yield only if includeCosts is false)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: includeCosts
                    ? [
                        _buildPdfStatItem(
                          title: l10n.recipe_yield,
                          value:
                              '${RecipeUtils.formatQuantity(detail.recipe.defaultYield)} ${detail.recipe.yieldName}',
                        ),
                        _buildPdfStatItem(
                          title: l10n.cost_per_portion,
                          value:
                              '$currency ${RecipeUtils.formatNumber(financials.costPerPortion, decimalDigits: 2)}',
                        ),
                        _buildPdfStatItem(
                          title: l10n.target_price_portion,
                          value:
                              '$currency ${RecipeUtils.formatNumber(detail.recipe.targetPricePerPortion, decimalDigits: 2)}',
                        ),
                        _buildPdfStatItem(
                          title: l10n.target_profit_margin,
                          value:
                              '${RecipeUtils.formatNumber(detail.recipe.targetProfitMargin, decimalDigits: 0)}%',
                        ),
                        _buildPdfStatItem(
                          title: l10n.total_cost,
                          value:
                              '$currency ${RecipeUtils.formatNumber(financials.totalCost, decimalDigits: 2)}',
                          isHighlight: true,
                        ),
                      ]
                    : [
                        _buildPdfStatItem(
                          title: l10n.recipe_yield,
                          value:
                              '${RecipeUtils.formatQuantity(detail.recipe.defaultYield)} ${detail.recipe.yieldName}',
                          isHighlight: true,
                        ),
                        _buildPdfStatItem(
                          title: l10n.ingredients_title,
                          value: '${detail.ingredients.length}',
                        ),
                        _buildPdfStatItem(
                          title: l10n.recipe_steps,
                          value: '${detail.steps.length}',
                        ),
                      ],
              ),
            ),
            pw.SizedBox(height: 18),

            // Ingredients Section Title
            pw.Text(
              includeCosts
                  ? l10n.share_recipe_pdf_ingredients_title
                  : l10n.ingredients_title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 8),

            // Ingredients Table
            pw.TableHelper.fromTextArray(
              context: context,
              headers: includeCosts
                  ? [
                      l10n.ingredient_name,
                      l10n.share_recipe_pdf_amount,
                      l10n.share_recipe_pdf_unit,
                      l10n.share_recipe_pdf_cost_per_unit,
                      l10n.share_recipe_pdf_subtotal,
                    ]
                  : [
                      l10n.ingredient_name,
                      l10n.share_recipe_pdf_amount,
                      l10n.share_recipe_pdf_unit,
                    ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: includeCosts
                  ? {
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.center,
                      3: pw.Alignment.centerRight,
                      4: pw.Alignment.centerRight,
                    }
                  : {
                      1: pw.Alignment.centerRight,
                      2: pw.Alignment.center,
                    },
              cellStyle: const pw.TextStyle(fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              data: includeCosts
                  ? [
                      ...detail.ingredients.map((item) {
                        final unit = unitMap[item.ingredient.unitFk];
                        final unitSymbol = unit?.symbol ?? '';
                        final unitCost = item.ingredient.cost /
                            (item.ingredient.quantityForCost > 0
                                ? item.ingredient.quantityForCost
                                : 1.0);
                        final subtotal = unitCost * item.entry.amountNeeded;

                        return [
                          item.ingredient.name,
                          RecipeUtils.formatQuantity(item.entry.amountNeeded),
                          unitSymbol,
                          '$currency ${RecipeUtils.formatNumber(unitCost, decimalDigits: 2)}',
                          '$currency ${RecipeUtils.formatNumber(subtotal, decimalDigits: 2)}',
                        ];
                      }),
                      // Total row
                      [
                        'TOTAL',
                        '',
                        '',
                        '',
                        '$currency ${RecipeUtils.formatNumber(financials.totalCost, decimalDigits: 2)}',
                      ],
                    ]
                  : [
                      ...detail.ingredients.map((item) {
                        final unit = unitMap[item.ingredient.unitFk];
                        final unitSymbol = unit?.symbol ?? '';

                        return [
                          item.ingredient.name,
                          RecipeUtils.formatQuantity(item.entry.amountNeeded),
                          unitSymbol,
                        ];
                      }),
                    ],
            ),
            pw.SizedBox(height: 18),

            // Instructions / Steps Section
            if (detail.steps.isNotEmpty) ...[
              pw.Text(
                l10n.share_recipe_pdf_instructions_title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 8),
              ...detail.steps.map((step) {
                final cleanText = step.instruction
                    .replaceAll(timerRegExp, '')
                    .trim();
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 20,
                        height: 20,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.orange700,
                          shape: pw.BoxShape.circle,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          '${step.stepNumber}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Text(
                          cleanText,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Timers section if any
            if (timers.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                l10n.share_recipe_pdf_timers_title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 8,
                runSpacing: 6,
                children: timers.map((t) {
                  final durationText = _formatSecondsToMinutes(t['seconds'] as int);
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.amber100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: PdfColors.amber400, width: 0.5),
                    ),
                    child: pw.Text(
                      '${t['name']}: $durationText',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfStatItem({
    required String title,
    required String value,
    bool isHighlight = false,
  }) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: isHighlight ? PdfColors.deepOrange800 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  static String _formatSecondsToMinutes(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final remainingSeconds = totalSeconds % 60;
    if (minutes > 0 && remainingSeconds > 0) {
      return '$minutes min $remainingSeconds sec';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$remainingSeconds sec';
    }
  }

  /// Summons native share dialog or browser download
  static Future<ShareResult> shareRecipeFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final String resolvedMimeType;
    if (filename.toLowerCase().endsWith('.chefy')) {
      resolvedMimeType = 'application/octet-stream';
    } else {
      resolvedMimeType = mimeType;
    }

    if (kIsWeb) {
      final handled = await webShareOrDownloadFile(
        bytes: bytes,
        filename: filename,
        mimeType: resolvedMimeType,
        subject: subject,
      );
      if (handled) {
        return const ShareResult('', ShareResultStatus.success);
      }
    }

    final xFile = await prepareFileForShare(
      bytes: bytes,
      filename: filename,
      mimeType: resolvedMimeType,
    );

    try {
      return await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          fileNameOverrides: [filename],
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
          downloadFallbackEnabled: true,
        ),
      );
    } on MissingPluginException catch (_) {
      if (kIsWeb) {
        await webShareOrDownloadFile(
          bytes: bytes,
          filename: filename,
          mimeType: resolvedMimeType,
          subject: subject,
        );
        return const ShareResult('', ShareResultStatus.success);
      }
      rethrow;
    }
  }

  /// Parses JSON content into preview information before database insertion
  static RecipeImportPreview previewRecipeFromJson(
    String jsonContent,
    List<Recipe> existingRecipes,
  ) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('Invalid JSON data');
    }

    if (data['format'] != chefyFormatIdentifier && data['recipe'] == null) {
      throw const FormatException('File does not match Chef&Cost recipe schema');
    }

    final recipeMap = (data['recipe'] as Map<String, dynamic>?) ?? {};
    final name = (recipeMap['name'] as String?)?.trim() ?? 'Untitled Recipe';
    final description = recipeMap['description'] as String?;
    final defaultYield = (recipeMap['defaultYield'] as num?)?.toDouble() ?? 1.0;
    final yieldName = (recipeMap['yieldName'] as String?) ?? 'portions';
    final targetProfitMargin =
        (recipeMap['targetProfitMargin'] as num?)?.toDouble() ?? 0.0;
    final targetPricePerPortion =
        (recipeMap['targetPricePerPortion'] as num?)?.toDouble() ?? 0.0;

    final ingredientsList = (data['ingredients'] as List?) ?? [];
    final stepsList = (data['steps'] as List?) ?? [];

    // Count timers in steps
    int timersCount = 0;
    final timerRegExp = RegExp(r'\[timer:([^\|]+)\|(\d+)\]');
    for (final s in stepsList) {
      if (s is Map && s['instruction'] is String) {
        timersCount += timerRegExp.allMatches(s['instruction'] as String).length;
      }
    }

    final existingNames =
        existingRecipes.map((r) => r.name.trim().toLowerCase()).toSet();
    final hasConflict = existingNames.contains(name.toLowerCase());

    String suggestedName = name;
    if (hasConflict) {
      int counter = 1;
      while (existingNames.contains('$name ($counter)'.toLowerCase())) {
        counter++;
      }
      suggestedName = '$name ($counter)';
    }

    return RecipeImportPreview(
      name: name,
      description: description,
      defaultYield: defaultYield,
      yieldName: yieldName,
      targetProfitMargin: targetProfitMargin,
      targetPricePerPortion: targetPricePerPortion,
      ingredientsCount: ingredientsList.length,
      stepsCount: stepsList.length,
      timersCount: timersCount,
      hasExistingRecipeWithSameName: hasConflict,
      suggestedName: suggestedName,
    );
  }

  /// Imports recipe JSON into local database, creating ingredients and units as needed
  static Future<RecipeImportResult> importRecipeFromJson({
    required String jsonContent,
    required AppDatabase db,
    String? overrideRecipeName,
  }) async {
    final Map<String, dynamic> data =
        jsonDecode(jsonContent) as Map<String, dynamic>;

    if (data['format'] != chefyFormatIdentifier && data['recipe'] == null) {
      throw const FormatException('File does not match Chef&Cost recipe schema');
    }

    final recipeMap = (data['recipe'] as Map<String, dynamic>?) ?? {};
    final originalName =
        (recipeMap['name'] as String?)?.trim() ?? 'Untitled Recipe';
    final finalName = overrideRecipeName?.trim().isNotEmpty == true
        ? overrideRecipeName!.trim()
        : originalName;
    final wasRenamed = finalName != originalName;

    final description = recipeMap['description'] as String?;
    final defaultYield = (recipeMap['defaultYield'] as num?)?.toDouble() ?? 1.0;
    final yieldName = (recipeMap['yieldName'] as String?) ?? 'portions';
    final targetProfitMargin =
        (recipeMap['targetProfitMargin'] as num?)?.toDouble() ?? 0.0;
    final targetPricePerPortion =
        (recipeMap['targetPricePerPortion'] as num?)?.toDouble() ?? 0.0;
    final fixedOverheadCost =
        (recipeMap['fixedOverheadCost'] as num?)?.toDouble() ?? 0.0;
    final colour = recipeMap['colour'] as String?;

    final ingredientsList = (data['ingredients'] as List?) ?? [];
    final stepsList = (data['steps'] as List?) ?? [];

    int newUnitsCount = 0;
    int newIngredientsCount = 0;
    late Recipe insertedRecipe;

    await db.transaction(() async {
      final allUnits = await db.getAllUnits();
      final allIngredients = await db.getAllIngredients();

      final unitBySymbol = {for (final u in allUnits) u.symbol.toLowerCase(): u};
      final unitByName = {for (final u in allUnits) u.name.toLowerCase(): u};
      final ingByName = {
        for (final ing in allIngredients) ing.name.trim().toLowerCase(): ing
      };

      // 1. Process ingredients and match/create units and ingredients
      final List<Map<String, dynamic>> resolvedIngredients = [];

      for (final ingData in ingredientsList) {
        if (ingData is! Map) continue;
        final ingName = (ingData['name'] as String?)?.trim() ?? 'Ingredient';
        final ingCost = (ingData['cost'] as num?)?.toDouble() ?? 0.0;
        final ingQtyForCost =
            (ingData['quantityForCost'] as num?)?.toDouble() ?? 1.0;
        final amountNeeded =
            (ingData['amountNeeded'] as num?)?.toDouble() ?? 0.0;

        final unitMap = ingData['unit'] as Map<String, dynamic>?;

        // Resolve unit
        String resolvedUnitPk;
        if (unitMap != null) {
          final uSymbol = (unitMap['symbol'] as String?)?.trim().toLowerCase() ?? '';
          final uName = (unitMap['name'] as String?)?.trim().toLowerCase() ?? '';

          Unit? matchedUnit = unitBySymbol[uSymbol] ?? unitByName[uName];

          if (matchedUnit == null) {
            // Create new unit
            final newUnitPk = _uuid.v4();
            final newUnitName = (unitMap['name'] as String?) ?? 'unit';
            final newUnitSymbol = (unitMap['symbol'] as String?) ?? 'u';
            final newCategory = unitMap['category'] as String?;
            final newFactor = (unitMap['factorToBase'] as num?)?.toDouble() ?? 1.0;

            await db.into(db.units).insert(
                  UnitsCompanion(
                    unitPk: drift.Value(newUnitPk),
                    name: drift.Value(newUnitName),
                    symbol: drift.Value(newUnitSymbol),
                    category: drift.Value(newCategory),
                    factorToBase: drift.Value(newFactor),
                    isMutable: const drift.Value(true),
                  ),
                );
            newUnitsCount++;
            resolvedUnitPk = newUnitPk;
          } else {
            resolvedUnitPk = matchedUnit.unitPk;
          }
        } else {
          // Default to grams or first available unit
          resolvedUnitPk = allUnits.firstOrNull?.unitPk ?? 'unit-g';
        }

        // Resolve ingredient
        String resolvedIngPk;
        final existingIng = ingByName[ingName.toLowerCase()];
        if (existingIng == null) {
          final newIngPk = _uuid.v4();
          await db.into(db.ingredients).insert(
                IngredientsCompanion(
                  ingredientPk: drift.Value(newIngPk),
                  name: drift.Value(ingName),
                  cost: drift.Value(ingCost),
                  quantityForCost: drift.Value(ingQtyForCost),
                  unitFk: drift.Value(resolvedUnitPk),
                  dateCreated: drift.Value(DateTime.now()),
                  dateTimeModified: drift.Value(DateTime.now()),
                ),
              );
          newIngredientsCount++;
          resolvedIngPk = newIngPk;
          // Add to local map to handle duplicate references within the same recipe
          ingByName[ingName.toLowerCase()] = Ingredient(
            ingredientPk: newIngPk,
            name: ingName,
            cost: ingCost,
            quantityForCost: ingQtyForCost,
            unitFk: resolvedUnitPk,
            dateCreated: DateTime.now(),
          );
        } else {
          resolvedIngPk = existingIng.ingredientPk;
        }

        resolvedIngredients.add({
          'ingredientPk': resolvedIngPk,
          'amountNeeded': amountNeeded,
        });
      }

      // 2. Insert Recipe
      final newRecipePk = _uuid.v4();
      final now = DateTime.now();

      await db.into(db.recipes).insert(
            RecipesCompanion(
              recipePk: drift.Value(newRecipePk),
              name: drift.Value(finalName),
              description: drift.Value(description),
              defaultYield: drift.Value(defaultYield),
              yieldName: drift.Value(yieldName),
              targetProfitMargin: drift.Value(targetProfitMargin),
              targetPricePerPortion: drift.Value(targetPricePerPortion),
              fixedOverheadCost: drift.Value(fixedOverheadCost),
              colour: drift.Value(colour),
              dateCreated: drift.Value(now),
              dateTimeModified: drift.Value(now),
              archived: const drift.Value(false),
            ),
          );

      insertedRecipe = Recipe(
        recipePk: newRecipePk,
        name: finalName,
        description: description,
        defaultYield: defaultYield,
        yieldName: yieldName,
        targetProfitMargin: targetProfitMargin,
        targetPricePerPortion: targetPricePerPortion,
        fixedOverheadCost: fixedOverheadCost,
        colour: colour,
        dateCreated: now,
        dateTimeModified: now,
        archived: false,
      );

      // 3. Insert Recipe Ingredients
      for (final item in resolvedIngredients) {
        await db.into(db.recipeIngredients).insert(
              RecipeIngredientsCompanion.insert(
                recipeFk: newRecipePk,
                ingredientFk: item['ingredientPk'] as String,
                amountNeeded: item['amountNeeded'] as double,
                dateTimeModified: drift.Value(now),
              ),
            );
      }

      // 4. Insert Recipe Steps
      for (int i = 0; i < stepsList.length; i++) {
        final stepData = stepsList[i];
        if (stepData is! Map) continue;
        final stepNumber = (stepData['stepNumber'] as num?)?.toInt() ?? (i + 1);
        final instruction = (stepData['instruction'] as String?)?.trim() ?? '';

        await db.into(db.recipeSteps).insert(
              RecipeStepsCompanion.insert(
                recipeFk: newRecipePk,
                stepNumber: stepNumber,
                instruction: instruction,
                dateTimeModified: drift.Value(now),
              ),
            );
      }
    });

    return RecipeImportResult(
      recipe: insertedRecipe,
      ingredientsCount: ingredientsList.length,
      stepsCount: stepsList.length,
      newIngredientsCreated: newIngredientsCount,
      newUnitsCreated: newUnitsCount,
      wasRenamed: wasRenamed,
    );
  }
}
