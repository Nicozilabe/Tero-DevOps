#!/usr/bin/env python3
"""Genera tablas Markdown limpias para $GITHUB_STEP_SUMMARY desde reportes JSON de CI."""

from __future__ import annotations

import glob
import json
import os
import sys
from collections import Counter
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def md_cell(value: Any, max_len: int = 120) -> str:
    text = str(value if value is not None else "").replace("|", "\\|").replace("\r", " ").replace("\n", " ").strip()
    if len(text) > max_len:
        return text[: max_len - 3] + "..."
    return text


def emit(lines: list[str]) -> None:
    content = "\n".join(lines) + "\n"
    print(content, end="")
    summary_path = os.getenv("GITHUB_STEP_SUMMARY", "").strip()
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write(content + "\n")


def load_json(path: str, default: Any) -> Any:
    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        return default
    raw = p.read_text(encoding="utf-8").strip()
    if not raw:
        return default
    data = json.loads(raw)
    return default if data is None else data


def handle_gitleaks(pattern: str) -> int:
    files = sorted(glob.glob(pattern))
    findings: list[dict[str, Any]] = []
    for fpath in files:
        data = load_json(fpath, [])
        if isinstance(data, list):
            findings.extend(data)

    lines = ["### 🔐 Detección de Secretos (Gitleaks)", ""]
    if not findings:
        lines.append("✅ **0 secretos detectados** (working tree + commits del PR).")
        emit(lines)
        return 0

    lines.extend([
        f"❌ **{len(findings)} secreto(s) detectado(s)**",
        "",
        "| Archivo | Línea | Regla | Descripción |",
        "|---|---:|---|---|",
    ])
    for item in findings[:40]:
        lines.append(
            f"| `{md_cell(item.get('File', ''))}` "
            f"| {item.get('StartLine', 0)} "
            f"| `{md_cell(item.get('RuleID', ''))}` "
            f"| {md_cell(item.get('Description', ''))} |"
        )
    if len(findings) > 40:
        lines.append(f"\n_Mostrando 40 de {len(findings)} hallazgos (ver artifact JSON)._")
    emit(lines)
    return 0


def handle_trivy(title: str, json_path: str) -> int:
    data = load_json(json_path, {})
    if not data:
        emit([f"### {title}", "", f"⚠️ No se encontró el reporte `{json_path}`."])
        return 0

    counts: Counter[str] = Counter()
    blocking: dict[tuple[str, str, str, str], tuple[int, str, str, str, str, str, str]] = {}

    for result in data.get("Results") or []:
        target = result.get("Target") or "-"
        for vuln in result.get("Vulnerabilities") or []:
            sev = (vuln.get("Severity") or "UNKNOWN").upper()
            counts[sev] += 1
            if sev in ("CRITICAL", "HIGH"):
                pkg = vuln.get("PkgName") or "-"
                installed = vuln.get("InstalledVersion") or "-"
                fixed = vuln.get("FixedVersion") or "*(sin parche)*"
                cve = vuln.get("VulnerabilityID") or "-"
                rank = 0 if sev == "CRITICAL" else 1
                key = (target, pkg, installed, cve)
                blocking[key] = (rank, target, pkg, installed, fixed, cve, sev)

    crit = counts.get("CRITICAL", 0)
    high = counts.get("HIGH", 0)
    med = counts.get("MEDIUM", 0)
    low = counts.get("LOW", 0)

    badge = (
        "✅ **0 vulnerabilidades CRITICAL / HIGH** (Quality Gate aprobado)."
        if (crit + high) == 0
        else f"❌ **{crit} CRITICAL · {high} HIGH bloqueantes**"
    )

    lines = [
        f"### {title}",
        "",
        badge,
        "",
        "| CRITICAL | HIGH | MEDIUM | LOW |",
        "|:---:|:---:|:---:|:---:|",
        f"| {crit} | {high} | {med} | {low} |",
    ]

    if blocking:
        sorted_rows = sorted(blocking.values(), key=lambda x: (x[0], x[1], x[2], x[5]))
        lines.extend([
            "",
            "| Target | Paquete | Instalada | Parche (Fixed) | CVE | Sev |",
            "|---|---|---|---|---|---|",
        ])
        for _, target, pkg, installed, fixed, cve, sev in sorted_rows[:40]:
            fixed_fmt = fixed if fixed.startswith("*(") else f"`{md_cell(fixed, 60)}`"
            lines.append(
                f"| `{md_cell(target, 45)}` "
                f"| `{md_cell(pkg, 40)}` "
                f"| `{md_cell(installed, 30)}` "
                f"| {fixed_fmt} "
                f"| `{md_cell(cve, 30)}` "
                f"| **{sev}** |"
            )
        if len(sorted_rows) > 40:
            lines.append(
                f"\n_Mostrando 40 de {len(sorted_rows)} vulnerabilidades CRITICAL/HIGH únicas (ver artifact JSON completo)._"
            )

    emit(lines)
    return 0


def handle_semgrep(json_path: str) -> int:
    data = load_json(json_path, {})
    results = data.get("results") or []
    counts = Counter((r.get("extra") or {}).get("severity", "INFO").upper() for r in results)

    err_count = counts.get("ERROR", 0)
    warn_count = counts.get("WARNING", 0)
    info_count = counts.get("INFO", 0)

    app_findings: list[dict[str, Any]] = []
    workflow_findings: list[dict[str, Any]] = []
    for r in results:
        path = r.get("path", "")
        if path.startswith(".github/workflows/"):
            workflow_findings.append(r)
        else:
            app_findings.append(r)

    badge = (
        "✅ **0 hallazgos ERROR** (Quality Gate aprobado)."
        if err_count == 0
        else f"❌ **{err_count} hallazgo(s) ERROR bloqueante(s)**"
    )

    lines = [
        "### 🛡️ SAST Multi-lenguaje (Semgrep)",
        "",
        badge,
        "",
        "| ERROR (bloqueante) | WARNING | INFO |",
        "|:---:|:---:|:---:|",
        f"| {err_count} | {warn_count} | {info_count} |",
    ]

    if app_findings:
        lines.extend([
            "",
            "#### Hallazgos en código de aplicación",
            "| Sev | Archivo:Línea | Regla | Mensaje |",
            "|---|---|---|---|",
        ])
        for r in app_findings[:30]:
            sev = (r.get("extra") or {}).get("severity", "INFO").upper()
            path = md_cell(r.get("path", ""), 60)
            line_num = (r.get("start") or {}).get("line", 0)
            rule = md_cell(str(r.get("check_id", "")).split(".")[-1], 45)
            msg = md_cell((r.get("extra") or {}).get("message", ""), 140)
            lines.append(f"| **{sev}** | `{path}:{line_num}` | `{rule}` | {msg} |")

    if workflow_findings:
        lines.extend([
            "",
            f"ℹ️ **GitHub Actions workflows:** {len(workflow_findings)} avisos informativos "
            "(tags mutables en `.github/workflows/`).",
        ])

    emit(lines)
    return 1 if err_count > 0 else 0


def main() -> int:
    if len(sys.argv) < 3:
        print("Uso: format_summary.py <gitleaks|trivy|semgrep> <args...>", file=sys.stderr)
        return 2

    cmd = sys.argv[1]
    if cmd == "gitleaks":
        return handle_gitleaks(sys.argv[2])
    if cmd == "trivy":
        if len(sys.argv) < 4:
            print("Uso: format_summary.py trivy <title> <json_path>", file=sys.stderr)
            return 2
        return handle_trivy(sys.argv[2], sys.argv[3])
    if cmd == "semgrep":
        return handle_semgrep(sys.argv[2])

    print(f"Subcomando desconocido: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
