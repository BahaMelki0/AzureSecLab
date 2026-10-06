"""Execute a read-only managed identity probe inside the lab VM."""
import argparse
import json
import re
import tempfile
from pathlib import Path
from scripts.common import ROOT, outputs, azure


def build_probe(vault, client_id):
    if not re.fullmatch(r"[a-zA-Z0-9-]{3,24}", vault):
        raise ValueError("Unexpected vault name")
    if not re.fullmatch(r"[0-9a-fA-F-]{36}", client_id):
        raise ValueError("Unexpected identity client ID")
    # Python's urllib avoids dependencies and keeps tokens/secret bodies out of output.
    return "python3 - <<'PY'\n" + f'''import json, urllib.request, urllib.error
request=urllib.request.Request("http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net&client_id={client_id}", headers={{"Metadata":"true"}})
with urllib.request.urlopen(request, timeout=15) as response:
    token=json.load(response)["access_token"]
events=[]
for secret in ["lab-canary", "lab-payroll"]:
    request=urllib.request.Request("https://{vault}.vault.azure.net/secrets/"+secret+"?api-version=7.4", headers={{"Authorization":"Bearer "+token}})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status=response.status
    except urllib.error.HTTPError as error:
        status=error.code
    events.append({{"secret":secret,"status":status}})
print("AZURESECLAB_PROBE="+json.dumps(events))
''' + "PY"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["vulnerable", "hardened"], required=True)
    args = parser.parse_args()
    lab = outputs()
    if lab["security_mode"] != args.phase:
        raise SystemExit("Probe phase must match deployed Terraform security_mode")
    # Pass a file instead of multiline shell text through Windows az.cmd quoting.
    with tempfile.TemporaryDirectory(prefix="azureseclab-") as directory:
        script = Path(directory) / "probe.sh"
        script.write_text(build_probe(lab["vault_name"], lab["identity_client_id"]), encoding="utf-8", newline="\n")
        response = json.loads(azure("vm", "run-command", "invoke", "--resource-group", lab["resource_group"],
                                   "--name", lab["vm_name"], "--command-id", "RunShellScript",
                                   "--scripts", "@" + str(script), "--output", "json").stdout)
    messages = "\n".join(item.get("message", "") for item in response.get("value", []))
    match = re.search(r"AZURESECLAB_PROBE=(\[[^\n]+\])", messages)
    if not match:
        raise SystemExit("VM probe produced no structured result; check VM agent/network health")
    events = json.loads(match.group(1))
    expected = {"lab-canary": 200, "lab-payroll": 200 if args.phase == "vulnerable" else 403}
    passed = len(events) == 2 and {e["secret"]: e["status"] for e in events} == expected
    evidence = {"provenance": "live-vm-probe", "phase": args.phase, "events": events, "passed": passed}
    destination = ROOT / "evidence" / "live"
    destination.mkdir(parents=True, exist_ok=True)
    (destination / f"{args.phase}.json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    print(json.dumps(evidence, indent=2))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
