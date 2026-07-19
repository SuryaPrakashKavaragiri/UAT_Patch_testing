#!/bin/bash
set -e

# shellScript.sh
# Surya Prakash <skavaragirir@crunchtime.com>
# v0.1 - 9/15/2025 - initial script


# Validate PATCHING variables
##########################################
: "${TYPE:? TYPE not provided}"
: "${ENVIRONMENT:?ENVIRONMENT Type not provided}"
: "${CES_TWX:?CES_TWX not provided}"
: "${SITE_NAME:?SITE_NAME not provided}"
: "${SITE_BRING_UP_DATA:?SITE_BRING_UP_DATA not provided}"
: "${GITHUB_PR_TOKEN:?GITHUB_PR_TOKEN not provided}"

SITE_NAME="${SITE_NAME%,}"

if [[ -z "${SITE_NAME%,}" ]]; then
    echo "SITE_NAME not provided"
    exit 1
fi

# if [[ -z "$SITE_BRING_UP_DATA" ]]; then
#     echo "SITE_BRING_UP_DATA not provided"
#     exit 1
# fi

if [[ -z "${SITE_BRING_UP_DATA//[[:space:]]/}" ]]; then
    echo "SITE_BRING_UP_DATA not provided"
    exit 1
fi



# if [[ "$TYPE" == "Site up" && "$CES_TWX" == "ces" ]]; then
#     : "${CES_DEPLOYMENT_NAME:?CES_DEPLOYMENT_NAME not provided}"
# fi

# if [[ "$TYPE" == "Site up" && "$CES_TWX" == "twx" ]]; then
#     : "${TWX_DEPLOYMENT_NAME:?TWX_DEPLOYMENT_NAME not provided}"
# fi


if [[ "$TYPE" == "Site up" && "$CES_TWX" == *"ces"* ]]; then
    if [[ -z "${CES_DEPLOYMENT_NAME%,}" ]]; then
      echo "CES_DEPLOYMENT_NAME not provided"
      exit 1
    fi
fi

if [[ "$TYPE" == "Site up" && "$CES_TWX" == *"twx"* ]]; then
    if [[ -z "${TWX_DEPLOYMENT_NAME%,}" ]]; then
      echo "TWX_DEPLOYMENT_NAME not provided"
      exit 1
    fi
fi


#REFERENCE_TICKET use this to add description in MR
#: "${REFERENCE_TICKET:?REFERENCE_TICKET not provided}"


REPO=$(pwd)
GITHUB_USERNAME="SuryaPrakashKavaragiri"
REPO_OWNER="SuryaPrakashKavaragiri"
REPO_NAME="UAT_Patch_testing"



# Update YAML tag
#########################################


remove_ces_siteinfo() {
    local file="$1"
    local em="$2"
    local nc="$3"

      #yq e -i --arg em "$em_domain" --arg nc "$nc_domain" '
      yq e -i '
        .siteinfo |= map(
          select(
            (.web_emdomain | contains(["'"$em"'"]) | not)
            and
            (.web_ncdomain | contains(["'"$nc"'"]) | not)
          )
        )
      ' "$file"
}

remove_twx_siteinfo() {
    local file="$1"
    local twx="$2"

      #yq e -i --arg twx "$twx_domain" '
      yq e -i '
        .siteinfo |= map(
          select(
            (.web_twxdomain | contains(["'"$twx"'"]) | not)
          )
       )
      ' "$file"
}


disable_ces_siteinfo() {
    local file="$1"
    local em="$2"
    local nc="$3"

    yq e -i '
      .siteinfo |= map(
        if (
          (.web_emdomain | contains(["'"$em"'"]))
          and
          (.web_ncdomain | contains(["'"$nc"'"]))
        )
        then
          .disable = true
        else
          .
        end
      )
    ' "$file"
}



disable_twx_siteinfo() {
    local file="$1"
    local twx="$2"

    yq e -i '
      .siteinfo |= map(
        if (.web_twxdomain | contains(["'"$twx"'"]))
        then
          .disable = true
        else
          .
        end
      )
    ' "$file"
}

enable_ces_siteinfo() {
    local file="$1"
    local em="$2"
    local nc="$3"

    yq e -i '
      .siteinfo |= map(
        if (
          (.web_emdomain | contains(["'"$em"'"]))
          and
          (.web_ncdomain | contains(["'"$nc"'"]))
          and
          (.disable == true)
        )
        then
          del(.disable)
        else
          .
        end
      )
    ' "$file"
}


enable_twx_siteinfo() {
    local file="$1"
    local twx="$2"

    yq e -i '
      .siteinfo |= map(
        if (.web_twxdomain | contains(["'"$twx"'"])) and (.disable == true)
        then
          del(.disable)
        else
          .
        end
      )
    ' "$file"
}

# add_siteinfo() {
#     local file="$1"
#     local data="$2"

#     yq -i '.siteinfo += [load("/dev/stdin")]' "$file" <<< "$data"
# }


# add_siteinfo() {
#     local file=$1
#     local data=$2

#     local tmpfile
#     tmpfile=$(mktemp)

#     printf '%s\n' "$data" > "$tmpfile"

#     # Convert Git Bash path to Windows path
#     local tmpfile_win
#     tmpfile_win=$(cygpath -w "$tmpfile")

#     yq -i ".siteinfo += [load(\"$tmpfile_win\")]" "$file"

#     rm -f "$tmpfile"
# }


add_siteinfo() {
    local file=$1
    local data=$2

    export SITEINFO_DATA="$data"

    yq -i '.siteinfo += [strenv(SITEINFO_DATA) | from_yaml]' "$file"

    unset SITEINFO_DATA
}


# Determine versions
#########################################
COMMIT_PARTS=()
IFS=',' read -ra SERVICES <<< "$CES_TWX"
IFS=',' read -r -a CES_DEPLOYMENT_NAME <<< "${CES_DEPLOYMENT_NAME%,}"
IFS=',' read -r -a TWX_DEPLOYMENT_NAME <<< "${TWX_DEPLOYMENT_NAME%,}"
IFS=',' read -r -a EM_WEB_DOMAIN <<< "${EM_WEB_DOMAIN%,}"
IFS=',' read -r -a NC_WEB_DOMAIN <<< "${NC_WEB_DOMAIN%,}"
IFS=',' read -r -a TWX_WEB_DOMAIN <<< "${TWX_WEB_DOMAIN%,}"

if [[ "$TYPE" == "Site up" ]]; then
    case "$ENVIRONMENT" in
    prod)
    BASE_BRANCH="prod-k8s-c02"
    NEW_BRANCH="Adding-${SITE_NAME%,}-sites"
    ;;
    uat)
    BASE_BRANCH="uat-oke-c01"
    NEW_BRANCH="Adding-${SITE_NAME%,}-sites"
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
    NEW_BRANCH="Re-enabling-${SITE_NAME%,}-sites"
    ;;
    uat)
    BASE_BRANCH="uat-oke-c01"
    NEW_BRANCH="Re-enabling-${SITE_NAME%,}-sites"
    ;;
    esac

    fi



git clean -fdx
git reset --hard
export GITHUB_TOKEN="$GITHUB_PR_TOKEN"
#echo "$GITHUB_PR_TOKEN" | gh auth login --with-token
gh auth status

git config user.name "skavaragiri"
git config user.email "skavaragiri@crunchtime.com"

git remote set-url origin https://$GITHUB_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git


git checkout -B "$BASE_BRANCH" "origin/$BASE_BRANCH"
echo "Current branch after checkout:"
git branch --show-current

git push origin --delete "$NEW_BRANCH" 2>/dev/null || true

git checkout -B "$NEW_BRANCH"

cd opsmgmt/helm || exit 1

shopt -s nullglob


if [[ -n "$CES_DEPLOYMENT_NAME" ]]; then
    ces_file_name=("$CES_DEPLOYMENT_NAME")
else
    ces_file_name=(ces*)
fi
# Validate CES deployment file
if [[ "$TYPE" == "Site up" && "$CES_TWX" == *"ces"* ]]; then
    if [[ ! -f "$ces_file_name[0]}" ]]; then
        echo "Error: CES deployment file '$ces_file_name[0]}' does not exist."
        echo "Available CES deployment files:"
        ls -1 ces*
        exit 1
    fi
fi

if [[ -n "$TWX_DEPLOYMENT_NAME" ]]; then
    twx_files_list=("$TWX_DEPLOYMENT_NAME")
else
    twx_files_list=(twx*)
fi
# Validate TWX deployment file
if [[ "$TYPE" == "Site up" && "$CES_TWX" == *"twx"* ]]; then
    if [[ ! -f "${twx_files_list[0]}" ]]; then
        echo "Error: TWX deployment file '${twx_files_list[0]}' does not exist."
        echo "Available TWX deployment files:"
        ls -1 twx*
        exit 1
    fi
fi


# Debugging
yq --version
which yq
cygpath -w "$(mktemp)"


for SERVICE in "${SERVICES[@]}"; do
  case "$TYPE" in 
  "Site up")
    # if [[ "$SERVICE" == "ces" ]]; then
    #   CES_DATA=$(printf '%s\n' "$SITE_BRING_UP_DATA" | \
    #     yq -o=yaml '.[] | select(has("web_emdomain"))')
    #   DOMAIN=$(printf '%s\n' "$CES_DATA" | yq '.web_emdomain')
    #   if yq -e ".[] | select(.web_emdomain == \"$DOMAIN\")" "$ces_file_name" >/dev/null 2>&1; then
    #     echo "Entry for $DOMAIN already exists."
    #   else
    #     add_siteinfo "$ces_file_name" "$CES_DATA"
    #   fi
    # fi

    # if [[ "$SERVICE" == "twx" ]]; then
    #   TWX_DATA=$(printf '%s\n' "$SITE_BRING_UP_DATA" | \
    #     yq -o=yaml '.[] | select(has("web_twxdomain"))')
    #   DOMAIN=$(printf '%s\n' "$TWX_DATA" | yq '.web_twxdomain')
    #   if yq -e ".[] | select(.web_twxdomain == \"$DOMAIN\")" "$twx_file_name" >/dev/null 2>&1; then
    #     echo "Entry for $DOMAIN already exists."
    #   else
    #     add_siteinfo "$twx_file_name" "$TWX_DATA"
    #   fi
    # fi

    if [[ "$SERVICE" == "ces" ]]; then
      #printf '%s\n' "$SITE_BRING_UP_DATA" |
      echo "===== RAW DATA ====="
      printf '%s\n' "$SITE_BRING_UP_DATA" | cat -A
      echo "===================="
      CLEAN_DATA=$(printf '%s' "$SITE_BRING_UP_DATA" | sed 's/\xC2\xA0/ /g')
      printf '%s\n' "$CLEAN_DATA" |
      yq -o=json -I=0 '.[] | select(has("web_emdomain"))' |
      while IFS= read -r entry; do

        CES_DATA=$(printf '%s\n' "$entry" | yq -P)

        EM_DOMAIN=$(printf '%s\n' "$CES_DATA" | yq -r '.web_emdomain[0]')
        NC_DOMAIN=$(printf '%s\n' "$CES_DATA" | yq -r '.web_ncdomain[0]')

        file="${ces_file_name[0]}"

          if yq -e \
              ".siteinfo[] | select(.web_emdomain[0] == \"$EM_DOMAIN\" and .web_ncdomain[0] == \"$NC_DOMAIN\")" \
              "$file" >/dev/null 2>&1; then

              echo "Entry for web_emdomain=$EM_DOMAIN and web_ncdomain=$NC_DOMAIN already exists in $file. Skipping."
              exit 1

          else

              add_siteinfo "$file" "$CES_DATA"

          fi
      done
    fi

    if [[ "$SERVICE" == "twx" ]]; then
        printf '%s\n' "$SITE_BRING_UP_DATA" |
        yq -o=json '.[] | select(has("web_twxdomain"))' |
        while IFS= read -r entry; do

            TWX_DATA=$(printf '%s\n' "$entry" | yq -P)

            DOMAIN=$(printf '%s\n' "$TWX_DATA" | yq -r '.web_twxdomain[0]')
            file="${twx_files_list[0]}"
            if yq -e \
                ".siteinfo[] | select(.web_twxdomain[0] == \"$DOMAIN\")" \
                "$file" >/dev/null 2>&1; then
                echo "Entry for web_twxdomain=$DOMAIN already exists. Skipping."
                exit 1
            else
                add_siteinfo "$file" "$TWX_DATA"
            fi
        done
    fi

  ;;
  "Site down")
    if [[ "$SERVICE" == "ces" ]]; then
      for idx in "${!EM_WEB_DOMAIN[@]}"; do
        em="${EM_WEB_DOMAIN[$idx]}"
        nc="${NC_WEB_DOMAIN[$idx]}"
        echo "EM=$em | NC=$nc"
        for file in "${ces_files_list[@]}"; do
          echo "Searching $file"
          if EM_VAL="$em" NC_VAL="$nc" yq e '
          .siteinfo[]
          | select(
              (.web_emdomain[] == strenv(EM_VAL))
              and
              (.web_ncdomain[] == strenv(NC_VAL))
          )
          ' "$file" | grep -q .; then
            echo "Found in $file"
            remove_ces_siteinfo "$file" "$em" "$nc"
            break
          fi
        done  
      done
    fi

    if [[ "$SERVICE" == "twx" ]]; then
      for twx in "${TWX_WEB_DOMAIN[@]}"; do
        [[ -z "$twx" ]] && continue
        echo "TWX=$twx"
        found=false
        for file in "${twx_files_list[@]}"; do
          echo "Searching $file"
          if TWX_VAL="$twx" yq e '
          .siteinfo[]
          | select(
              (.web_twxdomain[] == strenv(TWX_VAL))
          )
          ' "$file" | grep -q .; then
            echo "Found in $file"
            remove_twx_siteinfo "$file" "$twx"
            found=true
            break
          fi
        done
      done
    fi
  ;;
  "Disable site")
    if [[ "$SERVICE" == "ces" ]]; then
      for idx in "${!EM_WEB_DOMAIN[@]}"; do
        em="${EM_WEB_DOMAIN[$idx]}"
        nc="${NC_WEB_DOMAIN[$idx]}"
        echo "EM=$em | NC=$nc"
        for file in "${ces_file_name[@]}"; do
          echo "Searching $file"
          if EM_VAL="$em" NC_VAL="$nc" yq e '
          .siteinfo[]
          | select(
              (.web_emdomain[] == strenv(EM_VAL))
              and
              (.web_ncdomain[] == strenv(NC_VAL))
          )
          ' "$file" | grep -q .; then
            echo "Found in $file"
            disable_ces_siteinfo "$file" "$em" "$nc"
            break
          fi
        done  
      done
    fi

    if [[ "$SERVICE" == "twx" ]]; then
      for twx in "${TWX_WEB_DOMAIN[@]}"; do
        [[ -z "$twx" ]] && continue
        echo "TWX=$twx"
        found=false
        for file in "${twx_files_list[@]}"; do
          echo "Searching $file"
          if TWX_VAL="$twx" yq e '
          .siteinfo[]
          | select(
              (.web_twxdomain[] == strenv(TWX_VAL))
          )
          ' "$file" | grep -q .; then
            echo "Found in $file"
            disable_twx_siteinfo "$file" "$twx"
            found=true
            break
          fi
        done
      done
    fi 
  ;;
  "Enable site")
    if [[ "$SERVICE" == "ces" ]]; then
      for idx in "${!EM_WEB_DOMAIN[@]}"; do
        em="${EM_WEB_DOMAIN[$idx]}"
        nc="${NC_WEB_DOMAIN[$idx]}"
        echo "EM=$em | NC=$nc"
        for file in "${ces_files_list[@]}"; do
          echo "Searching $file"
          if EM_VAL="$em" NC_VAL="$nc" yq e '
          .siteinfo[]
          | select(
              (.web_emdomain[] == strenv(EM_VAL))
              and
              (.web_ncdomain[] == strenv(NC_VAL))
          )
          ' "$file" | grep -q .; then
            echo "Found in $file"
            enable_ces_siteinfo "$file" "$em" "$nc"
            break
          fi
        done  
      done
    fi

    if [[ "$SERVICE" == "twx" ]]; then
      for twx in "${TWX_WEB_DOMAIN[@]}"; do
        [[ -z "$twx" ]] && continue
        echo "TWX=$twx"
        found=false
        for file in "${twx_files_list[@]}"; do
          echo "Searching $file"
          if TWX_VAL="$twx" yq e '
          .siteinfo[]
          | select(
              (.web_twxdomain[] == strenv(TWX_VAL))
          )
          ' "$file" | grep -q .; then
            echo "Found in $file"
            enable_twx_siteinfo "$file" "$twx"
            found=true
            break
          fi
        done
      done
    fi
  ;;
  esac
done

git diff
git add -A
git status

#COMMIT_MSG=$(build_commit_message "${COMMIT_PARTS[@]}")

git commit -m "$NEW_BRANCH"

#push_remote

git push -u origin "$NEW_BRANCH"

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

