import os
import re
import csv

folder = r"C:\your_route\your_folder"
output = os.path.join(
    r"C:\your_route\your_folder",
    "output_CARGAS.csv"
)

def extraer_numero_ciclo(nombre):
    numeros = re.findall(r'\d+', nombre)
    return int(numeros[0]) if numeros else 0

def parsear_cir(path):
    params = {"L0": None, "R0": None, "R1": None, "C1": None, "R2": None, "C2": None}
    with open(path, "r", encoding="utf8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            for key in params:
                if line.startswith(key + " "):
                    tokens = line.split()
                    try:
                        params[key] = abs(float(tokens[-1]))
                    except ValueError:
                        pass
    return params

files = [f for f in os.listdir(folder) if f.lower().endswith(".cir")]
files.sort(key=extraer_numero_ciclo)

rows = []
ciclos_vistos = set()
for file in files:
    path = os.path.join(folder, file)
    ciclo = extraer_numero_ciclo(file)
    if ciclo in ciclos_vistos:
        continue
    ciclos_vistos.add(ciclo)
    params = parsear_cir(path)
    rows.append([
        ciclo,
        file,
        params["L0"],
        params["R0"],
        params["R1"],
        params["C1"],
        params["R2"],
        params["C2"],
    ])

os.makedirs(os.path.dirname(output), exist_ok=True)

with open(output, "w", newline="", encoding="utf-8-sig") as f:
    writer = csv.writer(f, delimiter=";")
    writer.writerow(["Ciclo", "Archivo", "L0_H", "R0_Ohm", "R1_Ohm", "C1_F", "R2_Ohm", "C2_F"])
    writer.writerows(rows)

print(f"Archivo generado: {output}")
print(f"Total de ciclos procesados: {len(rows)}")
