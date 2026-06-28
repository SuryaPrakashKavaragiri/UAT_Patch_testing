#!/bin/bash
set -e


echo "Current branch before checkout:"
git branch --show-current

echo "Available remote branches:"
git branch -r


#########################################

# Validate environment variables

#########################################

: "${ENVIRONMENT:?ENVIRONMENT not provided}"
: "${CES_TWX:?CES_TWX not provided}"
: "${VERSION_TYPE:?VERSION_TYPE not provided}"
: "${GITHUB_PR_TOKEN:?GITHUB_PR_TOKEN not provided}"

REPO=$(pwd)
GITHUB_USERNAME="SuryaPrakashKavaragiri"
REPO_OWNER="SuryaPrakashKavaragiri"
REPO_NAME="UAT_Patch_testing"

MONTH_DATE=$(date +"%b%d-%H%M%S")

#########################################

# Update YAML tag

#########################################

update_tag() {
FILE=$1
VERSION=${2%,}

echo "Updating $FILE -> $VERSION"

sed -i -E 's/^([[:space:]]*tag:).*/\1 "'"$VERSION"'"/' "$FILE"

}

#########################################

# Build commit message

#########################################

build_commit_message() {
local msg="${ENVIRONMENT^^} Patching"

for pair in "$@"; do
    msg="$msg | $pair"
done

echo "$msg"

}

#########################################

# Configure remote

#########################################

push_remote() {
git push \
https://${GITHUB_USERNAME}:${GITHUB_PR_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git \
"$NEW_BRANCH"
}
#########################################

# Create PR

#########################################

create_pr() {
local source_branch=$1
local target_branch=$2
local title=$3

echo "Creating PR..."
echo "Source branch: $source_branch"
echo "Target branch: $target_branch"


echo "Curl version:"
curl --version

echo "Testing GitHub connectivity..."
curl -v https://api.github.com


response=$(curl -s \
  -X POST \
  -H "Authorization: Bearer $GITHUB_PR_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/pulls \
  -d "{
    \"title\":\"${title}\",
    \"head\":\"${source_branch}\",
    \"base\":\"${target_branch}\",
    \"body\":\"Created automatically by Jenkins\"
  }")

echo "Response:"
echo "$response"

PR_URL=$(echo "$response" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)

echo "======================================================"
echo "REVIEW THIS PULL REQUEST"
echo "$PR_URL"
echo "======================================================"

}

#########################################

# Determine versions

#########################################

COMMIT_PARTS=()

IFS=',' read -ra SERVICES <<< "$CES_TWX"
IFS=',' read -ra TYPES <<< "$VERSION_TYPE"



#########################################

# Environment branch settings

#########################################

case "$ENVIRONMENT" in

prod)
BASE_BRANCH="prod-k8s-c02"
NEW_BRANCH="${MONTH_DATE}-Prod-Patching"
;;

dbi)
BASE_BRANCH="prod-k8s-c02"
NEW_BRANCH="${MONTH_DATE}-DBI-Patching"
;;

uat)
BASE_BRANCH="uat-oke-c01"
NEW_BRANCH="${MONTH_DATE}-UAT-Patching"
;;

*)
echo "Invalid environment"
exit 1
;;
esac

#########################################

# Git operations

#########################################

git checkout -B "$BASE_BRANCH" "origin/$BASE_BRANCH"


echo "Current branch after checkout:"
git branch --show-current

echo "opsmgmt contents:"
ls -la opsmgmt


git checkout -b "$NEW_BRANCH"


for SERVICE in "${SERVICES[@]}"; do

if [[ "$SERVICE" == "ces" ]]; then

    if [[ "$VERSION_TYPE" == *"standard"* ]]; then
        update_tag "$REPO/opsmgmt/version-standard-ces.yaml" "$CES_STD_VERSION"
        COMMIT_PARTS+=("CESSTD:$CES_STD_VERSION")
    fi

    if [[ "$VERSION_TYPE" == *"platinum"* ]]; then
        update_tag "$REPO/opsmgmt/version-platinum-ces.yaml" "$CES_PLT_VERSION"
        COMMIT_PARTS+=("CESPLT:$CES_PLT_VERSION")
    fi

elif [[ "$SERVICE" == "twx" ]]; then

    if [[ "$VERSION_TYPE" == *"standard"* ]]; then
        update_tag "$REPO/opsmgmt/version-standard-twx.yaml" "$TWX_STD_VERSION"
        COMMIT_PARTS+=("TWXSTD:$TWX_STD_VERSION")
    fi

    if [[ "$VERSION_TYPE" == *"platinum"* ]]; then
        update_tag "$REPO/opsmgmt/version-platinum-twx.yaml" "$TWX_PLT_VERSION"
        COMMIT_PARTS+=("TWXPLT:$TWX_PLT_VERSION")
    fi
fi

done


git diff
git status

git add -A

git config user.name "skavaragiri"
git config user.email "skavaragiri@crunchtime.com"

COMMIT_MSG=$(build_commit_message "${COMMIT_PARTS[@]}")

git commit -m "$COMMIT_MSG"

push_remote

#git push --set-upstream origin "$NEW_BRANCH"

create_pr "$NEW_BRANCH" "$BASE_BRANCH" "$COMMIT_MSG"

echo
echo "==============================================================="
echo "Updated successfully"
echo "==============================================================="

