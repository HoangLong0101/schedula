import json
import re
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
    demo_owners = [row[0] for row in rows if row[2] == "owner" and str(row[4]).endswith("@schedula.demo")]
    if demo_owners:
        raise ValueError(f"Tenant owners still use demo emails: {demo_owners}")
    dotted_owners = [
        row[0] for row in rows
        if row[2] == "owner" and "." in str(row[4]).split("@", 1)[0]
    ]
    if dotted_owners:
        raise ValueError(f"Tenant owner emails still contain dots: {dotted_owners}")
    invalid_tenant_ids = sorted({
        row[1] for row in rows if not re.fullmatch(r"[A-Za-z0-9]{20}", str(row[1]))
    })
    if invalid_tenant_ids:
        raise ValueError(f"Invalid tenant IDs: {invalid_tenant_ids}")
    print(json.dumps({
        "accounts": len(rows),
        "owners": sum(row[2] == "owner" for row in rows),
        "staff": sum(row[2] == "staff" for row in rows),
        "temporaryPasswords": sum(bool(row[5]) for row in rows),
        "demoOwnerEmails": len(demo_owners),
        "dottedOwnerEmails": len(dotted_owners),
        "invalidTenantIds": len(invalid_tenant_ids),
    }))


def read_credentials(path):
    workbook = load_workbook(path, read_only=True, data_only=True)
    rows = workbook["Credentials"].iter_rows(min_row=5, values_only=True)
    passwords = {}
    for row in rows:
        if not row[5]:
            continue
        if row[4]:
            passwords[f"email:{row[4]}"] = str(row[5])
        if row[1] and row[2] and row[3]:
            passwords[f"identity:{row[1]}|{row[2]}|{row[3]}"] = str(row[5])
    print(json.dumps({"passwords": passwords}, ensure_ascii=False))


def compare_credentials(old_path, new_path):
    def by_identity(path):
        workbook = load_workbook(path, read_only=True, data_only=True)
        rows = workbook["Credentials"].iter_rows(min_row=5, values_only=True)
        return {(row[0], row[2], row[3]): row[5] for row in rows}

    old = by_identity(old_path)
    new = by_identity(new_path)
    if old != new:
        raise ValueError("Temporary passwords changed during credential migration")
    print(json.dumps({"preservedPasswords": len(new)}))


def update_tenant_identities(source_path, output_path):
    sys.stdin.reconfigure(encoding="utf-8")
    identity_by_tenant = json.load(sys.stdin)
    workbook = load_workbook(source_path)
    sheet = workbook["Credentials"]
    updated_tenants = set()
    updated_owners = set()
    for row in sheet.iter_rows(min_row=5):
        tenant = clean(row[0].value)
        role = clean(row[2].value)
        if tenant not in identity_by_tenant:
            continue
        identity = identity_by_tenant[tenant]
        row[1].value = identity["tenantId"]
        updated_tenants.add(tenant)
        if role == "owner":
            row[4].value = identity["email"]
            row[6].value = "identity updated"
            updated_owners.add(tenant)
    missing = sorted(set(identity_by_tenant) - updated_tenants)
    if missing:
        raise ValueError(f"Tenant rows not found: {missing}")
    missing_owners = sorted(set(identity_by_tenant) - updated_owners)
    if missing_owners:
        raise ValueError(f"Owner rows not found: {missing_owners}")
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    workbook.save(output_path)
    print(json.dumps({
        "updatedTenants": len(updated_tenants),
        "updatedOwners": len(updated_owners),
        "output": output_path,
    }, ensure_ascii=False))


def clean(value):
    if value is None:
        return ""
    return str(value).strip()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(
            "Usage: simulationWorkbook.py extract|credentials|verify-credentials|read-credentials|update-tenant-identities PATH [PATH]"
        )
    if sys.argv[1] == "extract":
        extract(sys.argv[2])
    elif sys.argv[1] == "credentials":
        write_credentials(sys.argv[2])
    elif sys.argv[1] == "verify-credentials":
        verify_credentials(sys.argv[2])
    elif sys.argv[1] == "read-credentials":
        read_credentials(sys.argv[2])
    elif sys.argv[1] == "compare-credentials":
        compare_credentials(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "update-tenant-identities":
        update_tenant_identities(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit("Unknown mode")
