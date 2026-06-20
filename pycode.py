import subprocess
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
import os
import requests
from datetime import datetime

yaml = YAML()
yaml.default_flow_style=False


#token = os.getenv("GITHUB_TOKEN")

def create_pr(repo_owner, repo_name, source_branch, target_branch, title, body):
    token = os.getenv("GITHUB_TOKEN")

    if not token:
        raise Exception("GITHUB_TOKEN environment variable not found")

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json"
    }

    payload = {
        "title": title,
        "head": source_branch,
        "base": target_branch,
        "body": body
    }

    response = requests.post(
        f"https://api.github.com/repos/{repo_owner}/{repo_name}/pulls",
        headers=headers,
        json=payload
    )

    if response.status_code not in [200, 201]:
        print(response.text)
        response.raise_for_status()
    print("Creating PR...")
    print("Source branch:", source_branch)
    print("Target branch:", target_branch)
    
    data = response.json()
    if "html_url" not in data:
        raise Exception(f"PR creation failed: {data}")
    return data["html_url"]

env=os.getenv("ENVIRONMENT")
if not env:
    raise Exception("ENVIRONMENT not provided")

service_env = os.getenv("CES_TWX")
if not service_env:
    raise Exception("CES_TWX not provided")
service_type=service_env.split(",")

version_env = os.getenv("VERSION_TYPE")
if not version_env:
    raise Exception("VERSION_TYPE not provided")
version_type = version_env.split(",")


def function():
    if not service_type:
        raise Exception("Invalid Service, Select Service to patch")

    if len(service_type)==2:
        if len(version_type)==2:
            versions={"cesstd":os.getenv("CES_STD_VERSION"),"cesplt":os.getenv("CES_PLT_VERSION"),"twxstd":os.getenv("TWX_STD_VERSION"),"twxplt":os.getenv("TWX_PLT_VERSION")}
        elif len(version_type)==1:
            if "standard" in version_type and env=="dbi":
                versions={"dbices":os.getenv("DBICES_STD_VERSION"),"dbitwx":os.getenv("DBITWX_STD_VERSION")}
            elif "standard" in version_type:
                versions={"cesstd":os.getenv("CES_STD_VERSION"),"twxstd":os.getenv("TWX_STD_VERSION")}
            else:
                versions={"cesplt":os.getenv("CES_PLT_VERSION"),"twxplt":os.getenv("TWX_PLT_VERSION")}
            
    elif len(service_type)==1:
        if not version_type:
            raise Exception("Invalid service Type, select 'ces or twx'")     
        if "ces" in service_type:
            if len(version_type)==2:
                versions={"cesstd":os.getenv("CES_STD_VERSION"),"cesplt":os.getenv("CES_PLT_VERSION")}
            elif len(version_type)==1:
                if "standard" in version_type:
                    versions={"cesstd":os.getenv("CES_STD_VERSION")}
                elif "platinum" in version_type:
                    versions={"cesplt":os.getenv("CES_PLT_VERSION")}
                else:
                    raise Exception("Invalid Version Type, select 'standard or platinum'")
        elif "twx" in service_type:
            if len(version_type)==2:
                versions={"twxstd":os.getenv("TWX_STD_VERSION"),"twxplt":os.getenv("TWX_PLT_VERSION")}
            elif len(version_type)==1:
                if "standard" in version_type:
                    versions={"twxstd":os.getenv("TWX_STD_VERSION")}
                elif "platinum" in version_type:
                    versions={"twxplt":os.getenv("TWX_PLT_VERSION")}
                else:
                    raise Exception("Invalid Version Type, select 'standard or platinum'")
        else:
            raise Exception("Invalid service Type, select 'ces' or 'twx'")
    return versions

versions=function()

def build_commit_message(env, versions):
    version_parts = []

    for key, value in versions.items():
        value = value.strip().rstrip(",")
        version_parts.append(f"{key.upper()}:{value}")

    return f"{env.upper()} Patching - " + " | ".join(version_parts)

today_date=datetime.now()
month_date=today_date.strftime("%b%d-%H%M%S")

repo = os.getcwd()
#repo=r"C:/ProgramData/Jenkins/.jenkins/workspace/test-uat-deploy"

github_username = os.getenv("GITHUB_USERNAME")
github_token = os.getenv("GITHUB_TOKEN")
if not github_username:
    raise Exception("GITHUB_USERNAME environment variable not found")
if not github_token:
    raise Exception("GITHUB_TOKEN environment variable not found")


def configure_https_remote():
    subprocess.run([
        "git",
        "remote",
        "set-url",
        "origin",
        f"https://{github_username}:{github_token}@github.com/SuryaPrakashKavaragiri/UAT_Patch_testing.git"
    ], cwd=repo, check=True)


def loopversion(versions):
    for key,value in versions.items():
        value = value.strip().rstrip(",")
        if key=="cesstd":
            #read file
            with open(f"{repo}/opsmgmt/version-standard-ces.yaml","r") as file:
                data = yaml.load(file)
            #modify values
            data["image"]["tag"] = DoubleQuotedScalarString(value)
            # write back
            with open(f"{repo}/opsmgmt/version-standard-ces.yaml", "w") as file:
                yaml.dump(data, file)
        elif key=="cesplt":
            #read file
            with open(f"{repo}/opsmgmt/version-platinum-ces.yaml","r") as file:
                data = yaml.load(file)
            #modify values
            data["image"]["tag"] = DoubleQuotedScalarString(value)
            # write back
            with open(f"{repo}/opsmgmt/version-platinum-ces.yaml", "w") as file:
                yaml.dump(data, file)
        elif key=="twxstd":
            #read file
            with open(f"{repo}/opsmgmt/version-standard-twx.yaml","r") as file:
                data = yaml.load(file)
            #modify values
            data["image"]["tag"] = DoubleQuotedScalarString(value)
            # write back
            with open(f"{repo}/opsmgmt/version-standard-twx.yaml", "w") as file:
                yaml.dump(data, file)
        elif key=="twxplt":
            #read file
            with open(f"{repo}/opsmgmt/version-platinum-twx.yaml","r") as file:
                data = yaml.load(file)
            #modify values
            data["image"]["tag"] = DoubleQuotedScalarString(value)
            # write back
            with open(f"{repo}/opsmgmt/version-platinum-twx.yaml", "w") as file:
                yaml.dump(data, file)
        elif key=="dbices":
            #read file
            with open(f"{repo}/opsmgmt/version-dbi-ces.yaml","r") as file:
                data = yaml.load(file)
            #modify values
            data["image"]["tag"] = DoubleQuotedScalarString(value)
            # write back
            with open(f"{repo}/opsmgmt/version-dbi-ces.yaml", "w") as file:
                yaml.dump(data, file)
        elif key=="dbitwx":
            #read file
            with open(f"{repo}/opsmgmt/version-dbi-twx.yaml","r") as file:
                data = yaml.load(file)
            #modify values
            data["image"]["tag"] = DoubleQuotedScalarString(value)
            # write back
            with open(f"{repo}/opsmgmt/version-dbi-twx.yaml", "w") as file:
                yaml.dump(data, file)
        else:
            raise Exception("check the versions...")


if env=="prod":
    gitchangebranch=subprocess.run(["git","checkout","-B","prod-k8s-c02","origin/prod-k8s-c02"],cwd=repo,check=True)
    print("Checkout output:")
    print(gitchangebranch.stdout)
    print(gitchangebranch.stderr)
    newbranch=f"{month_date}-Prod-Patching" #f"prod/{month_date}-UAT-Patching"
    gitbranch=subprocess.run(["git","checkout","-b",newbranch],cwd=repo,check=True)
    
    loopversion(versions)
    
    gitdiff= subprocess.run(["git","diff"],cwd=repo,capture_output=True,text=True).stdout
    print(gitdiff)
    gitstatus=subprocess.run(["git","status"],cwd=repo,capture_output=True,text=True).stdout
    print(gitstatus)
    gitadd=subprocess.run(["git","add","-A"],cwd=repo,check=True)
    gitconfigname=subprocess.run(["git","config","user.name","skavaragiri"],cwd=repo,check=True)
    gitconfigemail=subprocess.run(["git","config","user.email","skavaragiri@crunchtime.com"],cwd=repo,check=True)
    commitmsg = build_commit_message(env, versions)
    gitcommit=subprocess.run(["git","commit","-m",commitmsg],cwd=repo,check=True)

    configure_https_remote()

    gitpush=subprocess.run(["git","push","--set-upstream","origin",newbranch],cwd=repo,check=True)
    pr_url = create_pr(
    repo_owner="SuryaPrakashKavaragiri",
    repo_name="UAT_Patch_testing",
    source_branch=newbranch,
    target_branch="prod-k8s-c02",
    title=commitmsg,
    body="Created automatically by Jenkins"
    )
    print("=" * 80)
    print("REVIEW THIS PULL REQUEST")
    print(pr_url)
    print("=" * 80)

elif env=="dbi":
    gitchangebranch=subprocess.run(["git","checkout","-B","prod-k8s-c02","origin/prod-k8s-c02"],cwd=repo,check=True)
    print("Checkout output:")
    print(gitchangebranch.stdout)
    print(gitchangebranch.stderr)
    newbranch=f"{month_date}-DBI-Patching" #f"prod/{month_date}-UAT-Patching"
    gitbranch=subprocess.run(["git","checkout","-b",newbranch],cwd=repo,check=True)
    
    loopversion(versions)

    gitdiff= subprocess.run(["git","diff"],cwd=repo,capture_output=True,text=True).stdout
    print(gitdiff)
    gitstatus=subprocess.run(["git","status"],cwd=repo,capture_output=True,text=True).stdout
    print(gitstatus)
    gitadd=subprocess.run(["git","add","-A"],cwd=repo,check=True)
    gitconfigname=subprocess.run(["git","config","user.name","skavaragiri"],cwd=repo,check=True)
    gitconfigemail=subprocess.run(["git","config","user.email","skavaragiri@crunchtime.com"],cwd=repo,check=True)
    commitmsg = build_commit_message(env, versions)
    gitcommit=subprocess.run(["git","commit","-m",commitmsg],cwd=repo,check=True)
    
    configure_https_remote()

    gitpush=subprocess.run(["git","push","--set-upstream","origin",newbranch],cwd=repo,check=True)
    pr_url = create_pr(
    repo_owner="SuryaPrakashKavaragiri",
    repo_name="UAT_Patch_testing",
    source_branch=newbranch,
    target_branch="prod-k8s-c02",
    title=commitmsg,
    body="Created automatically by Jenkins"
    )
    print("=" * 80)
    print("REVIEW THIS PULL REQUEST")
    print(pr_url)
    print("=" * 80)

elif env=="uat":
    gitchangebranch=subprocess.run(["git","checkout","-B","uat-oke-c01","origin/uat-oke-c01"],cwd=repo,check=True)
    print("Checkout output:")
    print(gitchangebranch.stdout)
    print(gitchangebranch.stderr)
    newbranch=f"{month_date}-UAT-Patching" #f"uat-ash/{month_date}-UAT-Patching"
    gitbranch=subprocess.run(["git","checkout","-b",newbranch],cwd=repo,check=True)
   
    loopversion(versions)
    
    gitdiff= subprocess.run(["git","diff"],cwd=repo,capture_output=True,text=True).stdout
    print(gitdiff)
    gitstatus=subprocess.run(["git","status"],cwd=repo,capture_output=True,text=True).stdout
    print(gitstatus)
    gitadd=subprocess.run(["git","add","-A"],cwd=repo,check=True)
    gitconfigname=subprocess.run(["git","config","user.name","skavaragiri"],cwd=repo,check=True)
    gitconfigemail=subprocess.run(["git","config","user.email","skavaragiri@crunchtime.com"],cwd=repo,check=True)
    commitmsg = build_commit_message(env, versions)
    gitcommit=subprocess.run(["git","commit","-m",commitmsg],cwd=repo,check=True)
    
    configure_https_remote()

    gitpush=subprocess.run(["git","push","--set-upstream","origin",newbranch],
                           cwd=repo,
                           check=True)
    pr_url = create_pr(
    repo_owner="SuryaPrakashKavaragiri",
    repo_name="UAT_Patch_testing",
    source_branch=newbranch,
    target_branch="uat-oke-c01",
    title=commitmsg,
    body="Created automatically by Jenkins"
    )
    print("=" * 80)
    print("REVIEW THIS PULL REQUEST")
    print(pr_url)
    print("=" * 80)

else:
    raise Exception("Invalid Environment, Select Environment Prod or UAT")

print("Updated tag:", versions)

