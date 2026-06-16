import os
import subprocess
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
from datetime import datetime

yaml = YAML()
yaml.default_flow_style = False

# -----------------------------
# JENKINS PARAMETERS
# -----------------------------
env = os.getenv("ENVIRONMENT", "").strip().lower()

if env not in ["prod", "uat"]:
    raise Exception("Invalid Environment")

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
# CREATE BRANCH
# -----------------------------
today_date = datetime.now()
month_date = today_date.strftime("%b%d-%H-%M-%S")

newbranch = f"{month_date}-{env}-patching"

subprocess.run(
    ["git", "checkout", "-b", newbranch],
    cwd=repo,
    check=True
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
            raise Exception(f"Invalid type: {vtype}")

        if service == "ces":

            if vtype == "standard":
                new_version = os.getenv("CES_STD_VERSION")

            else:
                new_version = os.getenv("CES_PLT_VERSION")

        else:

            if vtype == "standard":
                new_version = os.getenv("TWX_STD_VERSION")

            else:
                new_version = os.getenv("TWX_PLT_VERSION")

        if not new_version:
            raise Exception(
                f"Version missing for {service}-{vtype}"
            )

        file_name = (
            f"{env}-{service}-{vtype}-version.yaml"
        )

        patches.append(
            {
                "file": file_name,
                "version": new_version
            }
        )

# -----------------------------
# UPDATE FILES
# -----------------------------
for patch in patches:

    file_path = os.path.join(
        repo,
        patch["file"]
    )

    print(
        f"Updating {file_path} -> {patch['version']}"
    )

    with open(file_path, "r") as file:
        data = yaml.load(file)

    data["image"]["tag"] = DoubleQuotedScalarString(
        patch["version"]
    )

    with open(file_path, "w") as file:
        yaml.dump(data, file)

    print(f"Updated {patch['file']}")

# -----------------------------
# GIT STATUS
# -----------------------------
gitstatus = subprocess.run(
    ["git", "status"],
    cwd=repo,
    capture_output=True,
    text=True
).stdout

print(gitstatus)

# -----------------------------
# GIT DIFF
# -----------------------------
gitdiff = subprocess.run(
    ["git", "diff"],
    cwd=repo,
    capture_output=True,
    text=True
).stdout

print(gitdiff)

# -----------------------------
# GIT ADD
# -----------------------------
subprocess.run(
    ["git", "add", "."],
    cwd=repo,
    check=True
)

# -----------------------------
# COMMIT
# -----------------------------
commitmsg = (
    f"Patching {env.upper()} image versions"
)

subprocess.run(
    ["git", "commit", "-m", commitmsg],
    cwd=repo,
    check=True
)

# -----------------------------
# PUSH
# -----------------------------
subprocess.run(
    [
        "git",
        "push",
        "--set-upstream",
        "origin",
        newbranch
    ],
    cwd=repo,
    check=True
)

print("All versions updated successfully")