// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get home_title => 'Inicio';

  @override
  String get home_greeting_morning => 'Buenos días, Chef';

  @override
  String get home_greeting_afternoon => 'Buenas tardes, Chef';

  @override
  String get home_greeting_evening => 'Buenas noches, Chef';

  @override
  String get home_quick_actions => 'Acciones Rápidas';

  @override
  String get home_recent_recipes => 'Recetas Recientes';

  @override
  String get home_view_all => 'Ver todas';

  @override
  String get home_active_timers => 'Temporizadores Activos';

  @override
  String get home_kitchen_tools => 'Herramientas de Cocina';

  @override
  String get home_stats_recipes => 'Recetas';

  @override
  String get home_stats_ingredients => 'Ingredientes';

  @override
  String get home_stats_avg_margin => 'Margen Promedio';

  @override
  String get recipes_title => 'Recetas';

  @override
  String get new_recipe_title => 'Nueva Receta';

  @override
  String get recipe_title => 'Receta';

  @override
  String get ingredients_title => 'Ingredientes';

  @override
  String get units_title => 'Unidades';

  @override
  String get recipe_name => 'Nombre de la Receta';

  @override
  String get recipe_description => 'Descripción';

  @override
  String get recipe_description_hint => 'Breve descripción de la receta...';

  @override
  String get recipe_yield => 'Rendimiento';

  @override
  String get recipe_yield_name => 'Unidad (ej. galletas)';

  @override
  String get target_profit_margin => 'Margen de Ganancia (%)';

  @override
  String get target_price_portion => 'Precio por Porción';

  @override
  String get fixed_overhead => 'Gastos Fijos';

  @override
  String get total_cost => 'Costo Total';

  @override
  String get profit_per_recipe => 'Ganancia por Receta';

  @override
  String get ingredient_name => 'Nombre del Ingrediente';

  @override
  String get ingredient_cost => 'Costo';

  @override
  String get ingredient_quantity => 'Cantidad';

  @override
  String get unit_grams => 'Gramos';

  @override
  String get unit_kilograms => 'Kilogramos';

  @override
  String get unit_milliliters => 'Mililitros';

  @override
  String get unit_liters => 'Litros';

  @override
  String get unit_pieces => 'Piezas';

  @override
  String get unit_spoonfuls => 'Cucharadas';

  @override
  String get unit_tablespoons => 'Cucharadas';

  @override
  String get unit_teaspoons => 'Cucharaditas';

  @override
  String get unit_cups => 'Tazas';

  @override
  String get unit_ounces => 'Onzas';

  @override
  String get step_instruction => 'Instrucción';

  @override
  String get step_instruction_hint => 'Describe el paso...';

  @override
  String get save_button => 'Guardar';

  @override
  String get add_button => 'Agregar';

  @override
  String get edit_button => 'Editar';

  @override
  String get delete_button => 'Eliminar';

  @override
  String get duplicate_button => 'Duplicar';

  @override
  String get delete_recipe_title => 'Eliminar Receta';

  @override
  String get delete_recipe_message =>
      '¿Estás seguro de que deseas eliminar esta receta? Esta acción no se puede deshacer.';

  @override
  String get discard_button => 'Descartar';

  @override
  String get cancel_button => 'Cancelar';

  @override
  String get unsaved_changes_title => 'Cambios sin guardar';

  @override
  String get unsaved_changes_body =>
      '¿Quieres guardar o descartar esta receta?';

  @override
  String get new_ingredient_button => 'Nuevo Ingrediente';

  @override
  String get config_button => 'Configuración';

  @override
  String get recipe_steps => 'Pasos';

  @override
  String get tools_title => 'Herramientas';

  @override
  String get no_steps => 'Aún no hay pasos añadidos.';

  @override
  String get est_revenue => 'Ingresos Est.';

  @override
  String get financial_targets => 'Objetivos Financieros';

  @override
  String get financial_margin => 'Margen Total';

  @override
  String get financial_price => 'Precio por Porción';

  @override
  String get no_ingredients => 'Aún no hay ingredientes.';

  @override
  String get unit_portions => 'Porciones';

  @override
  String get cost_per_portion => 'Costo por Porción';

  @override
  String get profit_per_portion => 'Ganancia por Porción';

  @override
  String get total_profit => 'Ganancia Total';

  @override
  String get total_sale => 'Venta Total';

  @override
  String get sale_per_portion => 'Venta por Porción';

  @override
  String get validation_required => 'Requerido';

  @override
  String get profit_margin_helper =>
      'Ingrese números enteros (ej. 35 para 35%)';

  @override
  String get assign_ingredients_tooltip => 'Asignar ingredientes a este paso';

  @override
  String get select_ingredient_recipe_title => 'Seleccionar Ingrediente';

  @override
  String assign_to_step_title(int number) {
    return 'Asignar al Paso $number';
  }

  @override
  String get mention_ingredient_title => 'Mencionar Ingrediente';

  @override
  String get add_ingredients_first_error =>
      'Agrega ingredientes a la receta primero';

  @override
  String get assign_step_ingredients_first_error =>
      'Asigna ingredientes al paso en la cabecera (+)';

  @override
  String get done_button => 'Hecho';

  @override
  String get add_ingredient_title => 'Agregar Ingrediente';

  @override
  String get edit_ingredient_title => 'Editar Ingrediente';

  @override
  String get select_unit => 'Seleccionar Unidad';

  @override
  String ingredient_price_per_quantity(
    String price,
    String quantity,
    String unit,
  ) {
    return '$price por cada $quantity $unit';
  }

  @override
  String get search_hint => 'Buscar...';

  @override
  String get search_ingredients_hint => 'Buscar ingredientes...';

  @override
  String get no_ingredients_found => 'Ingredientes no encontrados';

  @override
  String get no_recipes_found => 'No se encontraron recetas.';

  @override
  String get related_ingredients => 'Relacionados';

  @override
  String get no_similar_ingredients => 'No hay ingredientes similares';

  @override
  String get merge_button => 'Combinar';

  @override
  String get compare_button => 'Comparar';

  @override
  String get merge_confirm_title => '¿Combinar Ingredientes?';

  @override
  String merge_confirm_message(String oldName, String newName) {
    return 'Esto reemplazará todas las referencias a $oldName con $newName in tus recetas. Esta acción no se puede deshacer.';
  }

  @override
  String get price_comparison => 'Comparación de Precios';

  @override
  String get error_select_unit => 'Por favor selecciona una unidad';

  @override
  String error_prefix(String error) {
    return 'Error: $error';
  }

  @override
  String get short_cost => 'COSTO';

  @override
  String get short_profit => 'GANANCIA';

  @override
  String get short_price_portion => 'P/PORCIÓN';

  @override
  String get per_unit => 'por';

  @override
  String get error_text => 'Error';

  @override
  String get scale_recipe_tooltip => 'Escalar receta (vista temporal)';

  @override
  String get temporary_view_title => 'Vista Temporal';

  @override
  String temporary_view_banner(String multiplier) {
    return 'Esta es una vista temporal escalada por ${multiplier}x. Los cambios no se guardarán.';
  }

  @override
  String get scale_button => 'Escalar';

  @override
  String get rule_of_three_title => 'Regla de Tres';

  @override
  String get rule_of_three_desc =>
      'Calcula proporciones fácilmente para cantidades de ingredientes y rendimientos.';

  @override
  String get rule_of_three_if => 'Si';

  @override
  String get rule_of_three_corresponds => 'corresponde a';

  @override
  String get rule_of_three_then => 'Entonces';

  @override
  String get rule_of_three_will_be => 'será';

  @override
  String get rule_of_three_result => 'Resultado';

  @override
  String get rule_of_three_clear => 'Limpiar';

  @override
  String get rule_of_three_example =>
      'Ejemplo: Si 100g de harina rinden 10 porciones, entonces para rendir 25 porciones necesitas 250g de harina.';

  @override
  String get unit_converter_title => 'Conversor de Unidades';

  @override
  String get unit_converter_desc =>
      'Convierte unidades de cocina para masa, volumen y cantidades fácilmente.';

  @override
  String get unit_converter_category => 'Categoría';

  @override
  String get unit_converter_from => 'Desde';

  @override
  String get unit_converter_to => 'Hacia';

  @override
  String get unit_converter_value => 'Valor';

  @override
  String get unit_converter_result => 'Resultado';

  @override
  String get unit_category_mass => 'Peso / Masa';

  @override
  String get unit_category_volume => 'Volumen';

  @override
  String get unit_category_count => 'Cantidad / Unidades';

  @override
  String get settings_general => 'Configuración General';

  @override
  String get settings_reset_db => 'Restablecer Base de Datos';

  @override
  String get settings_reset_db_desc =>
      'Elimina todas las recetas e ingredientes. No se puede deshacer.';

  @override
  String get settings_reset_db_confirm => '¿Restablecer Base de Datos?';

  @override
  String get settings_reset_db_warning =>
      '¿Estás seguro de que quieres eliminar todas las recetas, ingredientes y pasos? Esta acción es permanente.';

  @override
  String get settings_reset_db_success =>
      'Base de datos restablecida correctamente.';

  @override
  String get settings_theme_title => 'Tema y Estilo';

  @override
  String get settings_theme_mode => 'Modo de Tema';

  @override
  String get settings_theme_color => 'Color de Acento';

  @override
  String get settings_theme_system => 'Sistema';

  @override
  String get settings_theme_light => 'Claro';

  @override
  String get settings_theme_dark => 'Oscuro';

  @override
  String get settings_locale_title => 'Localización y Formato';

  @override
  String get settings_locale_lang => 'Idioma';

  @override
  String get settings_locale_es => 'Español';

  @override
  String get settings_locale_en => 'Inglés';

  @override
  String get settings_format_decimals => 'Decimales';

  @override
  String get settings_about => 'Acerca de';

  @override
  String get settings_version => 'Versión';

  @override
  String get settings_font_size => 'Tamaño de Fuente';

  @override
  String get settings_font_size_small => 'Pequeño';

  @override
  String get settings_font_size_medium => 'Mediano';

  @override
  String get settings_font_size_large => 'Grande';

  @override
  String get settings_font_size_xlarge => 'Muy Grande';

  @override
  String get settings_styles_title => 'Estilos';

  @override
  String get settings_about_app_title => 'Acerca de la Aplicación';

  @override
  String get settings_haptic_feedback => 'Respuesta Háptica';

  @override
  String get settings_haptic_feedback_desc =>
      'Activa vibraciones del sistema al interactuar con botones';

  @override
  String get settings_styles_m3 => 'Usar Material 3';

  @override
  String get settings_styles_m3_desc =>
      'Activa el diseño y componentes modernos de Material 3';

  @override
  String get settings_styles_icon_style => 'Estilo de Iconos';

  @override
  String get settings_styles_icon_style_outlined => 'Contorno';

  @override
  String get settings_styles_icon_style_rounded => 'Redondeado';

  @override
  String get settings_styles_icon_style_sharp => 'Afilado';

  @override
  String get settings_styles_number_colors => 'Colorear Números';

  @override
  String get settings_styles_number_colors_desc =>
      'Usa colores semánticos para métricas financieras';

  @override
  String get settings_styles_animations => 'Animaciones';

  @override
  String get settings_styles_animations_desc =>
      'Activa transiciones de pantalla y microanimaciones';

  @override
  String get settings_styles_scroll => 'Física de Desplazamiento';

  @override
  String get settings_styles_scroll_default => 'Por Defecto';

  @override
  String get settings_styles_scroll_simple => 'Simple (Limitado)';

  @override
  String get settings_styles_scroll_stretch => 'Estirar';

  @override
  String get settings_styles_scroll_bounce => 'Rebotar';

  @override
  String get settings_styles_left_hand => 'Modo Zurdo';

  @override
  String get settings_styles_left_hand_desc =>
      'Refleja controles para un uso más fácil con la mano izquierda';

  @override
  String get settings_styles_high_contrast => 'Texto de Alto Contraste';

  @override
  String get settings_styles_high_contrast_desc =>
      'Fuerza texto negro/blanco puro para legibilidad';

  @override
  String get settings_styles_font => 'Familia de Fuente';

  @override
  String get settings_styles_font_system => 'Predeterminada';

  @override
  String get settings_styles_font_sans => 'Metropolis';

  @override
  String get settings_styles_font_serif => 'Nunito';

  @override
  String get settings_styles_font_mono => 'Inconsolata Monospace';

  @override
  String get settings_styles_font_amatic => 'Amatic SC';

  @override
  String get settings_styles_font_butler => 'Butler';

  @override
  String get settings_styles_font_caveat => 'Caveat';

  @override
  String get settings_styles_show_nav_labels =>
      'Mostrar Etiquetas de Navegación';

  @override
  String get settings_styles_show_nav_labels_desc =>
      'Muestra las etiquetas de texto debajo de los iconos de navegación';

  @override
  String get settings_format_mass_unit => 'Unidad de Masa Predeterminada';

  @override
  String get settings_format_volume_unit => 'Unidad de Volumen Predeterminada';

  @override
  String get settings_format_decimals_1 => '1 decimal';

  @override
  String get settings_format_decimals_2 => '2 decimales';

  @override
  String get settings_format_decimals_3 => '3 decimales';

  @override
  String get settings_format_decimals_4 => '4 decimales';

  @override
  String get settings_format_mass_g => 'Gramos (g)';

  @override
  String get settings_format_mass_kg => 'Kilogramos (kg)';

  @override
  String get settings_format_volume_ml => 'Mililitros (ml)';

  @override
  String get settings_format_volume_l => 'Litros (l)';

  @override
  String get settings_format_currency => 'Símbolo de Moneda';

  @override
  String get cloud_sync_title => 'Sincronización en la Nube';

  @override
  String get cloud_sync_desc =>
      'Realiza copias de seguridad y restaura tus recetas e ingredientes de forma segura usando tu cuenta de Google Drive.';

  @override
  String get cloud_sync_connected => 'Conectado a Google Drive';

  @override
  String get cloud_sync_disconnected => 'Desconectado';

  @override
  String get cloud_sync_connect_btn => 'Iniciar sesión con Google';

  @override
  String get cloud_sync_disconnect_btn => 'Cerrar sesión';

  @override
  String get cloud_sync_backup_btn => 'Respaldar ahora';

  @override
  String get cloud_sync_backups_header => 'Historial de Copias';

  @override
  String get cloud_sync_no_backups => 'No hay copias de seguridad.';

  @override
  String get cloud_sync_backup_confirm_title => 'Crear Copia de Seguridad';

  @override
  String get cloud_sync_backup_confirm_desc =>
      'Se subirá una copia de seguridad de tu base de datos actual a Google Drive.';

  @override
  String get cloud_sync_restore_confirm_title => 'Restaurar Copia de Seguridad';

  @override
  String get cloud_sync_restore_confirm_desc =>
      'Se sobrescribirán todas las recetas, pasos e ingredientes con la copia de seguridad seleccionada. Esta acción no se puede deshacer.';

  @override
  String get cloud_sync_delete_confirm_title => 'Eliminar Copia de Seguridad';

  @override
  String get cloud_sync_delete_confirm_desc =>
      '¿Estás seguro de que deseas eliminar permanentemente esta copia de seguridad de Google Drive?';

  @override
  String get cloud_sync_sandbox_badge => 'Copia Local';

  @override
  String get cloud_sync_sandbox_desc =>
      'Las copias se guardan en un directorio local del dispositivo.';

  @override
  String get cloud_sync_sync_btn => 'Sincronización Bidireccional';

  @override
  String get cloud_sync_sync_confirm_title => 'Sincronización Bidireccional';

  @override
  String get cloud_sync_sync_confirm_desc =>
      'Esto combinará tus recetas e ingredientes locales con la copia en la nube. Los conflictos se resuelven dando prioridad a la última edición según su fecha de modificación. No se borrarán registros locales ni ediciones más recientes.';

  @override
  String get cloud_sync_sync_with_backup_confirm_desc =>
      'Esto combinará tus recetas e ingredientes locales con esta copia de seguridad. Los conflictos se resuelven dando prioridad a la última edición según su fecha de modificación. No se borrarán registros locales ni ediciones más recientes.';

  @override
  String get cloud_sync_merge_tooltip => 'Combinar con base de datos local';

  @override
  String get timers_title => 'Temporizadores de Cocina';

  @override
  String get timers_desc =>
      'Ejecuta múltiples temporizadores de cocina y horneado simultáneamente en segundo plano.';

  @override
  String get timers_add_title => 'Nuevo Temporizador';

  @override
  String get timers_timer_name => 'Nombre del Temporizador';

  @override
  String get timers_duration => 'Duración';

  @override
  String get timers_no_timers => 'Sin temporizadores activos.';

  @override
  String get timers_no_timers_desc =>
      '¡Crea un nuevo temporizador para comenzar a cocinar!';

  @override
  String get timers_finished => '¡Temporizador Finalizado!';

  @override
  String get filter_all => 'Todos';

  @override
  String get filter_solids => 'Secos';

  @override
  String get filter_liquids => 'Líquidos';

  @override
  String get filter_pieces => 'Piezas';

  @override
  String get filter_tooltip => 'Filtrar ingredientes';

  @override
  String get sort_by => 'Ordenar:';

  @override
  String get sort_default => 'Por defecto';

  @override
  String get sort_type => 'Tipo (Sólidos / Líquidos / Piezas)';

  @override
  String get sort_alphabetical => 'Alfabético';

  @override
  String get sort_solids => 'Sólidos';

  @override
  String get sort_liquids => 'Líquidos';

  @override
  String get sort_pieces => 'Piezas';

  @override
  String get staged_ingredients_title => '¿Guardar ingredientes seleccionados?';

  @override
  String get staged_ingredients_body =>
      'Tienes ingredientes seleccionados. ¿Deseas agregarlos a la receta o descartar los cambios?';

  @override
  String add_custom_ingredient(String name) {
    return 'Agregar \'$name\'';
  }

  @override
  String get total_weight => 'Peso Total';

  @override
  String get total_volume => 'Volumen Total';

  @override
  String get scale_by_ingredient => 'Escalar por Ingrediente';

  @override
  String get scale_by_ingredient_desc =>
      'Ajustar cantidades de la receta según la cantidad objetivo de un ingrediente';

  @override
  String get target_quantity => 'Cantidad Objetivo';

  @override
  String get current_quantity => 'Cantidad Actual';

  @override
  String scale_factor_label(String factor) {
    return 'Factor de Escala: ${factor}x';
  }

  @override
  String get scale_preview_button => 'Vista Previa';

  @override
  String get select_ingredient => 'Seleccionar Ingrediente';

  @override
  String scale_temporary_title(String multiplier) {
    return 'Vista Escalada Temporal (${multiplier}x)';
  }

  @override
  String get scale_temporary_notice =>
      'Este escalado es temporal y no modifica la receta real en la base de datos.';

  @override
  String get scale_revert_button => 'Restablecer Original';

  @override
  String get scale_save_as_real_button => 'Guardar como Receta Real';

  @override
  String get scale_reverted_toast =>
      'Receta restablecida a las cantidades originales';

  @override
  String get scale_saved_toast =>
      'Cantidades escaladas guardadas en la receta real';

  @override
  String get brand_home_tooltip => 'Chef&Cost - Inicio';

  @override
  String get back_to_home_tooltip => 'Volver al Inicio';

  @override
  String get back_button => 'Volver';

  @override
  String get close_button => 'Cerrar';

  @override
  String get apply_button => 'Aplicar';

  @override
  String get save_changes_button => 'Guardar Cambios';

  @override
  String get view_button => 'Ver';

  @override
  String get sign_in_button => 'Iniciar Sesión';

  @override
  String get toggle_theme_tooltip => 'Cambiar tema';

  @override
  String get search_recipes_hint => 'Buscar recetas...';

  @override
  String sample_data_loaded_snackbar(int recipes, int ingredients) {
    return 'Datos de ejemplo cargados: $recipes recetas y $ingredients ingredientes';
  }

  @override
  String get load_sample_data => 'Cargar datos de ejemplo';

  @override
  String get timer_finished_banner => '¡Temporizador finalizado!';

  @override
  String timer_finished_at(String time) {
    return 'Terminado a las $time';
  }

  @override
  String get delete_ingredient_title => '¿Eliminar ingrediente?';

  @override
  String delete_ingredient_confirm(String name) {
    return '¿Estás seguro de que deseas eliminar \"$name\" de la base de datos?';
  }

  @override
  String get unsaved_changes_ingredient_body =>
      '¿Deseas guardar los cambios del ingrediente o descartarlos?';

  @override
  String get recipe_editor_add_ingredients_to_scale =>
      'Agregue ingredientes a la receta para escalar';

  @override
  String get recipe_editor_please_enter_name =>
      'Por favor, ingrese el nombre de la receta';

  @override
  String get recipe_duplicated_success => 'Receta duplicada con éxito';

  @override
  String get apply_to_recipe_button => 'Aplicar a la Receta';

  @override
  String recipe_duplicate_name(String name, String copyLabel) {
    return '$name ($copyLabel)';
  }

  @override
  String get financial_summary_title => 'Resumen Financiero';

  @override
  String get financial_costs_section => 'Costos';

  @override
  String get financial_margin_pricing_section => 'Margen y Precios';

  @override
  String get financial_results_section => 'Resultados';

  @override
  String get financial_total_revenue => 'Ingreso bruto total';

  @override
  String get recipe_stats_section => 'Datos de Receta';

  @override
  String get hide_financial_summary => 'Ocultar Resumen Financiero';

  @override
  String get show_financial_summary => 'Mostrar Resumen Financiero';

  @override
  String get recipe_editor_live => 'En vivo';

  @override
  String get recipe_editor_other_category => 'Otros';

  @override
  String get recipe_timers_section => 'Temporizadores de la Receta';

  @override
  String get recipe_timer_single => 'Temporizador';

  @override
  String get recipe_timers_title => 'Temporizadores';

  @override
  String get recipe_timer_add_badge => '+ Temporizador';

  @override
  String get start_timer_tooltip => 'Iniciar temporizador';

  @override
  String timer_started_snackbar(String name, String duration) {
    return 'Temporizador iniciado: $name ($duration)';
  }

  @override
  String get recipe_timer_edit_title => 'Editar Temporizador';

  @override
  String get recipe_timer_add_title => 'Agregar Temporizador';

  @override
  String get recipe_timer_name_label => 'Nombre del temporizador';

  @override
  String get recipe_timer_name_hint => 'ej. Hervir Pasta, Hornear';

  @override
  String get add_timer_preset_button => 'Guardar Temporizador';

  @override
  String get edit_ingredient_action => 'Editar ingrediente';

  @override
  String get edit_ingredient_action_desc =>
      'Modificar nombre, costo, cantidad o unidad en la base de datos';

  @override
  String get merge_ingredient_action => 'Combinar / Fusionar ingrediente';

  @override
  String get merge_ingredient_action_desc =>
      'Sumar cantidad a otro ingrediente de esta receta';

  @override
  String get delete_ingredient_action => 'Eliminar ingrediente';

  @override
  String get delete_ingredient_action_desc =>
      'Quitar ingrediente de esta receta';

  @override
  String get merge_ingredient_title => 'Combinar Ingrediente';

  @override
  String merge_ingredient_into_prompt(String name) {
    return 'Combinar \"$name\" en:';
  }

  @override
  String get compare_merged_success => 'Ingredientes combinados con éxito';

  @override
  String get compare_no_units_error => 'ERROR: No hay unidades cargadas.';

  @override
  String compare_more_costly(String amount) {
    return '+$amount MÁS COSTOSO';
  }

  @override
  String compare_less_costly(String amount) {
    return '-$amount MÁS ECONÓMICO';
  }

  @override
  String get compare_loading => 'Cargando datos de comparación...';

  @override
  String get timers_running => 'En marcha';

  @override
  String get timers_paused => 'Pausado';

  @override
  String get timers_stop_alarm => 'DETENER ALARMA';

  @override
  String get timers_reset => 'Reiniciar';

  @override
  String get timers_pause => 'Pausar';

  @override
  String get timers_start => 'Iniciar';

  @override
  String get timers_start_timer => 'Iniciar Temporizador';

  @override
  String get timers_edit_title => 'Editar Temporizador';

  @override
  String get timers_hint => 'ej. Hervir Papas';

  @override
  String get timers_min => 'Min';

  @override
  String get timers_sec => 'Seg';

  @override
  String timers_add_minutes(int minutes) {
    return '+${minutes}m';
  }

  @override
  String get rule_of_three_error_zero => 'El valor inicial no puede ser cero';

  @override
  String rule_of_three_explanation(
    String a,
    String b,
    String c,
    String result,
  ) {
    return 'Si $a equivale a $b, entonces $c equivale a $result.';
  }

  @override
  String get cloud_sync_sync_target => 'Destino de Sincronización';

  @override
  String get cloud_sync_target_firestore => 'Firestore';

  @override
  String get cloud_sync_target_drive => 'Google Drive';

  @override
  String get cloud_sync_target_local => 'Directorio Local';

  @override
  String get cloud_sync_desc_web =>
      'En la Web, la sincronización se realiza mediante Cloud Firestore para sincronizar datos en tiempo real entre tu navegador y la aplicación móvil. Los respaldos en archivo de Google Drive están disponibles en dispositivos móviles y de escritorio.';

  @override
  String get cloud_sync_desc_firestore =>
      'Sincronización multiplataforma (Web y Móvil) en tiempo real mediante Cloud Firestore.';

  @override
  String get cloud_sync_desc_local =>
      'El modo Directorio Local guarda tus respaldos en el almacenamiento local del dispositivo. No requiere conexión a Internet ni una cuenta de Google.';

  @override
  String get cloud_sync_switch_account => 'Cambiar cuenta';

  @override
  String get cloud_sync_sync_now => 'Sincronizar ahora';

  @override
  String get cloud_sync_save_copy_dialog_title =>
      'Seleccionar carpeta para guardar la copia';

  @override
  String get cloud_sync_save_copy_tooltip => 'Guardar copia en...';

  @override
  String get cloud_sync_restore_tooltip => 'Restaurar';

  @override
  String get cloud_sync_delete_tooltip => 'Eliminar';

  @override
  String get cloud_sync_connect_account_title => 'Conecta tu cuenta';

  @override
  String get cloud_sync_connect_account_subtitle =>
      'Sincroniza tus recetas automáticamente entre Web y Móvil';

  @override
  String get cloud_sync_continue_google => 'Continuar con Google';

  @override
  String get cloud_sync_or_email => 'o con correo electrónico';

  @override
  String get cloud_sync_create_account => 'Crear Cuenta';

  @override
  String get cloud_sync_email_label => 'Correo electrónico';

  @override
  String get cloud_sync_email_hint => 'ejemplo@correo.com';

  @override
  String get cloud_sync_password_label => 'Contraseña';

  @override
  String get cloud_sync_password_hint => 'Mínimo 6 caracteres';

  @override
  String get cloud_sync_forgot_password => '¿Olvidaste tu contraseña?';

  @override
  String get cloud_sync_connected_to_firestore => 'Conectado a Firestore';

  @override
  String get cloud_sync_authenticated_user => 'Usuario autenticado';

  @override
  String get cloud_sync_sign_out_confirm_title => 'Cerrar sesión';

  @override
  String get cloud_sync_sign_out_confirm_message =>
      '¿Estás seguro de que deseas cerrar sesión de Firestore?';

  @override
  String get cloud_sync_error_invalid_email =>
      'Por favor, introduce un correo electrónico válido.';

  @override
  String get cloud_sync_error_short_password =>
      'La contraseña debe tener al menos 6 caracteres.';

  @override
  String get cloud_sync_reset_email_sent =>
      '¡Enlace enviado! Revisa tu correo electrónico para restablecer tu contraseña.';

  @override
  String get cloud_sync_connected_account => 'Cuenta conectada';

  @override
  String get settings_category_data_subtitle => 'Gestión de datos de la app';

  @override
  String get settings_category_backup_subtitle =>
      'Respaldar y restaurar en Google Drive';

  @override
  String get settings_category_themes_subtitle =>
      'Temas, colores y tamaño de letra';

  @override
  String get settings_category_locale_subtitle => 'Idioma y formato numérico';

  @override
  String get settings_category_info_subtitle => 'Versión e información';

  @override
  String get settings_sample_data_dialog_message =>
      '¿Deseas añadir las recetas de ejemplo a las existentes o reemplazar todo el contenido actual de la base de datos?';

  @override
  String get settings_sample_data_add_button => 'Añadir a los actuales';

  @override
  String get settings_sample_data_replace_button => 'Reemplazar todo';

  @override
  String settings_sample_data_replaced_snackbar(int recipes, int ingredients) {
    return 'Base de datos reemplazada con datos de ejemplo ($recipes recetas, $ingredients ingredientes)';
  }

  @override
  String get settings_sample_data_subtitle =>
      'Carga ingredientes y recetas de prueba para evaluar la app';

  @override
  String get settings_brand_theme_adapt_notice =>
      'El icono y la marca se adaptan al tema seleccionado';

  @override
  String scale_multiplier_button(String multiplier) {
    return 'x$multiplier';
  }

  @override
  String get scale_custom_multiplier_hint => 'ej. 1.5';

  @override
  String scaled_recipe_name(String name, String multiplier) {
    return '$name (x$multiplier)';
  }

  @override
  String get merge_no_other_ingredients =>
      'No hay otros ingredientes en esta receta para combinar.';

  @override
  String get merge_no_other_database_ingredients =>
      'No hay otros ingredientes en la base de datos para combinar.';

  @override
  String get merge_ingredient_action_db_desc =>
      'Fusionar con otro ingrediente en la base de datos';

  @override
  String get delete_ingredient_permanent_desc =>
      'Eliminar permanentemente de la base de datos';

  @override
  String ingredient_deleted_snackbar(String name) {
    return 'Ingrediente \"$name\" eliminado.';
  }

  @override
  String get no_timers_in_recipe =>
      'No hay temporizadores agregados a esta receta.';

  @override
  String get recipe_timer_min => 'Min';

  @override
  String get recipe_timer_sec => 'Seg';

  @override
  String get gain_per_portion => 'Ganancia/Porción';

  @override
  String get price_per_portion => 'Precio/Porción';

  @override
  String get force_overwrite_danger_zone => 'Zona de Peligro';

  @override
  String get force_overwrite_cloud_btn => 'Forzar Sobrescritura en la Nube';

  @override
  String get force_overwrite_first_confirm_title =>
      'Forzar Sobrescritura en la Nube';

  @override
  String get force_overwrite_first_confirm_desc =>
      'Esto SOBRESCRIBIRÁ permanentemente todos los datos en la nube con su copia local. Esta acción es irreversible.';

  @override
  String get force_overwrite_understand_risk => 'Sí, entiendo el riesgo';

  @override
  String get force_overwrite_challenge_title =>
      'Escribe OVERWRITE para Confirmar';

  @override
  String get force_overwrite_challenge_desc =>
      'Para evitar pérdidas accidentales, escribe OVERWRITE a continuación para continuar.';

  @override
  String get force_overwrite_challenge_placeholder => 'OVERWRITE';

  @override
  String get force_overwrite_confirm_final_btn => 'Confirmar Sobrescritura';

  @override
  String get force_overwrite_success_toast =>
      'Los datos en la nube se han sobrescrito con éxito con la copia local.';

  @override
  String get force_overwrite_failure_toast =>
      'Error al sobrescribir los datos en la nube.';
}
