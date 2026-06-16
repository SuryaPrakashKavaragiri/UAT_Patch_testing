import subprocess
import os
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from datetime import datetime

yaml = YAML()
yaml.default_flow_style = False

# -----------------------------
# ENVIRONMENT
# -----------------------------
env = os.getenv("ENVIRONMENT", "").strip().lower()

if env not in ["prod", "uat"]:
    raise Exception("Invalid Environment, Select Prod or UAT")

# -----------------------------
# PARAMETERS (comma-separated)
# -----------------------------
service_type = [
    x.strip().lower()
    for x in os.getenv("CES_TWX", "").split(",")
    if x.strip()
]

version_type = [
    x.strip().lower()
    for x in os.getenv("VERSION_TYPE", "").split(",")
    if x.strip()
]

if not service_type:
    raise Exception("SERVICE_TYPE not provided")

if not version_type:
    raise Exception("VERSION_TYPE not provided")

# -----------------------------
# REPO PATH
# -----------------------------
repo = r"C:\Users\Accentiqa_30\Desktop\UAT_Patch_testing"

# -----------------------------
# GIT PULL
# -----------------------------
gitpull = subprocess.run(
    ["git", "pull"],
    cwd=repo,
    capture_output=True,
    text=True
).stdout
print(gitpull)

# -----------------------------
# CREATE NEW BRANCH
# -----------------------------
today_date = datetime.now()
month_date = today_date.strftime("%b%d-%H:%M:%S")

newbranch = f"{month_date}-{env}-patching"

subprocess.run(
    ["git", "checkout", "-b", newbranch],
    cwd=repo
)

# -----------------------------
# BUILD PATCH LIST
# -----------------------------
patches = []

for service in service_type:

    if service not in ["ces", "twx"]:
        raise Exception(f"Invalid service: {service}")

    for vtype in version_type:

        if vtype not in ["standard", "platinum"]:
            raise Exception(f"Invalid version type: {vtype}")

        param_name = f"{service.upper()}_{vtype.upper()}_VERSION"
        new_version = os.getenv(param_name)

        if not new_version:
            raise Exception(f"Missing parameter: {param_name}")

        file_name = f"{env}-{service}-{vtype}-version.yaml"

        patches.append({
            "service": service,
            "type": vtype,
            "version": new_version,
            "file": file_name
        })

# -----------------------------
# UPDATE YAML FILES
# -----------------------------
for patch in patches:

    file_path = os.path.join(repo, patch["file"])

    print(f"Updating {file_path} -> {patch['version']}")

    with open(file_path, "r") as file:
        data = yaml.load(file)

    data["image"]["tag"] = DoubleQuotedScalarString(patch["version"])

    with open(file_path, "w") as file:
        yaml.dump(data, file)

# -----------------------------
# GIT STATUS & DIFF
# -----------------------------
print(
    subprocess.run(
        ["git", "status"],
        cwd=repo,
        capture_output=True,
        text=True
    ).stdout
)

print(
    subprocess.run(
        ["git", "diff"],
        cwd=repo,
        capture_output=True,
        text=True
    ).stdout
)

# -----------------------------
# GIT ADD
# -----------------------------
subprocess.run(["git", "add", "."], cwd=repo)

# -----------------------------
# COMMIT
# -----------------------------
commitmsg = f"Patching {env.upper()} services versions"
subprocess.run(
    ["git", "commit", "-m", commitmsg],
    cwd=repo
)

# -----------------------------
# PUSH BRANCH
# -----------------------------
subprocess.run(
    ["git", "push", "--set-upstream", "origin", newbranch],
    cwd=repo
)

print("✅ All versions updated successfully")