"""Create only public, synthetic canary values; never store secrets in Terraform."""
from scripts.common import outputs, azure


def main():
    lab = outputs()
    for name in ("lab-canary", "lab-payroll"):
        azure("keyvault", "secret", "set", "--vault-name", lab["vault_name"],
              "--name", name, "--value", "SYNTHETIC-AZURESECLAB-NOT-A-REAL-SECRET",
              "--output", "none")
        print(f"Created synthetic secret: {name}")


if __name__ == "__main__":
    main()
