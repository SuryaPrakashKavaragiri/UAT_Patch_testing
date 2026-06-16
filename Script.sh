set -e


if [ -z "$ENVIRONMENT" ]; then 
    echo "ERROR: "
fi

if [ -z "$version" ]; then
  echo "ERROR: CES_VERSION not provided"
  exit 1
fi



echo "=============================="
echo "STEP 1: Reading input version"
echo "=============================="

ces_version="$CES_VERSION"

if [ -z "$version" ]; then
  echo "ERROR: CES_VERSION not provided"
  exit 1
fi

echo "VERSION: $version"

repo="C:\Users\Accentiqa_30\Desktop\UAT_Patch_testing"        #this path is in my localmachine repopath
file="$repo/version-standard-ces.yaml"

cd "$repo"
echo "STEP 2: Changed directory to repo -> $repo"

#echo "=============================="
#echo "STEP 3: Git pull"
#echo "=============================="
#git pull
#echo "Git pull completed"

echo "=============================="
echo "STEP 4: Create new branch"
echo "=============================="

branch_date=$(date +"%b%d-%H%M%S")
newbranch="${branch_date}-UAT-Patching"

git checkout -b "$newbranch"
echo "Branch created -> $newbranch"

echo "=============================="
echo "STEP 5: Update YAML file"
echo "=============================="

echo "Before update:"
grep "tag:" "$file"

sed -i 's/^  tag: .*/  tag: "'"$version"'"/' "$file"

echo "After update:"
grep "tag:" "$file"

echo "YAML update completed"

echo "=============================="
echo "STEP 6: Git status & diff"
echo "=============================="

git diff
git status

echo "=============================="
echo "STEP 7: Git commit"
echo "=============================="

git config user.name "skavaragiri"
git config user.email "skavaragiri@crunchtime.com"

git add .
git commit -m "Patching CES $version to UAT"
echo "Commit completed"

echo "=============================="
echo "STEP 8: Push branch"
echo "=============================="

git push --set-upstream origin "$newbranch"
echo "Push completed"

echo "=============================="
echo "FINAL STATUS"
echo "=============================="

echo "Updated tag: $version"
echo "Branch pushed: $newbranch"