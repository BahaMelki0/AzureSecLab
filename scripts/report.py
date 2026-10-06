"""Render probe evidence without treating fixtures as deployed results."""
import argparse
from html import escape
import json
from pathlib import Path


def evaluate(evidence):
    phase = evidence.get("phase")
    if phase not in ("vulnerable", "hardened"):
        raise ValueError("Unknown evidence phase")
    if evidence.get("provenance") not in ("synthetic-fixture", "live-vm-probe"):
        raise ValueError("Explicit evidence provenance is required")
    events = evidence.get("events")
    if not isinstance(events, list) or len(events) != 2:
        raise ValueError("Exactly two probe events are required")
    by_secret = {}
    for event in events:
        if not isinstance(event, dict) or event.get("secret") not in ("lab-canary", "lab-payroll"):
            raise ValueError("Unknown probe target")
        if event["secret"] in by_secret or type(event.get("status")) is not int:
            raise ValueError("Duplicate target or invalid HTTP status")
        by_secret[event["secret"]] = event["status"]
    return by_secret == {"lab-canary": 200, "lab-payroll": 200 if phase == "vulnerable" else 403}


def render(evidence):
    passed = evaluate(evidence)
    rows = "".join(f'<tr><td>{escape(e["secret"])}</td><td>{e["status"]}</td></tr>' for e in evidence["events"])
    return '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AzureSecLab — identity access evidence</title><style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#090a0d;color:#f0f1f3;font:16px/1.6 system-ui,sans-serif}main{max-width:960px;margin:8vh auto;padding:24px}header{border-bottom:2px solid #f04452;padding-bottom:24px}h1{font-size:40px;margin:0;color:#f04452}section{background:#111318;border:1px solid #2b3039;padding:24px;margin-top:24px;border-radius:12px}p{color:#9a9faa}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:12px;border-bottom:1px solid #2b3039}.tag{font:13px monospace;color:#e9bd62}.result{color:#65d39b}a{color:#8abcf0}@media(max-width:600px){main{margin:20px auto}h1{font-size:30px}}
</style><main><header><div class="tag">OBSIDIAN SIGNAL / CLOUD &amp; IDENTITY</div><h1>AzureSecLab</h1><p>Managed identity permissions: attack, observe, harden.</p></header>''' + f'''
<section><h2>{escape(evidence["phase"].title())} probe</h2><div class="tag">Evidence source: {escape(evidence["provenance"])}</div>
<p>{"Synthetic example only — no Azure deployment or live detection is demonstrated." if evidence["provenance"] == "synthetic-fixture" else "VM access probe evidence. Verify corresponding cloud audit logs separately."}</p>
<strong class="result">Expected access pattern: {"PASS" if passed else "FAIL"}</strong><table><thead><tr><th>Target secret</th><th>HTTP status</th></tr></thead><tbody>{rows}</tbody></table></section>
<section><h2>Interpretation</h2><p>Hardened access should retain canary reads and deny unrelated payroll reads. A 403 may also reflect a network restriction or RBAC propagation; inspect Key Vault diagnostics before attributing it to remediation. A successful probe is not proof that a Sentinel analytic has fired.</p></section></main></html>'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    evidence = json.loads(args.input.read_text(encoding="utf-8"))
    html = render(evidence)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(html, encoding="utf-8")
    print(f"Report written: {args.output}")
    raise SystemExit(0 if evaluate(evidence) else 1)


if __name__ == "__main__":
    main()
