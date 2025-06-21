import json
import os
from collections import OrderedDict
from bs4 import BeautifulSoup

DRIVERS_FILE = "drivers.json"

# Variables globales
drivers = {}
raw_data = {}
profil_colonnes = OrderedDict()

def save_drivers_to_file():
    with open(DRIVERS_FILE, "w", encoding="utf-8") as f:
        json.dump(drivers, f, indent=2, ensure_ascii=False)
    print("✅ Fichier drivers.json mis à jour.")

def remap_drivers():
    global drivers
    new_drivers = {}
    mapping_keys_ordered = list(profil_colonnes.keys())

    for driver_id in set(list(raw_data.keys()) + list(drivers.keys())):
        sorted_driver = OrderedDict()
        combined_data = {}

        if driver_id in raw_data:
            for col, (code, value) in raw_data[driver_id].items():
                label = profil_colonnes.get(col)
                if label:
                    combined_data[label] = value

        if driver_id in drivers:
            for label, value in drivers[driver_id].items():
                combined_data[label] = value

        for col in mapping_keys_ordered:
            label = profil_colonnes[col]
            if label in combined_data:
                sorted_driver[label] = combined_data[label]

        new_drivers[driver_id] = sorted_driver

    drivers.update(new_drivers)
    save_drivers_to_file()

def parse_message(ws, message):
    print("📨 Message WebSocket reçu.")
    lines = message.strip().split("\n")
    for line in lines:
        parts = line.split("|")
        if len(parts) == 3:
            ident, code, value = parts
            if not ident.startswith("r") or "c" not in ident:
                continue

            pilot_raw, col = ident.split("c")
            driver_id = pilot_raw[1:]

            if driver_id not in raw_data:
                raw_data[driver_id] = {}

            raw_data[driver_id][f"C{col}"] = (code, value)
            print(f"🧪 Donnée WebSocket : {driver_id} -> {col} = {value})")

    remap_drivers()

def update_drivers(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    rows = soup.find_all('tr')

    for row in rows:
        driver_id = row.get("data-id")
        if not driver_id or driver_id == "r0":
            continue
        driver_id = driver_id.lstrip("r")

        kart = row.find('td', {'class': 'no'})
        driver_name = row.find('td', {'class': 'dr'})

        kart_text = kart.text.strip() if kart else None
        driver_name_text = driver_name.text.strip() if driver_name else None

        if driver_id not in drivers:
            drivers[driver_id] = {}

        if kart_text:
            drivers[driver_id]['Kart'] = kart_text
        if driver_name_text:
            drivers[driver_id]['Equipe/Pilote'] = driver_name_text

    save_drivers_to_file()
    print("📁 drivers.json mis à jour avec Kart et Driver.")
