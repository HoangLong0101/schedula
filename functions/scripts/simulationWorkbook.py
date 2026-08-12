import json
import sys
from pathlib import Path

from openpyxl import Workbook, load_workbook
from openpyxl.styles import Alignment, Font, PatternFill


def extract(path):
    workbook = load_workbook(path, read_only=False, data_only=True)
    sheet = workbook.worksheets[0]
    businesses = []
    for row_number in range(2, sheet.max_row + 1):
        if sheet.row_dimensions[row_number].hidden:
            continue
        values = [sheet.cell(row_number, col).value for col in range(1, 16)]
        if not any(value is not None for value in values):
            continue
        businesses.append({
            "sourceRow": row_number,
            "sourceId": int(values[0]),
            "name": clean(values[1]),
            "type": clean(values[2]) or "Spa",
            "area": clean(values[3]),
            "staffBand": clean(values[4]) or clean(values[6]),
            "branches": int(values[5] or 1),
            "contactRole": clean(values[7]),
            "contact": clean(values[8]),
            "contactName": clean(values[9]) or "Chủ cơ sở",
            "source": clean(values[10]),
            "status": clean(values[11]),
            "startDate": clean(values[12]),
            "endDate": clean(values[13]),
            "note": clean(values[14]),
        })
    if not businesses:
        raise ValueError("Workbook has no visible tenant rows")
    print(json.dumps({"businesses": businesses}, ensure_ascii=False))


def write_credentials(path):
    records = json.load(sys.stdin)
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Credentials"
    sheet["A1"] = "SCHEDULA — SIMULATION ACCOUNT CREDENTIALS"
    sheet["A1"].font = Font(size=16, bold=True, color="FFFFFF")
    sheet["A1"].fill = PatternFill("solid", fgColor="148A9C")
    sheet.merge_cells("A1:H1")
    sheet["A2"] = (
        "Sensitive: distribute privately. New accounts must change their "
        "temporary password on first sign-in."
    )
    sheet["A2"].font = Font(italic=True, color="9C2C2C")
    sheet.merge_cells("A2:H2")
    headers = [
        "Tenant", "Tenant ID", "Role", "Name", "Email",
        "Temporary password", "Account status", "Source contact",
    ]
    sheet.append([])
    sheet.append(headers)
    for record in records:
        sheet.append([
            record.get("tenantName", ""),
            record.get("tenantId", ""),
            record.get("role", ""),
            record.get("name", ""),
            record.get("email", ""),
            record.get("temporaryPassword", ""),
            record.get("accountStatus", ""),
            record.get("sourceContact", ""),
        ])
    header_fill = PatternFill("solid", fgColor="D8F2F5")
    for cell in sheet[4]:
        cell.font = Font(bold=True, color="124E5A")
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center")
    widths = [30, 42, 12, 24, 38, 28, 18, 28]
    for index, width in enumerate(widths, 1):
        sheet.column_dimensions[chr(64 + index)].width = width
    sheet.freeze_panes = "A5"
    sheet.auto_filter.ref = f"A4:H{sheet.max_row}"
    sheet.sheet_view.showGridLines = False
    for row in sheet.iter_rows(min_row=5):
        for cell in row:
            cell.alignment = Alignment(vertical="top")
    output = Path(path)
    output.parent.mkdir(parents=True, exist_ok=True)
    workbook.save(output)
    check = load_workbook(output, read_only=True, data_only=True)
    if check["Credentials"].max_row != len(records) + 4:
        raise ValueError("Credential workbook verification failed")


def verify_credentials(path):
    workbook = load_workbook(path, read_only=True, data_only=True)
    sheet = workbook["Credentials"]
    rows = list(sheet.iter_rows(min_row=5, values_only=True))
    if not rows or not all(all(row[index] for index in range(6)) for row in rows):
        raise ValueError("Credential workbook has missing required values")
    roles = {row[2] for row in rows}
    if roles != {"owner", "staff"}:
        raise ValueError(f"Unexpected credential roles: {roles}")
    print(json.dumps({
        "accounts": len(rows),
        "owners": sum(row[2] == "owner" for row in rows),
        "staff": sum(row[2] == "staff" for row in rows),
        "temporaryPasswords": sum(bool(row[5]) for row in rows),
    }))


def clean(value):
    if value is None:
        return ""
    return str(value).strip()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(
            "Usage: simulationWorkbook.py extract|credentials|verify-credentials PATH"
        )
    if sys.argv[1] == "extract":
        extract(sys.argv[2])
    elif sys.argv[1] == "credentials":
        write_credentials(sys.argv[2])
    elif sys.argv[1] == "verify-credentials":
        verify_credentials(sys.argv[2])
    else:
        raise SystemExit("Unknown mode")
