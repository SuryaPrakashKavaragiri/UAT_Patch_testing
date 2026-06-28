#!/bin/bash
set -e

# shellScript.sh
# Surya Prakash <skavaragirir@crunchtime.com>
# v0.1 - 9/15/2025 - initial script

#PRE-REQUISITES
#must check if the new versions are avaialbe in registry

# This script will update version yaml files based on the type of patch and versions we give at time job.
# It uses the GitLab CLI tool, glab, to create a branch, commit changes, create a merge request.
# It will also update a GitLab banner notification with the target version and date of upgrade based on input.

# It is intended to be run from this Jenkins job
# https://jenkins-lab.crunchtime.it/job/Operations/job/test-uat-deploy/

# The following variables are provided to the script from parameters in the job
# PATCHING
#CES_TWX
#VERSION_TYPE
# CES_STD_VERSION, CES_PLT_VERSION, TWX_STD_VERSION & TWX_PLT_VERSION - AS PER THE REQUIREMENT

# The following variable is provided to the script from vault secrets in the job
# GITLAB_MR_TOKEN


# Validate PATCHING variables
##########################################
: "${TYPE:? TYPE not provided}"
: "${ENVIRONMENT:?ENVIRONMENT Type not provided}"
: "${CES_TWX:?CES_TWX not provided}"
: "${SITE_NAME:?SITE_NAME not provided}"
: "${GITHUB_PR_TOKEN:?GITHUB_PR_TOKEN not provided}"
#REFERENCE_TICKET use this to add description in MR


REPO=$(pwd)
GITHUB_USERNAME="SuryaPrakashKavaragiri"
REPO_OWNER="SuryaPrakashKavaragiri"
REPO_NAME="UAT_Patch_testing"

# Update YAML tag
#########################################
remove_ces_siteinfo() {
    local file="$1"
    local em_domain="${2%,}"
    local nc_domain="${3%,}"

    #yq e -i --arg em "$em_domain" --arg nc "$nc_domain" '
    yq e -i '
      .siteinfo |= map(
        select(
          (.web_emdomain | index("'"$em_domain"'") | not)
          and
          (.web_ncdomain | index("'"$nc_domain"'") | not)
        )
      )
    ' "$file"
}

remove_twx_siteinfo() {
    local file="$1"
    local twx_domain="${2%,}"
    #yq e -i --arg twx "$twx_domain" '
    yq e -i '
      .siteinfo |= map(
        select(
          (.web_twxdomain | index("'"$twx_domain"'") | not)
        )
      )
    ' "$file"
}

# # Build commit message
# #########################################
# build_commit_message() {
# local msg="${ENVIRONMENT^^} Patching"
# for pair in "$@"; do
#     msg="$msg | $pair"
# done
# echo "$msg"
# }

# # Configure remote
# #########################################
# push_remote() {
# git push \
# https://${GITHUB_USERNAME}:${GITHUB_PR_TOKEN}@github.com/${REPO_OWNER}/${REPO_NAME}.git \
# "$NEW_BRANCH"
# }


# # Create PR
# #########################################
# create_pr() {
# local source_branch=$1
# local target_branch=$2
# local title=$3

# echo "Creating PR..."
# echo "Source branch: $source_branch"
# echo "Target branch: $target_branch"


# echo "Curl version:"
# curl --version

# echo "Testing GitHub connectivity..."
# curl -v https://api.github.com


# response=$(curl -s \
#   -X POST \
#   -H "Authorization: Bearer $GITHUB_PR_TOKEN" \
#   -H "Accept: application/vnd.github+json" \
#   https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/pulls \
#   -d "{
#     \"title\":\"${title}\",
#     \"head\":\"${source_branch}\",
#     \"base\":\"${target_branch}\",
#     \"body\":\"Created automatically by Jenkins\"
#   }")

# echo "Response:"
# echo "$response"

# PR_URL=$(echo "$response" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)

# echo "======================================================"
# echo "REVIEW THIS PULL REQUEST"
# echo "$PR_URL"
# echo "======================================================"
# }

# Determine versions
#########################################
COMMIT_PARTS=()
IFS=',' read -ra SERVICES <<< "$CES_TWX"

if [[ "$TYPE" == "Site up" ]]; then
    case "$ENVIRONMENT" in
    prod)
    BASE_BRANCH="prod-k8s-c02"
    NEW_BRANCH="Adding ${SITE_NAME%,} sites"
    ;;
    uat)
    BASE_BRANCH="uat-oke-c01"
    NEW_BRANCH="Adding ${SITE_NAME%,} sites"
    ;;
    esac
elif [[ "$TYPE" == "Site down" ]]; then
    case "$ENVIRONMENT" in
    prod)
    BASE_BRANCH="prod-k8s-c02"
    NEW_BRANCH="Removing-${SITE_NAME%,}-sites"
    ;;
    uat)
    BASE_BRANCH="uat-oke-c01"
    NEW_BRANCH="Removing-${SITE_NAME%,}-sites"
    ;;
    esac
elif [[ "$TYPE" == "Disable site" ]]; then
    case "$ENVIRONMENT" in
    prod)
    BASE_BRANCH="prod-k8s-c02"
    NEW_BRANCH="Disabling-${SITE_NAME%,}-sites"
    ;;
    uat)
    BASE_BRANCH="uat-oke-c01"
    NEW_BRANCH="Disabling-${SITE_NAME%,}-sites"
    ;;
    esac
elif [[ "$TYPE" == "Enable site" ]]; then
    case "$ENVIRONMENT" in
    prod)
    BASE_BRANCH="prod-k8s-c02"
    NEW_BRANCH="Enabling_${SITE_NAME%,}_sites"
    ;;
    uat)
    BASE_BRANCH="uat-oke-c01"
    NEW_BRANCH="Enabling ${SITE_NAME%,} sites"
    ;;
    esac

    fi

export GITHUB_TOKEN="$GITHUB_PR_TOKEN"
#echo "$GITHUB_PR_TOKEN" | gh auth login --with-token
gh auth status

git config user.name "skavaragiri"
git config user.email "skavaragiri@crunchtime.com"


git checkout -B "$BASE_BRANCH" "origin/$BASE_BRANCH"
echo "Current branch after checkout:"
git branch --show-current
cd opsmgmt/helm || exit 1

shopt -s nullglob
ces_files_list=(ces*)
twx_files_list=(twx*)

for SERVICE in "${SERVICES[@]}"; do

if [[ "$SERVICE" == "ces" ]]; then
for file in "${ces_files_list[@]}"; do
remove_ces_siteinfo "$file" "$EM_WEB_DOMAIN" "$NC_WEB_DOMAIN"
done
fi

if [[ "$SERVICE" == "twx" ]]; then
for file in "${twx_files_list[@]}"; do
remove_twx_siteinfo "$file" "$TWX_WEB_DOMAIN"
done
fi
done

git diff
git add -A
git status



#COMMIT_MSG=$(build_commit_message "${COMMIT_PARTS[@]}")

git commit -m "$NEW_BRANCH"

#push_remote

git push --set-upstream origin "$NEW_BRANCH"

gh pr create \
  --title "$NEW_BRANCH" \
  --body "$REFERENCE_TICKET" \
  --base "$BASE_BRANCH" \
  --head "$NEW_BRANCH"

#create_pr "$NEW_BRANCH" "$BASE_BRANCH" "$COMMIT_MSG"

echo
echo "==============================================================="
echo "Updated successfully"
echo "==============================================================="

#=======================================================================================================================================


