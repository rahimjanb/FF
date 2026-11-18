#!/usr/bin/env python3
"""Builds the nutrition seed data of the AI Food Scanner from official USDA data.

    python3 -I backend/tools/nutrition-data/build_foods.py --work <scratch dir> [--table]

Reads curated.json (next to this script): which USDA foods to take (FDC id, key, names, aliases, category) and the
compositions of the Uzbek dishes. Downloads the USDA FoodData Central "SR Legacy" CSV release into --work (never
into the repository), takes the nutrient values per 100 g from it and writes:

    backend/src/FitnessFormulasi.Api/Features/Nutrition/Data/foods.json
    backend/src/FitnessFormulasi.Api/Features/Nutrition/Data/recipes.json

No nutrient value is typed by hand: every number in foods.json comes from the USDA CSV. Recipe batches are scaled
to 1000 g of the finished dish. --table prints the per-100 g values of every recipe as a Markdown table (README).
Python 3 standard library only.
"""
import argparse
import csv
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

DATASET = "USDA FoodData Central, SR Legacy (2018-04)"
DATASET_URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip"
DATASET_DIR = "FoodData_Central_sr_legacy_food_csv_2018-04"

# Nutrient ids of FoodData Central. Energy falls back to the Atwater energies, total sugars to the NLEA total.
NUTRIENTS = {
    "kcal": ["1008", "2047", "2048"],
    "protein": ["1003"],
    "fat": ["1004"],
    "carbs": ["1005"],
    "fiber": ["1079"],
    "sugar": ["2000", "1063"],
    "saturatedFat": ["1258"],
    "sodiumMg": ["1093"],
}
REQUIRED = ["kcal", "protein", "fat", "carbs"]

# Must match the C# enums in backend/src/FitnessFormulasi.Api/Domain/Nutrition.cs.
CATEGORIES = {
    "Breakfast", "Lunch", "Dinner", "Snacks", "Fruits", "Vegetables", "Meat", "Fish", "Dairy", "Bakery", "Desserts",
    "FastFood", "Drinks", "PackagedFood", "TraditionalFood", "Grains", "Legumes", "NutsSeeds", "FatsOils", "Sauces",
    "Eggs", "Other",
}
ROLES = {"Main", "Fat", "Sauce", "Garnish", "Drink"}
KEY_RE = re.compile(r"^[a-z][a-z0-9_]{1,47}$")

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "src", "FitnessFormulasi.Api", "Features", "Nutrition", "Data"))


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(1)


def number(value):
    """Rounded to 2 decimals; whole numbers without a fraction."""
    v = round(float(value), 2)
    return int(v) if v == int(v) else v


def download(work):
    os.makedirs(work, exist_ok=True)
    folder = os.path.join(work, DATASET_DIR)
    if os.path.isfile(os.path.join(folder, "food_nutrient.csv")):
        return folder
    archive = os.path.join(work, "sr_legacy.zip")
    if not os.path.isfile(archive):
        print("Downloading " + DATASET_URL)
        with urllib.request.urlopen(DATASET_URL, timeout=300) as response, open(archive, "wb") as out:
            out.write(response.read())
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            base = os.path.basename(name)
            if base in ("food.csv", "food_nutrient.csv", "nutrient.csv"):
                os.makedirs(folder, exist_ok=True)
                with z.open(name) as src, open(os.path.join(folder, base), "wb") as dst:
                    dst.write(src.read())
    return folder


def read_usda(folder, wanted_ids):
    descriptions = {}
    with open(os.path.join(folder, "food.csv"), newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["fdc_id"] in wanted_ids:
                descriptions[row["fdc_id"]] = row["description"]
    ids = {i for ids in NUTRIENTS.values() for i in ids}
    amounts = {}
    with open(os.path.join(folder, "food_nutrient.csv"), newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["fdc_id"] in wanted_ids and row["nutrient_id"] in ids and row["amount"] != "":
                amounts.setdefault(row["fdc_id"], {})[row["nutrient_id"]] = row["amount"]
    return descriptions, amounts


def build_foods(curated, descriptions, amounts):
    foods, notes, seen = [], [], set()
    for item in curated["foods"]:
        key, fdc = item["key"], str(item["fdcId"])
        if not KEY_RE.match(key):
            fail(f"bad key '{key}'")
        if key in seen:
            fail(f"duplicate key '{key}'")
        seen.add(key)
        if item["category"] not in CATEGORIES:
            fail(f"{key}: unknown category {item['category']}")
        aliases = item.get("aliases", [])
        if len(aliases) > 8 or any(a != a.lower() for a in aliases):
            fail(f"{key}: at most 8 lower-case aliases")
        if fdc not in descriptions:
            fail(f"{key}: FDC id {fdc} is not in {DATASET}")
        values = {}
        for name, candidates in NUTRIENTS.items():
            found = next((c for c in candidates if c in amounts.get(fdc, {})), None)
            values[name] = number(amounts[fdc][found]) if found else None
            if found and found != candidates[0]:
                notes.append(f"{key}: {name} from nutrient {found} (no {candidates[0]})")
        missing = [n for n in REQUIRED if values[n] is None]
        if missing:
            fail(f"{key}: USDA has no {', '.join(missing)}")
        foods.append({
            "key": key, "fdcId": int(fdc), "nameRu": item["nameRu"], "nameUz": item["nameUz"],
            "nameEn": descriptions[fdc], "aliases": aliases, "category": item["category"], "per100Ml": False,
            "per100g": values,
        })
    return foods, notes


def scale_batch(recipe):
    """Scales the batch to 1000 g of the finished dish: integer grams, the rounding remainder on the largest."""
    batch = recipe["batch"]
    total = sum(g for _, g, _ in batch)
    grams = [max(1, round(g * 1000 / total)) for _, g, _ in batch]
    largest = max(range(len(grams)), key=lambda i: grams[i])
    grams[largest] += 1000 - sum(grams)
    return [{"key": k, "grams": g, "role": r} for (k, _, r), g in zip(batch, grams)]


def build_recipes(curated, foods_by_key):
    recipes, seen = [], set()
    for item in curated["recipes"]:
        key = item["key"]
        if not KEY_RE.match(key) or key in seen:
            fail(f"bad or duplicate recipe key '{key}'")
        seen.add(key)
        for k, _, role in item["batch"]:
            if k not in foods_by_key:
                fail(f"{key}: ingredient '{k}' is not in foods.json")
            if role not in ROLES:
                fail(f"{key}: unknown role {role}")
        ingredients = scale_batch(item)
        total = sum(i["grams"] for i in ingredients)
        if item.get("yieldGrams") is None and abs(total - 1000) > 1:
            fail(f"{key}: grams add up to {total}, not 1000")
        recipes.append({
            "key": key, "dishKey": item["dishKey"], "nameRu": item["nameRu"], "nameUz": item["nameUz"],
            "nameEn": item["nameEn"], "aliases": item["aliases"], "category": "TraditionalFood",
            "portionGrams": item["portionGrams"], "yieldGrams": item.get("yieldGrams"),
            "description": item["description"], "ingredients": ingredients,
        })
    return recipes


def per100(recipe, foods_by_key):
    """Values per 100 g of the dish: sum of ingredient values for their grams, divided by the dish weight."""
    weight = recipe["yieldGrams"] or sum(i["grams"] for i in recipe["ingredients"])
    out = {}
    for name in NUTRIENTS:
        total, known = 0.0, True
        for i in recipe["ingredients"]:
            v = foods_by_key[i["key"]]["per100g"][name]
            if v is None:
                known = False
                continue
            total += v * i["grams"] / 100
        out[name] = (round(total * 100 / weight, 1), known)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--work", required=True, help="scratch folder for the USDA download (outside the repository)")
    parser.add_argument("--table", action="store_true", help="print the per-100 g table of the recipes")
    args = parser.parse_args()

    with open(os.path.join(HERE, "curated.json"), encoding="utf-8") as f:
        curated = json.load(f)
    folder = download(args.work)
    wanted = {str(i["fdcId"]) for i in curated["foods"]}
    descriptions, amounts = read_usda(folder, wanted)
    foods, notes = build_foods(curated, descriptions, amounts)
    foods_by_key = {f["key"]: f for f in foods}
    recipes = build_recipes(curated, foods_by_key)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "foods.json"), "w", encoding="utf-8") as f:
        json.dump({"source": DATASET, "sourceUrl": DATASET_URL, "foods": foods}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    with open(os.path.join(OUT_DIR, "recipes.json"), "w", encoding="utf-8") as f:
        json.dump({"note": "Typical recipe compositions (estimates), as-eaten state, grams per 1000 g of the finished dish.",
                   "recipes": recipes}, f, ensure_ascii=False, indent=1)
        f.write("\n")

    print(f"foods: {len(foods)}, recipes: {len(recipes)} -> {OUT_DIR}")
    for n in notes:
        print("note: " + n)
    if args.table:
        print()
        print("| Блюдо | ккал | белки, г | жиры, г | углеводы, г | порция, г | ккал в порции |")
        print("|---|---:|---:|---:|---:|---:|---:|")
        for r in recipes:
            v = per100(r, foods_by_key)
            kcal = v["kcal"][0]
            print(f"| {r['nameRu']} | {kcal:.0f} | {v['protein'][0]} | {v['fat'][0]} | {v['carbs'][0]} | "
                  f"{r['portionGrams']} | {kcal * r['portionGrams'] / 100:.0f} |")


if __name__ == "__main__":
    main()
