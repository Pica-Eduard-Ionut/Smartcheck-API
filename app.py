import os
import re
from fastapi import FastAPI

app = FastAPI()
OUTPUT_DIR = "logs"

@app.get("/logs")
def get_logs(limit: int = 30):
    logs = []

    for filename in sorted(os.listdir(OUTPUT_DIR)):
        if not filename.endswith(".txt"):
            continue

        year = filename[0:4]
        month = filename[5:7]
        day = filename[8:10]
        attributes = {}
        filepath = os.path.join(OUTPUT_DIR, filename)

        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()

                if not line or not re.match(r"^\d+\s+", line):
                    continue

                parts = re.split(r"\s+", line, maxsplit=9)

                if len(parts) != 10:
                    continue

                attributes[parts[1]] = {
                    "id": int(parts[0]),
                    "flag": parts[2],
                    "value": int(parts[3]),
                    "worst": int(parts[4]),
                    "thresh": parts[5],
                    "type": parts[6],
                    "updated": parts[7],
                    "when_failed": parts[8],
                    "raw_value": parts[9],
                }

        logs.append({
            "year": int(year),
            "month": int(month),
            "day": int(day),
            "temperature": int(attributes["Temperature_Celsius"]["raw_value"].split()[0]),
            "power_on_hours": int(attributes["Power_On_Hours"]["raw_value"]),
            "wear_percent": int(attributes["Media_Wearout_Indicator"]["value"]),
            "power_cycles": int(attributes["Power_Cycle_Count"]["raw_value"]),
        })

        logs.sort(key=lambda x: (x["year"], x["month"], x["day"]), reverse=True)

    return logs[:limit]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
