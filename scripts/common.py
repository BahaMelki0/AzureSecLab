from pathlib import Path
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def terraform():
    local = ROOT / ".tools" / "terraform.exe"
    tool = shutil.which("terraform") or (str(local) if local.exists() else None)
    if not tool:
        raise RuntimeError("Install Terraform 1.16.x and add it to PATH")
    return tool


def outputs():
    process = subprocess.run(
        [terraform(), "-chdir=" + str(ROOT / "infra"), "output", "-json"],
        check=True, capture_output=True, text=True,
    )
    return {key: item["value"] for key, item in json.loads(process.stdout).items()}


def azure(*arguments):
    tool = shutil.which("az")
    if not tool:
        raise RuntimeError("Install Azure CLI and sign in with az login")
    return subprocess.run([tool, *arguments], check=True, capture_output=True, text=True)
