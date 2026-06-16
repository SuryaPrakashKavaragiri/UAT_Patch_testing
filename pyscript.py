import subprocess
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import DoubleQuotedScalarString
import os
from datetime import datetime

yaml = YAML()
yaml.default_flow_style=False

env=os.getenv("ENVIRONMENT")
service_type=list(os.getenv("CES_TWX",","))
version_type=list(os.getenv("VERSION_TYPE"))

if env=="prod":
    if len(service_type)==2:
        if len(version_type)
        ces_versions=list(os.getenv("CES_STD_VERSION"),os.getenv("CES_PLT_VERSION"))
        ces_versions=list(os.getenv("TWX_STD_VERSION"),os.getenv("TWX_PLT_VERSION"))





    elif len(service_type)==1:
        if service[0]=="ces":
            pass



        elif service_type[0]=="twx":
            pass


    else:
        raise Exception("Invalid Service, Select Service to patch")
    
    

        






elif env=="uat":
    pass







else:
    raise Exception("Invalid Environment, Select Environment Prod or UAT")


ces_ver_std = os.getenv("CES_VERSION") #input("Enter CES version: ") 

if not ces_ver_std:
    raise Exception("CES_VERSION not provided")

repo="C:\Users\Accentiqa_30\Desktop\UAT_Patch_testing"
#file_path=f"{repo}\\version-standard-ces.yaml"

gitpull=subprocess.run(["git","pull"],cwd=repo,capture_output=True,text=True).stdout
print(gitpull)
#gitchangebranch=subprocess.run(["git","checkout","uat-oke-c01"])

today_date=datetime.now()
month_date=today_date.strftime("%b%d-%H:%M:%S")
newbranch=f"{month_date}-UAT-Patching" #f"uat-ash/{month_date}-UAT-Patching"
gitbranch=subprocess.run(["git","checkout","-b",newbranch],cwd=repo)

#gitchangepath=subprocess.run(["git","checkout","-b",newbranch])

#read file
with open(file_path,"r") as file:
    data = yaml.load(file)

#modify values
data["image"]["tag"] = DoubleQuotedScalarString(version)


# write back
with open(file_path, "w") as file:
    yaml.dump(data, file)

gitdiff= subprocess.run(["git","diff"],cwd=repo,capture_output=True,text=True).stdout
print(gitdiff)

gitstatus=subprocess.run(["git","status"],cwd=repo,capture_output=True,text=True).stdout
print(gitstatus)

gitadd=subprocess.run(["git","add","*"],cwd=repo)

commitmsg=f"Patching CES {version} to UAT"
gitcommit=subprocess.run(["git","commit","-m",commitmsg],cwd=repo)

#gitpush=subprocess.run(["git","push"],cwd=repo)

gitpush2=subprocess.run(["git","push","--set-upstream","origin",newbranch],cwd=repo)
# gitchangemain=subprocess.run(["git","checkout","main"],cwd=repo)

# git push --set-upstream origin newbranch
# git push -u origin branch_name

# gitchangemain=subprocess.run(["git","checkout","main"],cwd=repo)
# gitpull1=subprocess.run(["git","pull","orgin","main"],cwd=repo)
# gitmerge=subprocess.run(["git","merge",newbranch],cwd=repo,capture_output=True,text=True).stdout
# gitpush2=subprocess.run(["git","push","origin","main"],cwd=repo,capture_output=True,text=True).stdout


print("Updated tag:", version)
