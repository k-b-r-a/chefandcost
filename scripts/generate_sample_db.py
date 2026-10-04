#!/usr/bin/env python3
"""
Generates a sample SQLite database file (sample_recipetools.sqlite)
prepopulated with realistic culinary ingredients and recipes for testing RecipeTools.
"""

import sqlite3
import uuid
import time
import os

OUTPUT_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sample_recipetools.sqlite")

def create_sample_database(output_path=OUTPUT_PATH):
    if os.path.exists(output_path):
        os.remove(output_path)

    conn = sqlite3.connect(output_path)
    cur = conn.cursor()

    # 1. Create tables
    cur.execute("""
    CREATE TABLE IF NOT EXISTS units (
        unit_pk TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        symbol TEXT NOT NULL,
        category TEXT,
        factor_to_base REAL NOT NULL DEFAULT 1.0,
        is_mutable INTEGER NOT NULL DEFAULT 0
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS ingredients (
        ingredient_pk TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        cost REAL NOT NULL,
        quantity_for_cost REAL NOT NULL,
        unit_fk TEXT NOT NULL REFERENCES units(unit_pk),
        date_created INTEGER NOT NULL,
        date_time_modified INTEGER
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS recipes (
        recipe_pk TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        default_yield REAL NOT NULL,
        yield_name TEXT NOT NULL,
        target_profit_margin REAL NOT NULL DEFAULT 0.0,
        target_price_per_portion REAL NOT NULL DEFAULT 0.0,
        fixed_overhead_cost REAL NOT NULL DEFAULT 0.0,
        colour TEXT,
        date_created INTEGER NOT NULL,
        date_time_modified INTEGER,
        archived INTEGER NOT NULL DEFAULT 0
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS recipe_ingredients (
        recipe_ingredient_pk TEXT NOT NULL PRIMARY KEY,
        recipe_fk TEXT NOT NULL REFERENCES recipes(recipe_pk),
        ingredient_fk TEXT NOT NULL REFERENCES ingredients(ingredient_pk),
        amount_needed REAL NOT NULL,
        date_time_modified INTEGER
    );
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS recipe_steps (
        step_pk TEXT NOT NULL PRIMARY KEY,
        recipe_fk TEXT NOT NULL REFERENCES recipes(recipe_pk),
        step_number INTEGER NOT NULL,
        instruction TEXT NOT NULL,
        date_time_modified INTEGER
    );
    """)

    # 2. Insert Standard Units
    units = [
        ("unit_g", "unit_grams", "g", "mass", 1.0, 0),
        ("unit_kg", "unit_kilograms", "kg", "mass", 1000.0, 0),
        ("unit_oz", "unit_ounces", "oz", "mass", 28.3495, 0),
        ("unit_ml", "unit_milliliters", "ml", "volume", 1.0, 0),
        ("unit_l", "unit_liters", "l", "volume", 1000.0, 0),
        ("unit_cup", "unit_cups", "cup", "volume", 240.0, 0),
        ("unit_tbsp", "unit_tablespoons", "tbsp", "volume", 15.0, 0),
        ("unit_tsp", "unit_teaspoons", "tsp", "volume", 5.0, 0),
        ("unit_cuch", "unit_spoonfuls", "cuch", "volume", 15.0, 0),
        ("unit_pcs", "unit_pieces", "pcs", "count", 1.0, 0),
    ]

    cur.executemany("""
    INSERT INTO units (unit_pk, name, symbol, category, factor_to_base, is_mutable)
    VALUES (?, ?, ?, ?, ?, ?);
    """, units)

    now = int(time.time())

    # 3. Insert Sample Ingredients
    ingredients = [
        ("ing_harina", "Harina de Trigo 0000", 1.20, 1000.0, "unit_g", now, now),
        ("ing_azucar", "Azúcar Blanca Refinada", 1.50, 1000.0, "unit_g", now, now),
        ("ing_huevos", "Huevos Frescos", 3.00, 12.0, "unit_pcs", now, now),
        ("ing_mantequilla", "Mantequilla sin Sal", 2.80, 250.0, "unit_g", now, now),
        ("ing_leche", "Leche Entera", 1.10, 1000.0, "unit_ml", now, now),
        ("ing_cacao", "Cacao Amargo en Polvo", 3.50, 250.0, "unit_g", now, now),
        ("ing_chocolate", "Chocolate de Cobertura 70%", 5.80, 500.0, "unit_g", now, now),
        ("ing_polvo_hornear", "Polvo de Hornear", 0.95, 100.0, "unit_g", now, now),
        ("ing_vainilla", "Esencia de Vainilla", 2.10, 100.0, "unit_ml", now, now),
        ("ing_sal", "Sal Fina", 0.60, 1000.0, "unit_g", now, now),
        ("ing_crema", "Crema de Leche (Nata)", 2.40, 500.0, "unit_ml", now, now),
        ("ing_levadura", "Levadura Seca Activa", 1.25, 50.0, "unit_g", now, now),
        ("ing_aceite", "Aceite de Girasol", 2.00, 1000.0, "unit_ml", now, now),
        ("ing_chispas", "Chispas de Chocolate Semiamargo", 4.20, 350.0, "unit_g", now, now),
    ]

    cur.executemany("""
    INSERT INTO ingredients (ingredient_pk, name, cost, quantity_for_cost, unit_fk, date_created, date_time_modified)
    VALUES (?, ?, ?, ?, ?, ?, ?);
    """, ingredients)

    # 4. Insert Sample Recipes
    recipes = [
        (
            "rec_torta_choco",
            "Torta Húmeda de Chocolate",
            "Deliciosa torta de chocolate esponjosa con ganache, ideal para cumpleaños y eventos.",
            8.0,
            "porciones",
            45.0,
            4.50,
            0.0,
            "amber",
            now,
            now,
            0
        ),
        (
            "rec_galletas_choco",
            "Galletas con Chispas de Chocolate",
            "Galletas americanas clásicas, crujientes en los bordes y suaves en el centro.",
            24.0,
            "galletas",
            50.0,
            1.20,
            0.0,
            "deepOrange",
            now,
            now,
            0
        ),
        (
            "rec_pan_campo",
            "Pan Casero de Campo",
            "Pan rústico tradicional de corteza crujiente y miga tierna, con fermentación lenta.",
            2.0,
            "hogazas",
            60.0,
            3.50,
            0.0,
            "brown",
            now,
            now,
            0
        ),
        (
            "rec_crema_pastelera",
            "Crema Pastelera de Vainilla",
            "Crema clásica de repostería francesa para rellenar facturas, tartas y medialunas.",
            4.0,
            "porciones",
            45.0,
            2.20,
            0.0,
            "yellow",
            now,
            now,
            0
        ),
    ]

    cur.executemany("""
    INSERT INTO recipes (
        recipe_pk, name, description, default_yield, yield_name,
        target_profit_margin, target_price_per_portion, fixed_overhead_cost,
        colour, date_created, date_time_modified, archived
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """, recipes)

    # 5. Insert Recipe Ingredients
    recipe_ingredients = [
        # Torta Húmeda de Chocolate
        (str(uuid.uuid4()), "rec_torta_choco", "ing_harina", 250.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_azucar", 200.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_huevos", 3.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_cacao", 60.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_leche", 150.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_mantequilla", 100.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_polvo_hornear", 10.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_vainilla", 10.0, now),
        (str(uuid.uuid4()), "rec_torta_choco", "ing_chocolate", 150.0, now),

        # Galletas con Chispas
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_harina", 280.0, now),
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_azucar", 150.0, now),
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_mantequilla", 170.0, now),
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_huevos", 2.0, now),
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_chispas", 200.0, now),
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_vainilla", 5.0, now),
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_polvo_hornear", 5.0, now),
        (str(uuid.uuid4()), "rec_galletas_choco", "ing_sal", 3.0, now),

        # Pan Casero
        (str(uuid.uuid4()), "rec_pan_campo", "ing_harina", 500.0, now),
        (str(uuid.uuid4()), "rec_pan_campo", "ing_levadura", 7.0, now),
        (str(uuid.uuid4()), "rec_pan_campo", "ing_sal", 10.0, now),
        (str(uuid.uuid4()), "rec_pan_campo", "ing_aceite", 20.0, now),

        # Crema Pastelera
        (str(uuid.uuid4()), "rec_crema_pastelera", "ing_leche", 500.0, now),
        (str(uuid.uuid4()), "rec_crema_pastelera", "ing_huevos", 4.0, now),
        (str(uuid.uuid4()), "rec_crema_pastelera", "ing_azucar", 120.0, now),
        (str(uuid.uuid4()), "rec_crema_pastelera", "ing_harina", 45.0, now),
        (str(uuid.uuid4()), "rec_crema_pastelera", "ing_vainilla", 10.0, now),
    ]

    cur.executemany("""
    INSERT INTO recipe_ingredients (
        recipe_ingredient_pk, recipe_fk, ingredient_fk, amount_needed, date_time_modified
    ) VALUES (?, ?, ?, ?, ?);
    """, recipe_ingredients)

    # 6. Insert Recipe Steps (with timer tags)
    recipe_steps = [
        # Torta Húmeda
        (str(uuid.uuid4()), "rec_torta_choco", 1, "Precalentar el horno a 180°C y engrasar un molde redondo de 22 cm.", now),
        (str(uuid.uuid4()), "rec_torta_choco", 2, "Tamizar la harina de trigo junto con el cacao amargo y el polvo de hornear.", now),
        (str(uuid.uuid4()), "rec_torta_choco", 3, "Batir los huevos con el azúcar hasta que la mezcla blanquee y esté espumosa. Añadir la mantequilla derretida y la esencia de vainilla.", now),
        (str(uuid.uuid4()), "rec_torta_choco", 4, "Integrar los ingredientes secos alternando con la leche tibia con movimientos envolventes.", now),
        (str(uuid.uuid4()), "rec_torta_choco", 5, "Verter en el molde y hornear durante 35 minutos hasta que un palillo salga seco. [timer:Horneado a 180°C|2100]", now),

        # Galletas con Chispas
        (str(uuid.uuid4()), "rec_galletas_choco", 1, "Batir la mantequilla pomada con el azúcar hasta lograr una textura cremosa.", now),
        (str(uuid.uuid4()), "rec_galletas_choco", 2, "Añadir los huevos uno a uno junto con la vainilla, batiendo bien tras cada adición.", now),
        (str(uuid.uuid4()), "rec_galletas_choco", 3, "Tamizar e incorporar la harina, polvo de hornear y sal. Agregar las chispas de chocolate de forma uniforme.", now),
        (str(uuid.uuid4()), "rec_galletas_choco", 4, "Formar bolitas de masa de 35 g y colocarlas en una bandeja con papel manteca. Llevar al refrigerador por 15 minutos. [timer:Reposo en Frío|900]", now),
        (str(uuid.uuid4()), "rec_galletas_choco", 5, "Hornear a 190°C durante 12 minutos hasta que los bordes adquieran un tono dorado. [timer:Horneado de Galletas|720]", now),

        # Pan Casero
        (str(uuid.uuid4()), "rec_pan_campo", 1, "Disolver la levadura en 320 ml de agua tibia y dejar activar durante 10 minutos. [timer:Activación de Levadura|600]", now),
        (str(uuid.uuid4()), "rec_pan_campo", 2, "Colocar la harina en forma de corona con la sal por fuera y los líquidos en el centro.", now),
        (str(uuid.uuid4()), "rec_pan_campo", 3, "Amasar enérgicamente de 10 a 12 minutos hasta lograr un bollo elástico y suave.", now),
        (str(uuid.uuid4()), "rec_pan_campo", 4, "Colocar en un recipiente aceitado, tapar con paño húmedo y dejar leudar por 60 minutos. [timer:Primer Leudado|3600]", now),
        (str(uuid.uuid4()), "rec_pan_campo", 5, "Dividir en 2 porciones, dar forma a las hogazas y dejar reposar 30 minutos más. [timer:Segundo Leudado|1800]", now),
        (str(uuid.uuid4()), "rec_pan_campo", 6, "Realizar cortes en la superficie y hornear a 220°C con vapor durante 35 minutos. [timer:Horneado con Vapor|2100]", now),

        # Crema Pastelera
        (str(uuid.uuid4()), "rec_crema_pastelera", 1, "Calentar la leche con la mitad del azúcar y la esencia de vainilla hasta casi hervir.", now),
        (str(uuid.uuid4()), "rec_crema_pastelera", 2, "Batir las yemas de huevo con el resto del azúcar y la harina hasta disolver todo grumo.", now),
        (str(uuid.uuid4()), "rec_crema_pastelera", 3, "Templar vertiendo un tercio de la leche caliente sobre las yemas sin dejar de remover.", now),
        (str(uuid.uuid4()), "rec_crema_pastelera", 4, "Volver todo al fuego medio y cocinar batiendo constantemente hasta que espese y rompa hervor. [timer:Cocción a Fuego Medio|300]", now),
        (str(uuid.uuid4()), "rec_crema_pastelera", 5, "Retirar del fuego, tapar con film al contacto y dejar enfriar en la heladera durante 30 minutos. [timer:Enfriado en Heladera|1800]", now),
    ]

    cur.executemany("""
    INSERT INTO recipe_steps (
        step_pk, recipe_fk, step_number, instruction, date_time_modified
    ) VALUES (?, ?, ?, ?, ?);
    """, recipe_steps)

    conn.commit()
    conn.close()
    print(f"Sample database created successfully at: {output_path}")

if __name__ == "__main__":
    create_sample_database()
