import subprocess
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from datetime import datetime
import os

yaml = YAML()
yaml.default_flow_style = False

# -----------------------------
# MANUAL INPUTS (LOCAL TEST)
# -----------------------------
env = input("Enter ENVIRONMENT (prod/uat): ").strip().lower()

if env not in ["prod", "uat"]:
    raise Exception("Invalid Environment")

service_type = input("Enter SERVICE_TYPE (ces/twx/ces,twx): ")
service_type = [x.strip().lower() for x in service_type.split(",") if x.strip()]

version_type = input("Enter VERSION_TYPE (standard/platinum/standard,platinum): ")
version_type = [x.strip().lower() for x in version_type.split(",") if x.strip()]

# -----------------------------
# REPO PATH (CHANGE THIS)
# -----------------------------
repo = "C:\Users\Accentiqa_30\Desktop\UAT_Patch_testing"

# -----------------------------
# BUILD PATCH LIST
# -----------------------------
patches = []

for service in service_type:

    if service not in ["ces", "twx"]:
        raise Exception(f"Invalid service: {service}")

    for vtype in version_type:

        if vtype not in ["standard", "platinum"]:
            raise Exception(f"Invalid type: {vtype}")

        param_name = f"{service.upper()}_{vtype.upper()}_VERSION"
        new_version = input(f"Enter version for {param_name}: ").strip()

        if not new_version:
            raise Exception(f"Missing version for {param_name}")

        file_name = f"{env}-{service}-{vtype}-version.yaml"

        patches.append({
            "file": file_name,
            "version": new_version
        })

# -----------------------------
# UPDATE YAML FILES
# -----------------------------
for patch in patches:

    file_path = os.path.join(repo, patch["file"])

    print(f"\nUpdating: {file_path}")
    print(f"New version: {patch['version']}")

    with open(file_path, "r") as file:
        data = yaml.load(file)

    data["image"]["tag"] = DoubleQuotedScalarString(patch["version"])

    with open(file_path, "w") as file:
        yaml.dump(data, file)

    print("Updated successfully")

print("\n✅ All updates completed")