import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_am.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_az.dart';
import 'app_localizations_bg.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_ca.dart';
import 'app_localizations_cs.dart';
import 'app_localizations_da.dart';
import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_eo.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_he.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_ht.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_km.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_kxd.dart';
import 'app_localizations_lt.dart';
import 'app_localizations_mk.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_nb.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_si.dart';
import 'app_localizations_sk.dart';
import 'app_localizations_sr.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_sw.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tl.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_uz.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('af'),
    Locale('am'),
    Locale('ar'),
    Locale('az'),
    Locale('bg'),
    Locale('bn'),
    Locale('ca'),
    Locale('cs'),
    Locale('da'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('eo'),
    Locale('es'),
    Locale('fa'),
    Locale('fi'),
    Locale('fr'),
    Locale('gu'),
    Locale('he'),
    Locale('hi'),
    Locale('hr'),
    Locale('ht'),
    Locale('hu'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('km'),
    Locale('ko'),
    Locale('kxd'),
    Locale('lt'),
    Locale('mk'),
    Locale('ml'),
    Locale('mr'),
    Locale('ms'),
    Locale('nb'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('pt', 'PT'),
    Locale('ro'),
    Locale('ru'),
    Locale('si'),
    Locale('sk'),
    Locale('sr'),
    Locale('sv'),
    Locale('sw'),
    Locale('ta'),
    Locale('te'),
    Locale('th'),
    Locale('tl'),
    Locale('tr'),
    Locale('uk'),
    Locale('ur'),
    Locale('uz'),
    Locale('vi'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @home_title.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home_title;

  /// No description provided for @home_greeting_morning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, Chef'**
  String get home_greeting_morning;

  /// No description provided for @home_greeting_afternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, Chef'**
  String get home_greeting_afternoon;

  /// No description provided for @home_greeting_evening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, Chef'**
  String get home_greeting_evening;

  /// No description provided for @home_quick_actions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get home_quick_actions;

  /// No description provided for @home_recent_recipes.
  ///
  /// In en, this message translates to:
  /// **'Recent Recipes'**
  String get home_recent_recipes;

  /// No description provided for @home_view_all.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get home_view_all;

  /// No description provided for @home_active_timers.
  ///
  /// In en, this message translates to:
  /// **'Active Timers'**
  String get home_active_timers;

  /// No description provided for @home_kitchen_tools.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Tools'**
  String get home_kitchen_tools;

  /// No description provided for @home_stats_recipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get home_stats_recipes;

  /// No description provided for @home_stats_ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get home_stats_ingredients;

  /// No description provided for @home_stats_avg_margin.
  ///
  /// In en, this message translates to:
  /// **'Avg. Margin'**
  String get home_stats_avg_margin;

  /// No description provided for @recipes_title.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipes_title;

  /// No description provided for @new_recipe_title.
  ///
  /// In en, this message translates to:
  /// **'New Recipe'**
  String get new_recipe_title;

  /// No description provided for @recipe_title.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get recipe_title;

  /// No description provided for @ingredients_title.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients_title;

  /// No description provided for @units_title.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units_title;

  /// No description provided for @recipe_name.
  ///
  /// In en, this message translates to:
  /// **'Recipe Name'**
  String get recipe_name;

  /// No description provided for @recipe_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get recipe_description;

  /// No description provided for @recipe_description_hint.
  ///
  /// In en, this message translates to:
  /// **'Short description of the recipe...'**
  String get recipe_description_hint;

  /// No description provided for @recipe_yield.
  ///
  /// In en, this message translates to:
  /// **'Default Yield'**
  String get recipe_yield;

  /// No description provided for @recipe_yield_name.
  ///
  /// In en, this message translates to:
  /// **'Yield Unit (e.g. cookies)'**
  String get recipe_yield_name;

  /// No description provided for @target_profit_margin.
  ///
  /// In en, this message translates to:
  /// **'Target Profit Margin'**
  String get target_profit_margin;

  /// No description provided for @target_price_portion.
  ///
  /// In en, this message translates to:
  /// **'Target Price per Portion'**
  String get target_price_portion;

  /// No description provided for @fixed_overhead.
  ///
  /// In en, this message translates to:
  /// **'Fixed Overhead Cost'**
  String get fixed_overhead;

  /// No description provided for @total_cost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get total_cost;

  /// No description provided for @profit_per_recipe.
  ///
  /// In en, this message translates to:
  /// **'Profit per Recipe'**
  String get profit_per_recipe;

  /// No description provided for @ingredient_name.
  ///
  /// In en, this message translates to:
  /// **'Ingredient Name'**
  String get ingredient_name;

  /// No description provided for @ingredient_cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get ingredient_cost;

  /// No description provided for @ingredient_quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get ingredient_quantity;

  /// No description provided for @unit_grams.
  ///
  /// In en, this message translates to:
  /// **'Grams'**
  String get unit_grams;

  /// No description provided for @unit_kilograms.
  ///
  /// In en, this message translates to:
  /// **'Kilograms'**
  String get unit_kilograms;

  /// No description provided for @unit_milliliters.
  ///
  /// In en, this message translates to:
  /// **'Milliliters'**
  String get unit_milliliters;

  /// No description provided for @unit_liters.
  ///
  /// In en, this message translates to:
  /// **'Liters'**
  String get unit_liters;

  /// No description provided for @unit_pieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get unit_pieces;

  /// No description provided for @unit_spoonfuls.
  ///
  /// In en, this message translates to:
  /// **'Spoonfuls'**
  String get unit_spoonfuls;

  /// No description provided for @unit_tablespoons.
  ///
  /// In en, this message translates to:
  /// **'Tablespoons'**
  String get unit_tablespoons;

  /// No description provided for @unit_teaspoons.
  ///
  /// In en, this message translates to:
  /// **'Teaspoons'**
  String get unit_teaspoons;

  /// No description provided for @unit_cups.
  ///
  /// In en, this message translates to:
  /// **'Cups'**
  String get unit_cups;

  /// No description provided for @unit_ounces.
  ///
  /// In en, this message translates to:
  /// **'Ounces'**
  String get unit_ounces;

  /// No description provided for @step_instruction.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get step_instruction;

  /// No description provided for @step_instruction_hint.
  ///
  /// In en, this message translates to:
  /// **'Describe the step...'**
  String get step_instruction_hint;

  /// No description provided for @save_button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_button;

  /// No description provided for @add_button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add_button;

  /// No description provided for @edit_button.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit_button;

  /// No description provided for @delete_button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete_button;

  /// No description provided for @duplicate_button.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate_button;

  /// No description provided for @delete_recipe_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Recipe'**
  String get delete_recipe_title;

  /// No description provided for @delete_recipe_message.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this recipe? This cannot be undone.'**
  String get delete_recipe_message;

  /// No description provided for @discard_button.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard_button;

  /// No description provided for @cancel_button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel_button;

  /// No description provided for @unsaved_changes_title.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsaved_changes_title;

  /// No description provided for @unsaved_changes_body.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save or discard this recipe?'**
  String get unsaved_changes_body;

  /// No description provided for @new_ingredient_button.
  ///
  /// In en, this message translates to:
  /// **'New Ingredient'**
  String get new_ingredient_button;

  /// No description provided for @config_button.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get config_button;

  /// No description provided for @recipe_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get recipe_steps;

  /// No description provided for @tools_title.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools_title;

  /// No description provided for @no_steps.
  ///
  /// In en, this message translates to:
  /// **'No steps added yet.'**
  String get no_steps;

  /// No description provided for @est_revenue.
  ///
  /// In en, this message translates to:
  /// **'Est. Revenue'**
  String get est_revenue;

  /// No description provided for @financial_targets.
  ///
  /// In en, this message translates to:
  /// **'Financial Targets'**
  String get financial_targets;

  /// No description provided for @financial_margin.
  ///
  /// In en, this message translates to:
  /// **'Total Margin'**
  String get financial_margin;

  /// No description provided for @financial_price.
  ///
  /// In en, this message translates to:
  /// **'Price per Portion'**
  String get financial_price;

  /// No description provided for @no_ingredients.
  ///
  /// In en, this message translates to:
  /// **'No ingredients added yet.'**
  String get no_ingredients;

  /// No description provided for @unit_portions.
  ///
  /// In en, this message translates to:
  /// **'Portions'**
  String get unit_portions;

  /// No description provided for @cost_per_portion.
  ///
  /// In en, this message translates to:
  /// **'Cost per Portion'**
  String get cost_per_portion;

  /// No description provided for @profit_per_portion.
  ///
  /// In en, this message translates to:
  /// **'Profit per Portion'**
  String get profit_per_portion;

  /// No description provided for @total_profit.
  ///
  /// In en, this message translates to:
  /// **'Total Profit'**
  String get total_profit;

  /// No description provided for @total_sale.
  ///
  /// In en, this message translates to:
  /// **'Total Sale'**
  String get total_sale;

  /// No description provided for @sale_per_portion.
  ///
  /// In en, this message translates to:
  /// **'Sale per Portion'**
  String get sale_per_portion;

  /// No description provided for @validation_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validation_required;

  /// No description provided for @profit_margin_helper.
  ///
  /// In en, this message translates to:
  /// **'Enter whole numbers (e.g., 35 for 35%)'**
  String get profit_margin_helper;

  /// No description provided for @assign_ingredients_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Assign ingredients to this step'**
  String get assign_ingredients_tooltip;

  /// No description provided for @select_ingredient_recipe_title.
  ///
  /// In en, this message translates to:
  /// **'Select Ingredient'**
  String get select_ingredient_recipe_title;

  /// No description provided for @assign_to_step_title.
  ///
  /// In en, this message translates to:
  /// **'Assign to Step {number}'**
  String assign_to_step_title(int number);

  /// No description provided for @mention_ingredient_title.
  ///
  /// In en, this message translates to:
  /// **'Mention Ingredient'**
  String get mention_ingredient_title;

  /// No description provided for @add_ingredients_first_error.
  ///
  /// In en, this message translates to:
  /// **'Add ingredients to the recipe first'**
  String get add_ingredients_first_error;

  /// No description provided for @assign_step_ingredients_first_error.
  ///
  /// In en, this message translates to:
  /// **'Assign ingredients to the step header (+)'**
  String get assign_step_ingredients_first_error;

  /// No description provided for @done_button.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done_button;

  /// No description provided for @add_ingredient_title.
  ///
  /// In en, this message translates to:
  /// **'Add Ingredient'**
  String get add_ingredient_title;

  /// No description provided for @edit_ingredient_title.
  ///
  /// In en, this message translates to:
  /// **'Edit Ingredient'**
  String get edit_ingredient_title;

  /// No description provided for @select_unit.
  ///
  /// In en, this message translates to:
  /// **'Select Unit'**
  String get select_unit;

  /// No description provided for @ingredient_price_per_quantity.
  ///
  /// In en, this message translates to:
  /// **'{price} per {quantity} {unit}'**
  String ingredient_price_per_quantity(
    String price,
    String quantity,
    String unit,
  );

  /// No description provided for @search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search_hint;

  /// No description provided for @search_ingredients_hint.
  ///
  /// In en, this message translates to:
  /// **'Search ingredients...'**
  String get search_ingredients_hint;

  /// No description provided for @no_ingredients_found.
  ///
  /// In en, this message translates to:
  /// **'No ingredients found.'**
  String get no_ingredients_found;

  /// No description provided for @no_recipes_found.
  ///
  /// In en, this message translates to:
  /// **'No recipes found.'**
  String get no_recipes_found;

  /// No description provided for @related_ingredients.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get related_ingredients;

  /// No description provided for @no_similar_ingredients.
  ///
  /// In en, this message translates to:
  /// **'No similar ingredients'**
  String get no_similar_ingredients;

  /// No description provided for @merge_button.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge_button;

  /// No description provided for @compare_button.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compare_button;

  /// No description provided for @merge_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Merge Ingredients?'**
  String get merge_confirm_title;

  /// No description provided for @merge_confirm_message.
  ///
  /// In en, this message translates to:
  /// **'This will replace all references to {oldName} with {newName} in your recipes. This action cannot be undone.'**
  String merge_confirm_message(String oldName, String newName);

  /// No description provided for @price_comparison.
  ///
  /// In en, this message translates to:
  /// **'Price Comparison'**
  String get price_comparison;

  /// No description provided for @error_select_unit.
  ///
  /// In en, this message translates to:
  /// **'Please select a unit'**
  String get error_select_unit;

  /// No description provided for @error_prefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error_prefix(String error);

  /// No description provided for @short_cost.
  ///
  /// In en, this message translates to:
  /// **'COST'**
  String get short_cost;

  /// No description provided for @short_profit.
  ///
  /// In en, this message translates to:
  /// **'PROFIT'**
  String get short_profit;

  /// No description provided for @short_price_portion.
  ///
  /// In en, this message translates to:
  /// **'P/PORTION'**
  String get short_price_portion;

  /// No description provided for @per_unit.
  ///
  /// In en, this message translates to:
  /// **'per'**
  String get per_unit;

  /// No description provided for @error_text.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error_text;

  /// No description provided for @scale_recipe_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Scale recipe (temporary view)'**
  String get scale_recipe_tooltip;

  /// No description provided for @temporary_view_title.
  ///
  /// In en, this message translates to:
  /// **'Temporary View'**
  String get temporary_view_title;

  /// No description provided for @temporary_view_banner.
  ///
  /// In en, this message translates to:
  /// **'This is a temporary view scaled by {multiplier}x. Changes will not be saved.'**
  String temporary_view_banner(String multiplier);

  /// No description provided for @scale_button.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scale_button;

  /// No description provided for @rule_of_three_title.
  ///
  /// In en, this message translates to:
  /// **'Rule of Three'**
  String get rule_of_three_title;

  /// No description provided for @rule_of_three_desc.
  ///
  /// In en, this message translates to:
  /// **'Calculate proportions easily for ingredient quantities and recipe yields.'**
  String get rule_of_three_desc;

  /// No description provided for @rule_of_three_if.
  ///
  /// In en, this message translates to:
  /// **'If'**
  String get rule_of_three_if;

  /// No description provided for @rule_of_three_corresponds.
  ///
  /// In en, this message translates to:
  /// **'corresponds to'**
  String get rule_of_three_corresponds;

  /// No description provided for @rule_of_three_then.
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get rule_of_three_then;

  /// No description provided for @rule_of_three_will_be.
  ///
  /// In en, this message translates to:
  /// **'will be'**
  String get rule_of_three_will_be;

  /// No description provided for @rule_of_three_result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get rule_of_three_result;

  /// No description provided for @rule_of_three_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get rule_of_three_clear;

  /// No description provided for @rule_of_three_example.
  ///
  /// In en, this message translates to:
  /// **'Example: If 100g of flour makes 10 portions, then to make 25 portions you need 250g of flour.'**
  String get rule_of_three_example;

  /// No description provided for @unit_converter_title.
  ///
  /// In en, this message translates to:
  /// **'Unit Converter'**
  String get unit_converter_title;

  /// No description provided for @unit_converter_desc.
  ///
  /// In en, this message translates to:
  /// **'Convert cooking units for mass, volume, and quantities easily.'**
  String get unit_converter_desc;

  /// No description provided for @unit_converter_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get unit_converter_category;

  /// No description provided for @unit_converter_from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get unit_converter_from;

  /// No description provided for @unit_converter_to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get unit_converter_to;

  /// No description provided for @unit_converter_value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get unit_converter_value;

  /// No description provided for @unit_converter_result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get unit_converter_result;

  /// No description provided for @unit_category_mass.
  ///
  /// In en, this message translates to:
  /// **'Weight / Mass'**
  String get unit_category_mass;

  /// No description provided for @unit_category_volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get unit_category_volume;

  /// No description provided for @unit_category_count.
  ///
  /// In en, this message translates to:
  /// **'Count / Quantity'**
  String get unit_category_count;

  /// No description provided for @settings_general.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get settings_general;

  /// No description provided for @settings_reset_db.
  ///
  /// In en, this message translates to:
  /// **'Reset Database'**
  String get settings_reset_db;

  /// No description provided for @settings_reset_db_desc.
  ///
  /// In en, this message translates to:
  /// **'Delete all recipes and ingredients. This cannot be undone.'**
  String get settings_reset_db_desc;

  /// No description provided for @settings_reset_db_confirm.
  ///
  /// In en, this message translates to:
  /// **'Reset Database?'**
  String get settings_reset_db_confirm;

  /// No description provided for @settings_reset_db_warning.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all recipes, ingredients, and steps? This action is permanent.'**
  String get settings_reset_db_warning;

  /// No description provided for @settings_reset_db_success.
  ///
  /// In en, this message translates to:
  /// **'Database reset successfully.'**
  String get settings_reset_db_success;

  /// No description provided for @settings_theme_title.
  ///
  /// In en, this message translates to:
  /// **'Theme & Style'**
  String get settings_theme_title;

  /// No description provided for @settings_theme_mode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get settings_theme_mode;

  /// No description provided for @settings_theme_color.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get settings_theme_color;

  /// No description provided for @settings_theme_system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settings_theme_system;

  /// No description provided for @settings_theme_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settings_theme_light;

  /// No description provided for @settings_theme_dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settings_theme_dark;

  /// No description provided for @settings_locale_title.
  ///
  /// In en, this message translates to:
  /// **'Localization & Formatting'**
  String get settings_locale_title;

  /// No description provided for @settings_locale_lang.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_locale_lang;

  /// No description provided for @settings_locale_es.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get settings_locale_es;

  /// No description provided for @settings_locale_en.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settings_locale_en;

  /// No description provided for @settings_format_decimals.
  ///
  /// In en, this message translates to:
  /// **'Decimal Places'**
  String get settings_format_decimals;

  /// No description provided for @settings_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_about;

  /// No description provided for @settings_version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settings_version;

  /// No description provided for @settings_font_size.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get settings_font_size;

  /// No description provided for @settings_font_size_small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get settings_font_size_small;

  /// No description provided for @settings_font_size_medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get settings_font_size_medium;

  /// No description provided for @settings_font_size_large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settings_font_size_large;

  /// No description provided for @settings_font_size_xlarge.
  ///
  /// In en, this message translates to:
  /// **'X-Large'**
  String get settings_font_size_xlarge;

  /// No description provided for @settings_styles_title.
  ///
  /// In en, this message translates to:
  /// **'Styles'**
  String get settings_styles_title;

  /// No description provided for @settings_about_app_title.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get settings_about_app_title;

  /// No description provided for @settings_haptic_feedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get settings_haptic_feedback;

  /// No description provided for @settings_haptic_feedback_desc.
  ///
  /// In en, this message translates to:
  /// **'Enable system vibrations on buttons and interactions'**
  String get settings_haptic_feedback_desc;

  /// No description provided for @settings_styles_m3.
  ///
  /// In en, this message translates to:
  /// **'Use Material 3'**
  String get settings_styles_m3;

  /// No description provided for @settings_styles_m3_desc.
  ///
  /// In en, this message translates to:
  /// **'Enable modern Material 3 styling and components'**
  String get settings_styles_m3_desc;

  /// No description provided for @settings_styles_icon_style.
  ///
  /// In en, this message translates to:
  /// **'Icon Style'**
  String get settings_styles_icon_style;

  /// No description provided for @settings_styles_icon_style_outlined.
  ///
  /// In en, this message translates to:
  /// **'Outlined'**
  String get settings_styles_icon_style_outlined;

  /// No description provided for @settings_styles_icon_style_rounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded'**
  String get settings_styles_icon_style_rounded;

  /// No description provided for @settings_styles_icon_style_sharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get settings_styles_icon_style_sharp;

  /// No description provided for @settings_styles_number_colors.
  ///
  /// In en, this message translates to:
  /// **'Colorize Numbers'**
  String get settings_styles_number_colors;

  /// No description provided for @settings_styles_number_colors_desc.
  ///
  /// In en, this message translates to:
  /// **'Use semantic colors for financial metrics'**
  String get settings_styles_number_colors_desc;

  /// No description provided for @settings_styles_animations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settings_styles_animations;

  /// No description provided for @settings_styles_animations_desc.
  ///
  /// In en, this message translates to:
  /// **'Enable screen transitions and micro-animations'**
  String get settings_styles_animations_desc;

  /// No description provided for @settings_styles_scroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll Behavior'**
  String get settings_styles_scroll;

  /// No description provided for @settings_styles_scroll_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settings_styles_scroll_default;

  /// No description provided for @settings_styles_scroll_simple.
  ///
  /// In en, this message translates to:
  /// **'Simple (Clamp)'**
  String get settings_styles_scroll_simple;

  /// No description provided for @settings_styles_scroll_stretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get settings_styles_scroll_stretch;

  /// No description provided for @settings_styles_scroll_bounce.
  ///
  /// In en, this message translates to:
  /// **'Bounce'**
  String get settings_styles_scroll_bounce;

  /// No description provided for @settings_styles_left_hand.
  ///
  /// In en, this message translates to:
  /// **'Left-Handed Mode'**
  String get settings_styles_left_hand;

  /// No description provided for @settings_styles_left_hand_desc.
  ///
  /// In en, this message translates to:
  /// **'Mirror controls for easier left-hand use'**
  String get settings_styles_left_hand_desc;

  /// No description provided for @settings_styles_high_contrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast Text'**
  String get settings_styles_high_contrast;

  /// No description provided for @settings_styles_high_contrast_desc.
  ///
  /// In en, this message translates to:
  /// **'Force pure black/white text for readability'**
  String get settings_styles_high_contrast_desc;

  /// No description provided for @settings_styles_font.
  ///
  /// In en, this message translates to:
  /// **'Font Family'**
  String get settings_styles_font;

  /// No description provided for @settings_styles_font_system.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settings_styles_font_system;

  /// No description provided for @settings_styles_font_sans.
  ///
  /// In en, this message translates to:
  /// **'Metropolis'**
  String get settings_styles_font_sans;

  /// No description provided for @settings_styles_font_serif.
  ///
  /// In en, this message translates to:
  /// **'Nunito'**
  String get settings_styles_font_serif;

  /// No description provided for @settings_styles_font_mono.
  ///
  /// In en, this message translates to:
  /// **'Inconsolata Monospace'**
  String get settings_styles_font_mono;

  /// No description provided for @settings_styles_font_amatic.
  ///
  /// In en, this message translates to:
  /// **'Amatic SC'**
  String get settings_styles_font_amatic;

  /// No description provided for @settings_styles_font_butler.
  ///
  /// In en, this message translates to:
  /// **'Butler'**
  String get settings_styles_font_butler;

  /// No description provided for @settings_styles_font_caveat.
  ///
  /// In en, this message translates to:
  /// **'Caveat'**
  String get settings_styles_font_caveat;

  /// No description provided for @settings_styles_show_nav_labels.
  ///
  /// In en, this message translates to:
  /// **'Show Navigation Labels'**
  String get settings_styles_show_nav_labels;

  /// No description provided for @settings_styles_show_nav_labels_desc.
  ///
  /// In en, this message translates to:
  /// **'Display text labels below the navigation bar icons'**
  String get settings_styles_show_nav_labels_desc;

  /// No description provided for @settings_styles_navbar_size.
  ///
  /// In en, this message translates to:
  /// **'Navigation Bar Size'**
  String get settings_styles_navbar_size;

  /// No description provided for @settings_styles_navbar_size_desc.
  ///
  /// In en, this message translates to:
  /// **'Adjust the height and icon scale of the navigation bar'**
  String get settings_styles_navbar_size_desc;

  /// No description provided for @settings_styles_navbar_size_compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settings_styles_navbar_size_compact;

  /// No description provided for @settings_styles_navbar_size_normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get settings_styles_navbar_size_normal;

  /// No description provided for @settings_styles_navbar_size_large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get settings_styles_navbar_size_large;

  /// No description provided for @settings_format_mass_unit.
  ///
  /// In en, this message translates to:
  /// **'Default Mass Unit'**
  String get settings_format_mass_unit;

  /// No description provided for @settings_format_volume_unit.
  ///
  /// In en, this message translates to:
  /// **'Default Volume Unit'**
  String get settings_format_volume_unit;

  /// No description provided for @settings_format_decimals_1.
  ///
  /// In en, this message translates to:
  /// **'1 Place'**
  String get settings_format_decimals_1;

  /// No description provided for @settings_format_decimals_2.
  ///
  /// In en, this message translates to:
  /// **'2 Places'**
  String get settings_format_decimals_2;

  /// No description provided for @settings_format_decimals_3.
  ///
  /// In en, this message translates to:
  /// **'3 Places'**
  String get settings_format_decimals_3;

  /// No description provided for @settings_format_decimals_4.
  ///
  /// In en, this message translates to:
  /// **'4 Places'**
  String get settings_format_decimals_4;

  /// No description provided for @settings_format_mass_g.
  ///
  /// In en, this message translates to:
  /// **'Grams (g)'**
  String get settings_format_mass_g;

  /// No description provided for @settings_format_mass_kg.
  ///
  /// In en, this message translates to:
  /// **'Kilograms (kg)'**
  String get settings_format_mass_kg;

  /// No description provided for @settings_format_volume_ml.
  ///
  /// In en, this message translates to:
  /// **'Milliliters (ml)'**
  String get settings_format_volume_ml;

  /// No description provided for @settings_format_volume_l.
  ///
  /// In en, this message translates to:
  /// **'Liters (l)'**
  String get settings_format_volume_l;

  /// No description provided for @settings_format_currency.
  ///
  /// In en, this message translates to:
  /// **'Currency Symbol'**
  String get settings_format_currency;

  /// No description provided for @cloud_sync_title.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloud_sync_title;

  /// No description provided for @cloud_sync_desc.
  ///
  /// In en, this message translates to:
  /// **'Back up and restore your recipes and ingredients securely using your Google Drive AppData folder.'**
  String get cloud_sync_desc;

  /// No description provided for @cloud_sync_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected to Google Drive'**
  String get cloud_sync_connected;

  /// No description provided for @cloud_sync_disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get cloud_sync_disconnected;

  /// No description provided for @cloud_sync_connect_btn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get cloud_sync_connect_btn;

  /// No description provided for @cloud_sync_disconnect_btn.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get cloud_sync_disconnect_btn;

  /// No description provided for @cloud_sync_backup_btn.
  ///
  /// In en, this message translates to:
  /// **'Back Up Now'**
  String get cloud_sync_backup_btn;

  /// No description provided for @cloud_sync_backups_header.
  ///
  /// In en, this message translates to:
  /// **'Backups History'**
  String get cloud_sync_backups_header;

  /// No description provided for @cloud_sync_no_backups.
  ///
  /// In en, this message translates to:
  /// **'No backups found.'**
  String get cloud_sync_no_backups;

  /// No description provided for @cloud_sync_backup_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get cloud_sync_backup_confirm_title;

  /// No description provided for @cloud_sync_backup_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'This will upload a copy of your current database to Google Drive.'**
  String get cloud_sync_backup_confirm_desc;

  /// No description provided for @cloud_sync_restore_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get cloud_sync_restore_confirm_title;

  /// No description provided for @cloud_sync_restore_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite all current recipes, steps, and ingredients with the selected backup. This action cannot be undone.'**
  String get cloud_sync_restore_confirm_desc;

  /// No description provided for @cloud_sync_delete_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Backup'**
  String get cloud_sync_delete_confirm_title;

  /// No description provided for @cloud_sync_delete_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this backup from Google Drive?'**
  String get cloud_sync_delete_confirm_desc;

  /// No description provided for @cloud_sync_sandbox_badge.
  ///
  /// In en, this message translates to:
  /// **'Local Backup'**
  String get cloud_sync_sandbox_badge;

  /// No description provided for @cloud_sync_sandbox_desc.
  ///
  /// In en, this message translates to:
  /// **'Data is backed up to a local directory on your device.'**
  String get cloud_sync_sandbox_desc;

  /// No description provided for @cloud_sync_sync_btn.
  ///
  /// In en, this message translates to:
  /// **'Two-Way Cloud Sync'**
  String get cloud_sync_sync_btn;

  /// No description provided for @cloud_sync_sync_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Two-Way Cloud Sync'**
  String get cloud_sync_sync_confirm_title;

  /// No description provided for @cloud_sync_sync_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'This will merge your local recipes and ingredients with your cloud backup. Conflicts are resolved using last-write-wins based on modification timestamps. Local records and newer edits will not be wiped.'**
  String get cloud_sync_sync_confirm_desc;

  /// No description provided for @cloud_sync_sync_with_backup_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'This will merge your local recipes and ingredients with this backup. Conflicts are resolved using last-write-wins based on modification timestamps. Local records and newer edits will not be wiped.'**
  String get cloud_sync_sync_with_backup_confirm_desc;

  /// No description provided for @cloud_sync_merge_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Merge with local database'**
  String get cloud_sync_merge_tooltip;

  /// No description provided for @timers_title.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Timers'**
  String get timers_title;

  /// No description provided for @timers_desc.
  ///
  /// In en, this message translates to:
  /// **'Run multiple cooking and baking timers simultaneously in the background.'**
  String get timers_desc;

  /// No description provided for @timers_add_title.
  ///
  /// In en, this message translates to:
  /// **'New Timer'**
  String get timers_add_title;

  /// No description provided for @timers_timer_name.
  ///
  /// In en, this message translates to:
  /// **'Timer Name'**
  String get timers_timer_name;

  /// No description provided for @timers_duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get timers_duration;

  /// No description provided for @timers_no_timers.
  ///
  /// In en, this message translates to:
  /// **'No active timers.'**
  String get timers_no_timers;

  /// No description provided for @timers_no_timers_desc.
  ///
  /// In en, this message translates to:
  /// **'Create a new timer to start cooking!'**
  String get timers_no_timers_desc;

  /// No description provided for @timers_finished.
  ///
  /// In en, this message translates to:
  /// **'Timer Finished!'**
  String get timers_finished;

  /// No description provided for @filter_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filter_all;

  /// No description provided for @filter_solids.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get filter_solids;

  /// No description provided for @filter_liquids.
  ///
  /// In en, this message translates to:
  /// **'Liquids'**
  String get filter_liquids;

  /// No description provided for @filter_pieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get filter_pieces;

  /// No description provided for @filter_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter ingredients'**
  String get filter_tooltip;

  /// No description provided for @sort_by.
  ///
  /// In en, this message translates to:
  /// **'Sort:'**
  String get sort_by;

  /// No description provided for @sort_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get sort_default;

  /// No description provided for @sort_type.
  ///
  /// In en, this message translates to:
  /// **'Type (Solid / Liquid / Pieces)'**
  String get sort_type;

  /// No description provided for @sort_alphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sort_alphabetical;

  /// No description provided for @sort_solids.
  ///
  /// In en, this message translates to:
  /// **'Solids'**
  String get sort_solids;

  /// No description provided for @sort_liquids.
  ///
  /// In en, this message translates to:
  /// **'Liquids'**
  String get sort_liquids;

  /// No description provided for @sort_pieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get sort_pieces;

  /// No description provided for @staged_ingredients_title.
  ///
  /// In en, this message translates to:
  /// **'Save selected ingredients?'**
  String get staged_ingredients_title;

  /// No description provided for @staged_ingredients_body.
  ///
  /// In en, this message translates to:
  /// **'You have staged ingredients. Do you want to add them to the recipe or discard changes?'**
  String get staged_ingredients_body;

  /// No description provided for @add_custom_ingredient.
  ///
  /// In en, this message translates to:
  /// **'Add \'{name}\''**
  String add_custom_ingredient(String name);

  /// No description provided for @total_weight.
  ///
  /// In en, this message translates to:
  /// **'Total Weight'**
  String get total_weight;

  /// No description provided for @total_volume.
  ///
  /// In en, this message translates to:
  /// **'Total Volume'**
  String get total_volume;

  /// No description provided for @scale_by_ingredient.
  ///
  /// In en, this message translates to:
  /// **'Scale by Ingredient'**
  String get scale_by_ingredient;

  /// No description provided for @scale_by_ingredient_desc.
  ///
  /// In en, this message translates to:
  /// **'Adjust recipe quantities based on target amount of an ingredient'**
  String get scale_by_ingredient_desc;

  /// No description provided for @target_quantity.
  ///
  /// In en, this message translates to:
  /// **'Target Quantity'**
  String get target_quantity;

  /// No description provided for @current_quantity.
  ///
  /// In en, this message translates to:
  /// **'Current Quantity'**
  String get current_quantity;

  /// No description provided for @scale_factor_label.
  ///
  /// In en, this message translates to:
  /// **'Scale Factor: {factor}x'**
  String scale_factor_label(String factor);

  /// No description provided for @scale_preview_button.
  ///
  /// In en, this message translates to:
  /// **'Preview Scaling'**
  String get scale_preview_button;

  /// No description provided for @select_ingredient.
  ///
  /// In en, this message translates to:
  /// **'Select Ingredient'**
  String get select_ingredient;

  /// No description provided for @scale_temporary_title.
  ///
  /// In en, this message translates to:
  /// **'Temporary Scaled View ({multiplier}x)'**
  String scale_temporary_title(String multiplier);

  /// No description provided for @scale_temporary_notice.
  ///
  /// In en, this message translates to:
  /// **'This scaling is temporary and does not change your real recipe in the database.'**
  String get scale_temporary_notice;

  /// No description provided for @scale_revert_button.
  ///
  /// In en, this message translates to:
  /// **'Revert to Original'**
  String get scale_revert_button;

  /// No description provided for @scale_save_as_real_button.
  ///
  /// In en, this message translates to:
  /// **'Save as Real Recipe'**
  String get scale_save_as_real_button;

  /// No description provided for @scale_reverted_toast.
  ///
  /// In en, this message translates to:
  /// **'Recipe reverted to original quantities'**
  String get scale_reverted_toast;

  /// No description provided for @scale_saved_toast.
  ///
  /// In en, this message translates to:
  /// **'Scaled quantities saved to the real recipe'**
  String get scale_saved_toast;

  /// No description provided for @brand_home_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Chef&Cost - Home'**
  String get brand_home_tooltip;

  /// No description provided for @back_to_home_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get back_to_home_tooltip;

  /// No description provided for @back_button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back_button;

  /// No description provided for @close_button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close_button;

  /// No description provided for @apply_button.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply_button;

  /// No description provided for @save_changes_button.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get save_changes_button;

  /// No description provided for @view_button.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view_button;

  /// No description provided for @sign_in_button.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get sign_in_button;

  /// No description provided for @toggle_theme_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle Theme'**
  String get toggle_theme_tooltip;

  /// No description provided for @search_recipes_hint.
  ///
  /// In en, this message translates to:
  /// **'Search recipes...'**
  String get search_recipes_hint;

  /// No description provided for @sample_data_loaded_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Sample data loaded: {recipes} recipes and {ingredients} ingredients'**
  String sample_data_loaded_snackbar(int recipes, int ingredients);

  /// No description provided for @load_sample_data.
  ///
  /// In en, this message translates to:
  /// **'Load sample data'**
  String get load_sample_data;

  /// No description provided for @timer_finished_banner.
  ///
  /// In en, this message translates to:
  /// **'Timer Finished!'**
  String get timer_finished_banner;

  /// No description provided for @timer_finished_at.
  ///
  /// In en, this message translates to:
  /// **'Finished at {time}'**
  String timer_finished_at(String time);

  /// No description provided for @delete_ingredient_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Ingredient?'**
  String get delete_ingredient_title;

  /// No description provided for @delete_ingredient_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\" from the database?'**
  String delete_ingredient_confirm(String name);

  /// No description provided for @unsaved_changes_ingredient_body.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save or discard changes to this ingredient?'**
  String get unsaved_changes_ingredient_body;

  /// No description provided for @recipe_editor_add_ingredients_to_scale.
  ///
  /// In en, this message translates to:
  /// **'Add ingredients to recipe before scaling'**
  String get recipe_editor_add_ingredients_to_scale;

  /// No description provided for @recipe_editor_please_enter_name.
  ///
  /// In en, this message translates to:
  /// **'Please enter a recipe name'**
  String get recipe_editor_please_enter_name;

  /// No description provided for @recipe_duplicated_success.
  ///
  /// In en, this message translates to:
  /// **'Recipe duplicated successfully'**
  String get recipe_duplicated_success;

  /// No description provided for @apply_to_recipe_button.
  ///
  /// In en, this message translates to:
  /// **'Apply to Recipe'**
  String get apply_to_recipe_button;

  /// No description provided for @recipe_duplicate_name.
  ///
  /// In en, this message translates to:
  /// **'{name} ({copyLabel})'**
  String recipe_duplicate_name(String name, String copyLabel);

  /// No description provided for @financial_summary_title.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get financial_summary_title;

  /// No description provided for @financial_costs_section.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get financial_costs_section;

  /// No description provided for @financial_margin_pricing_section.
  ///
  /// In en, this message translates to:
  /// **'Margin & Pricing'**
  String get financial_margin_pricing_section;

  /// No description provided for @financial_results_section.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get financial_results_section;

  /// No description provided for @financial_total_revenue.
  ///
  /// In en, this message translates to:
  /// **'Total Gross Revenue'**
  String get financial_total_revenue;

  /// No description provided for @recipe_stats_section.
  ///
  /// In en, this message translates to:
  /// **'Recipe Stats'**
  String get recipe_stats_section;

  /// No description provided for @hide_financial_summary.
  ///
  /// In en, this message translates to:
  /// **'Hide Financial Summary'**
  String get hide_financial_summary;

  /// No description provided for @show_financial_summary.
  ///
  /// In en, this message translates to:
  /// **'Show Financial Summary'**
  String get show_financial_summary;

  /// No description provided for @recipe_editor_live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get recipe_editor_live;

  /// No description provided for @recipe_editor_other_category.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recipe_editor_other_category;

  /// No description provided for @recipe_timers_section.
  ///
  /// In en, this message translates to:
  /// **'Recipe Timers'**
  String get recipe_timers_section;

  /// No description provided for @recipe_timer_single.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get recipe_timer_single;

  /// No description provided for @recipe_timers_title.
  ///
  /// In en, this message translates to:
  /// **'Timers'**
  String get recipe_timers_title;

  /// No description provided for @recipe_timer_add_badge.
  ///
  /// In en, this message translates to:
  /// **'+ Timer'**
  String get recipe_timer_add_badge;

  /// No description provided for @start_timer_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get start_timer_tooltip;

  /// No description provided for @timer_started_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Timer started: {name} ({duration})'**
  String timer_started_snackbar(String name, String duration);

  /// No description provided for @recipe_timer_edit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit Recipe Timer'**
  String get recipe_timer_edit_title;

  /// No description provided for @recipe_timer_add_title.
  ///
  /// In en, this message translates to:
  /// **'Add Recipe Timer'**
  String get recipe_timer_add_title;

  /// No description provided for @recipe_timer_name_label.
  ///
  /// In en, this message translates to:
  /// **'Timer label'**
  String get recipe_timer_name_label;

  /// No description provided for @recipe_timer_name_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Boil Noodles, Bake'**
  String get recipe_timer_name_hint;

  /// No description provided for @add_timer_preset_button.
  ///
  /// In en, this message translates to:
  /// **'Add Timer Preset'**
  String get add_timer_preset_button;

  /// No description provided for @edit_ingredient_action.
  ///
  /// In en, this message translates to:
  /// **'Edit ingredient'**
  String get edit_ingredient_action;

  /// No description provided for @edit_ingredient_action_desc.
  ///
  /// In en, this message translates to:
  /// **'Modify name, cost, quantity or unit in the database'**
  String get edit_ingredient_action_desc;

  /// No description provided for @merge_ingredient_action.
  ///
  /// In en, this message translates to:
  /// **'Merge ingredient'**
  String get merge_ingredient_action;

  /// No description provided for @merge_ingredient_action_desc.
  ///
  /// In en, this message translates to:
  /// **'Add amount into another ingredient in this recipe'**
  String get merge_ingredient_action_desc;

  /// No description provided for @delete_ingredient_action.
  ///
  /// In en, this message translates to:
  /// **'Delete ingredient'**
  String get delete_ingredient_action;

  /// No description provided for @delete_ingredient_action_desc.
  ///
  /// In en, this message translates to:
  /// **'Remove ingredient from this recipe'**
  String get delete_ingredient_action_desc;

  /// No description provided for @merge_ingredient_title.
  ///
  /// In en, this message translates to:
  /// **'Merge Ingredient'**
  String get merge_ingredient_title;

  /// No description provided for @merge_ingredient_into_prompt.
  ///
  /// In en, this message translates to:
  /// **'Merge \"{name}\" into:'**
  String merge_ingredient_into_prompt(String name);

  /// No description provided for @compare_merged_success.
  ///
  /// In en, this message translates to:
  /// **'Merged successfully'**
  String get compare_merged_success;

  /// No description provided for @compare_no_units_error.
  ///
  /// In en, this message translates to:
  /// **'DATABASE ERROR: No units loaded. Please restart the app.'**
  String get compare_no_units_error;

  /// No description provided for @compare_more_costly.
  ///
  /// In en, this message translates to:
  /// **'+{amount} MORE'**
  String compare_more_costly(String amount);

  /// No description provided for @compare_less_costly.
  ///
  /// In en, this message translates to:
  /// **'-{amount} LESS'**
  String compare_less_costly(String amount);

  /// No description provided for @compare_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading comparison data...'**
  String get compare_loading;

  /// No description provided for @timers_running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get timers_running;

  /// No description provided for @timers_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get timers_paused;

  /// No description provided for @timers_stop_alarm.
  ///
  /// In en, this message translates to:
  /// **'STOP ALARM'**
  String get timers_stop_alarm;

  /// No description provided for @timers_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get timers_reset;

  /// No description provided for @timers_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get timers_pause;

  /// No description provided for @timers_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get timers_start;

  /// No description provided for @timers_start_timer.
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get timers_start_timer;

  /// No description provided for @timers_edit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit Timer'**
  String get timers_edit_title;

  /// No description provided for @timers_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Boil Potatoes'**
  String get timers_hint;

  /// No description provided for @timers_min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get timers_min;

  /// No description provided for @timers_sec.
  ///
  /// In en, this message translates to:
  /// **'Sec'**
  String get timers_sec;

  /// No description provided for @timers_add_minutes.
  ///
  /// In en, this message translates to:
  /// **'+{minutes}m'**
  String timers_add_minutes(int minutes);

  /// No description provided for @rule_of_three_error_zero.
  ///
  /// In en, this message translates to:
  /// **'Initial value cannot be zero'**
  String get rule_of_three_error_zero;

  /// No description provided for @rule_of_three_explanation.
  ///
  /// In en, this message translates to:
  /// **'If {a} corresponds to {b}, then {c} will correspond to {result}.'**
  String rule_of_three_explanation(String a, String b, String c, String result);

  /// No description provided for @cloud_sync_sync_target.
  ///
  /// In en, this message translates to:
  /// **'Sync Target'**
  String get cloud_sync_sync_target;

  /// No description provided for @cloud_sync_target_firestore.
  ///
  /// In en, this message translates to:
  /// **'Firestore'**
  String get cloud_sync_target_firestore;

  /// No description provided for @cloud_sync_target_drive.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get cloud_sync_target_drive;

  /// No description provided for @cloud_sync_target_local.
  ///
  /// In en, this message translates to:
  /// **'Local Directory'**
  String get cloud_sync_target_local;

  /// No description provided for @cloud_sync_desc_web.
  ///
  /// In en, this message translates to:
  /// **'On Web, sync is powered by Cloud Firestore to synchronize data in real-time between your browser and mobile app. Google Drive file backups are available on mobile and desktop devices.'**
  String get cloud_sync_desc_web;

  /// No description provided for @cloud_sync_desc_firestore.
  ///
  /// In en, this message translates to:
  /// **'Real-time cross-platform sync between Web and Mobile via Cloud Firestore.'**
  String get cloud_sync_desc_firestore;

  /// No description provided for @cloud_sync_desc_local.
  ///
  /// In en, this message translates to:
  /// **'Local Directory mode stores your backups in the device\'s local storage. It does not require internet connection or a Google Account.'**
  String get cloud_sync_desc_local;

  /// No description provided for @cloud_sync_switch_account.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get cloud_sync_switch_account;

  /// No description provided for @cloud_sync_sync_now.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get cloud_sync_sync_now;

  /// No description provided for @cloud_sync_save_copy_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Select folder to save backup'**
  String get cloud_sync_save_copy_dialog_title;

  /// No description provided for @cloud_sync_save_copy_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Save backup to...'**
  String get cloud_sync_save_copy_tooltip;

  /// No description provided for @cloud_sync_restore_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get cloud_sync_restore_tooltip;

  /// No description provided for @cloud_sync_delete_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cloud_sync_delete_tooltip;

  /// No description provided for @cloud_sync_connect_account_title.
  ///
  /// In en, this message translates to:
  /// **'Connect Your Account'**
  String get cloud_sync_connect_account_title;

  /// No description provided for @cloud_sync_connect_account_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your recipes in real-time across Web and Mobile'**
  String get cloud_sync_connect_account_subtitle;

  /// No description provided for @cloud_sync_continue_google.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get cloud_sync_continue_google;

  /// No description provided for @cloud_sync_or_email.
  ///
  /// In en, this message translates to:
  /// **'or with email'**
  String get cloud_sync_or_email;

  /// No description provided for @cloud_sync_create_account.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get cloud_sync_create_account;

  /// No description provided for @cloud_sync_email_label.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get cloud_sync_email_label;

  /// No description provided for @cloud_sync_email_hint.
  ///
  /// In en, this message translates to:
  /// **'example@mail.com'**
  String get cloud_sync_email_hint;

  /// No description provided for @cloud_sync_password_label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get cloud_sync_password_label;

  /// No description provided for @cloud_sync_password_hint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get cloud_sync_password_hint;

  /// No description provided for @cloud_sync_forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get cloud_sync_forgot_password;

  /// No description provided for @cloud_sync_connected_to_firestore.
  ///
  /// In en, this message translates to:
  /// **'Connected to Firestore'**
  String get cloud_sync_connected_to_firestore;

  /// No description provided for @cloud_sync_authenticated_user.
  ///
  /// In en, this message translates to:
  /// **'Authenticated user'**
  String get cloud_sync_authenticated_user;

  /// No description provided for @cloud_sync_sign_out_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get cloud_sync_sign_out_confirm_title;

  /// No description provided for @cloud_sync_sign_out_confirm_message.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out from Firestore sync?'**
  String get cloud_sync_sign_out_confirm_message;

  /// No description provided for @cloud_sync_error_invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get cloud_sync_error_invalid_email;

  /// No description provided for @cloud_sync_error_short_password.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get cloud_sync_error_short_password;

  /// No description provided for @cloud_sync_reset_email_sent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent! Check your inbox.'**
  String get cloud_sync_reset_email_sent;

  /// No description provided for @cloud_sync_connected_account.
  ///
  /// In en, this message translates to:
  /// **'Connected account'**
  String get cloud_sync_connected_account;

  /// No description provided for @settings_category_data_subtitle.
  ///
  /// In en, this message translates to:
  /// **'App data management'**
  String get settings_category_data_subtitle;

  /// No description provided for @settings_category_backup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up and restore on Google Drive'**
  String get settings_category_backup_subtitle;

  /// No description provided for @settings_category_themes_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Themes, colors and font size'**
  String get settings_category_themes_subtitle;

  /// No description provided for @settings_category_locale_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Language and number formatting'**
  String get settings_category_locale_subtitle;

  /// No description provided for @settings_category_info_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Version and information'**
  String get settings_category_info_subtitle;

  /// No description provided for @settings_sample_data_dialog_message.
  ///
  /// In en, this message translates to:
  /// **'Do you want to add the sample recipes to your existing list, or replace all current database contents?'**
  String get settings_sample_data_dialog_message;

  /// No description provided for @settings_sample_data_add_button.
  ///
  /// In en, this message translates to:
  /// **'Add to current'**
  String get settings_sample_data_add_button;

  /// No description provided for @settings_sample_data_replace_button.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get settings_sample_data_replace_button;

  /// No description provided for @settings_sample_data_replaced_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Database replaced with sample data ({recipes} recipes, {ingredients} ingredients)'**
  String settings_sample_data_replaced_snackbar(int recipes, int ingredients);

  /// No description provided for @settings_sample_data_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Load test ingredients and recipes to evaluate the app'**
  String get settings_sample_data_subtitle;

  /// No description provided for @settings_brand_theme_adapt_notice.
  ///
  /// In en, this message translates to:
  /// **'The icon and branding adapt to your selected theme'**
  String get settings_brand_theme_adapt_notice;

  /// No description provided for @scale_multiplier_button.
  ///
  /// In en, this message translates to:
  /// **'x{multiplier}'**
  String scale_multiplier_button(String multiplier);

  /// No description provided for @scale_custom_multiplier_hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1.5'**
  String get scale_custom_multiplier_hint;

  /// No description provided for @scaled_recipe_name.
  ///
  /// In en, this message translates to:
  /// **'{name} (x{multiplier})'**
  String scaled_recipe_name(String name, String multiplier);

  /// No description provided for @merge_no_other_ingredients.
  ///
  /// In en, this message translates to:
  /// **'No other ingredients in this recipe to merge into.'**
  String get merge_no_other_ingredients;

  /// No description provided for @merge_no_other_database_ingredients.
  ///
  /// In en, this message translates to:
  /// **'No other ingredients in the database to merge into.'**
  String get merge_no_other_database_ingredients;

  /// No description provided for @merge_ingredient_action_db_desc.
  ///
  /// In en, this message translates to:
  /// **'Merge into another ingredient in the database'**
  String get merge_ingredient_action_db_desc;

  /// No description provided for @delete_ingredient_permanent_desc.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete from database'**
  String get delete_ingredient_permanent_desc;

  /// No description provided for @ingredient_deleted_snackbar.
  ///
  /// In en, this message translates to:
  /// **'Ingredient \"{name}\" deleted.'**
  String ingredient_deleted_snackbar(String name);

  /// No description provided for @no_timers_in_recipe.
  ///
  /// In en, this message translates to:
  /// **'No timer presets added to this recipe.'**
  String get no_timers_in_recipe;

  /// No description provided for @recipe_timer_min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get recipe_timer_min;

  /// No description provided for @recipe_timer_sec.
  ///
  /// In en, this message translates to:
  /// **'Sec'**
  String get recipe_timer_sec;

  /// No description provided for @gain_per_portion.
  ///
  /// In en, this message translates to:
  /// **'Gain/Portion'**
  String get gain_per_portion;

  /// No description provided for @price_per_portion.
  ///
  /// In en, this message translates to:
  /// **'Price/Portion'**
  String get price_per_portion;

  /// No description provided for @force_overwrite_danger_zone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get force_overwrite_danger_zone;

  /// No description provided for @force_overwrite_cloud_btn.
  ///
  /// In en, this message translates to:
  /// **'Force Overwrite Cloud'**
  String get force_overwrite_cloud_btn;

  /// No description provided for @force_overwrite_first_confirm_title.
  ///
  /// In en, this message translates to:
  /// **'Force Overwrite Cloud'**
  String get force_overwrite_first_confirm_title;

  /// No description provided for @force_overwrite_first_confirm_desc.
  ///
  /// In en, this message translates to:
  /// **'This will permanently OVERWRITE all cloud data with your local copy. This action is irreversible.'**
  String get force_overwrite_first_confirm_desc;

  /// No description provided for @force_overwrite_understand_risk.
  ///
  /// In en, this message translates to:
  /// **'Yes, I understand the risk'**
  String get force_overwrite_understand_risk;

  /// No description provided for @force_overwrite_challenge_title.
  ///
  /// In en, this message translates to:
  /// **'Type OVERWRITE to Confirm'**
  String get force_overwrite_challenge_title;

  /// No description provided for @force_overwrite_challenge_desc.
  ///
  /// In en, this message translates to:
  /// **'To prevent accidental loss, please type OVERWRITE below to proceed.'**
  String get force_overwrite_challenge_desc;

  /// No description provided for @force_overwrite_challenge_placeholder.
  ///
  /// In en, this message translates to:
  /// **'OVERWRITE'**
  String get force_overwrite_challenge_placeholder;

  /// No description provided for @force_overwrite_confirm_final_btn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Overwrite'**
  String get force_overwrite_confirm_final_btn;

  /// No description provided for @force_overwrite_success_toast.
  ///
  /// In en, this message translates to:
  /// **'Cloud data successfully overwritten with local copy.'**
  String get force_overwrite_success_toast;

  /// No description provided for @force_overwrite_failure_toast.
  ///
  /// In en, this message translates to:
  /// **'Failed to overwrite cloud data.'**
  String get force_overwrite_failure_toast;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'af',
    'am',
    'ar',
    'az',
    'bg',
    'bn',
    'ca',
    'cs',
    'da',
    'de',
    'el',
    'en',
    'eo',
    'es',
    'fa',
    'fi',
    'fr',
    'gu',
    'he',
    'hi',
    'hr',
    'ht',
    'hu',
    'id',
    'it',
    'ja',
    'km',
    'ko',
    'kxd',
    'lt',
    'mk',
    'ml',
    'mr',
    'ms',
    'nb',
    'nl',
    'pl',
    'pt',
    'ro',
    'ru',
    'si',
    'sk',
    'sr',
    'sv',
    'sw',
    'ta',
    'te',
    'th',
    'tl',
    'tr',
    'uk',
    'ur',
    'uz',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'PT':
            return AppLocalizationsPtPt();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'am':
      return AppLocalizationsAm();
    case 'ar':
      return AppLocalizationsAr();
    case 'az':
      return AppLocalizationsAz();
    case 'bg':
      return AppLocalizationsBg();
    case 'bn':
      return AppLocalizationsBn();
    case 'ca':
      return AppLocalizationsCa();
    case 'cs':
      return AppLocalizationsCs();
    case 'da':
      return AppLocalizationsDa();
    case 'de':
      return AppLocalizationsDe();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'eo':
      return AppLocalizationsEo();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'gu':
      return AppLocalizationsGu();
    case 'he':
      return AppLocalizationsHe();
    case 'hi':
      return AppLocalizationsHi();
    case 'hr':
      return AppLocalizationsHr();
    case 'ht':
      return AppLocalizationsHt();
    case 'hu':
      return AppLocalizationsHu();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'km':
      return AppLocalizationsKm();
    case 'ko':
      return AppLocalizationsKo();
    case 'kxd':
      return AppLocalizationsKxd();
    case 'lt':
      return AppLocalizationsLt();
    case 'mk':
      return AppLocalizationsMk();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'ms':
      return AppLocalizationsMs();
    case 'nb':
      return AppLocalizationsNb();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'ru':
      return AppLocalizationsRu();
    case 'si':
      return AppLocalizationsSi();
    case 'sk':
      return AppLocalizationsSk();
    case 'sr':
      return AppLocalizationsSr();
    case 'sv':
      return AppLocalizationsSv();
    case 'sw':
      return AppLocalizationsSw();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
    case 'th':
      return AppLocalizationsTh();
    case 'tl':
      return AppLocalizationsTl();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'ur':
      return AppLocalizationsUr();
    case 'uz':
      return AppLocalizationsUz();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
