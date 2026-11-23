"""Lambda procesadora de alertas operativas recibidas vía Amazon SNS."""

from __future__ import annotations

import http.client
import json
import os
from typing import Any
from urllib.parse import urlsplit

RUNBOOK_HINTS: tuple[tuple[str, str], ...] = (
    ("cpu", "Revisar consultas lentas o loops en RDS/EKS (docs/RUNBOOKS.md#rds-cpu)."),
    ("storage", "Liberar tablas temporales o ampliar volumen RDS gp3 (docs/RUNBOOKS.md#rds-storage)."),
    ("connections", "Verificar pool de conexiones en catalog/orders/cart/admin (docs/RUNBOOKS.md#rds-connections)."),
    ("5xx", "Inspeccionar logs JSON de pods y estado del Target Group ALB (docs/RUNBOOKS.md#alb-5xx)."),
    ("auth", "Revisar eventos auth_login_failed en CloudWatch Logs (docs/RUNBOOKS.md#auth-bruteforce)."),
)
DEFAULT_RUNBOOK_HINT = "Consultar CloudWatch Dashboard y estado de pods en EKS (docs/RUNBOOKS.md)."


def _resolve_runbook_hint(alarm_name: str) -> str:
    """Devuelve una recomendación operativa acorde al nombre de la alarma."""
    lowered = alarm_name.lower()
    for keyword, hint in RUNBOOK_HINTS:
        if keyword in lowered:
            return hint
    return DEFAULT_RUNBOOK_HINT


def _parse_alarm_message(raw_message: str) -> dict[str, Any]:
    """Parsea el JSON de CloudWatch Alarm cuando está presente dentro del mensaje SNS."""
    try:
        parsed = json.loads(raw_message)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass
    return {"AlarmName": "custom-sns-event", "NewStateValue": "INFO", "NewStateReason": raw_message}


def _send_webhook(webhook_url: str, payload: dict[str, Any]) -> None:
    """Envía la alerta enriquecida únicamente hacia webhooks HTTPS válidos."""
    parsed = urlsplit(webhook_url)
    if parsed.scheme != "https" or not parsed.netloc:
        return

    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"

    body = json.dumps({"content": json.dumps(payload, ensure_ascii=False)}).encode("utf-8")
    conn = http.client.HTTPSConnection(parsed.netloc, timeout=5)
    try:
        conn.request("POST", path, body=body, headers={"Content-Type": "application/json"})
        conn.getresponse().read()
    except OSError as exc:
        print(json.dumps({"level": "error", "event": "webhook_delivery_failed", "error": str(exc)}))
    finally:
        conn.close()


def lambda_handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    """Enriquece cada evento SNS con el ambiente, runbook sugerido y log JSON estructurado."""
    environment = os.environ.get("ENVIRONMENT", "unknown")
    webhook_url = os.environ.get("WEBHOOK_URL", "")
    processed: list[dict[str, Any]] = []

    for record in event.get("Records", []):
        sns_data = record.get("Sns", {})
        alarm = _parse_alarm_message(sns_data.get("Message", ""))
        alarm_name = str(alarm.get("AlarmName", "unknown-alarm"))
        enriched = {
            "service": "alert-handler",
            "event": "cloudwatch_alarm_processed",
            "environment": environment,
            "alarm_name": alarm_name,
            "state": alarm.get("NewStateValue", "UNKNOWN"),
            "reason": alarm.get("NewStateReason", ""),
            "timestamp": sns_data.get("Timestamp", ""),
            "runbook_hint": _resolve_runbook_hint(alarm_name),
        }
        print(json.dumps(enriched, ensure_ascii=False))
        processed.append(enriched)

        if webhook_url:
            _send_webhook(webhook_url, enriched)

    return {"statusCode": 200, "processed": len(processed)}
