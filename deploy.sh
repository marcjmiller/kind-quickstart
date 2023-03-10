#!/bin/bash

set -e

WAITING_ON_BIGBANG=0

function main {
  case "${1}" in
    -v|--verbose)
      set -ux
      echo "Start deploy bigbang in verbose mode"
    ;;
    *)
      set -u
      echo "Start deploy bigbang in less-verbose mode"
    ;;
  esac

  setup
  create_cluster
  apply_bb_templates
  configure_secrets
  configure_gitops
  install_bigbang
}

function create_cluster {
  kind create cluster --name bigbang --config bigbang.yaml
  kubectl create namespace bigbang

  # Install MetalLB
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

  # Grab Network used by kind and put it into the ConfigMap for metallb
  network=$(docker network inspect kind -f "{{(index .IPAM.Config 0).Subnet}}" | cut -d '.' -f1,2)
  cat <<EOF | kubectl apply -f -
  apiVersion: v1
  kind: ConfigMap
  metadata:
    namespace: metallb-system
    name: config
  data:
    config: |
      address-pools:
      - name: default
        protocol: layer2
        addresses:
        - $network.0.2-$network.0.3
EOF
}

function apply_bb_templates {
  git clone --branch main $BB_TEMPLATE_REPO
  pushd bb-template

  # git checkout all-apps
  git checkout -b $GIT_BRANCH_NAME
}

function configure_secrets {
  if [ -z ${fp+x} ]
  then
    gpg --batch --gen-key ../gpg-key.cfg
    export fp=`gpg --list-keys bigbang-sops | sed -e 's/ *//;2q;d;'`

    echo '' | gpg --pinentry-mode loopback --batch --no-tty --yes --passphrase-fd 0 --quick-add-key $fp rsa4096 encr
    gpg --quick-set-expire $fp 14d
  fi

  # Set fingerprint in .sops.yaml to encrypt files
  sed -i "s/pgp: FALSE_KEY_HERE/pgp: $fp/" .sops.yaml

  git add .sops.yaml
  git commit -m "chore: update default encryption key"

  # Setup cluster secrets to commit
  pushd base
    sops -e bigbang-dev-cert.yaml > secrets.enc.yaml

    git add secrets.enc.yaml
    git commit -m "chore: add bigbang.dev tls certificates"

    # Decrypt SOPS file to add in Registry One secrets
    sops -d secrets.enc.yaml > secrets.yaml
    sed -i "/values.yaml: |-/a \ \ \ \ \ \ \ \ registryCredentials:\n \ \ \ \ \ \ \ - registry: registry1.dso.mil\n \ \ \ \ \ \ \ \ \ username: $REGISTRY1_USERNAME\n \ \ \ \ \ \ \ \ \ password: $REGISTRY1_CLI_SECRET" secrets.yaml
    sops -e secrets.yaml > secrets.enc.yaml

    rm -f secrets.yaml

    git add secrets.enc.yaml
    git commit -m "chore: adds iron bank pull credentials"
  popd

  gpg --export-secret-key --armor $fp | kubectl create secret generic sops-gpg --from-file=bigbangkey.asc=/dev/stdin -n bigbang

  kubectl create secret generic private-git --from-literal=username=$GIT_USERNAME --from-literal=password=$GIT_ACCESS_TOKEN -n bigbang
}

function configure_gitops {
  pushd dev

  sed -i "s,https://replace-with-your-git-repo.git,$BB_TEMPLATE_REPO,g" bigbang.yaml

  sed -i "s/replace-with-your-branch/$GIT_BRANCH_NAME/g" bigbang.yaml

  git add bigbang.yaml
  git commit -m "chore: update git repo"

  # Push all configuration to your branch
  git push -u origin $GIT_BRANCH_NAME

  kubectl create namespace flux-system

  kubectl create secret docker-registry private-registry --docker-server=registry1.dso.mil --docker-username=$REGISTRY1_USERNAME --docker-password=$REGISTRY1_CLI_SECRET -n flux-system
  kubectl apply -k https://repo1.dso.mil/platform-one/big-bang/bigbang.git//base/flux?ref=1.53.0

  kubectl get deploy -o name -n flux-system | xargs -n1 -t kubectl rollout status -n flux-system
}

function install_bigbang {
  kubectl apply -f bigbang.yaml

  WAITING_ON_BIGBANG=1
  watch kubectl get kustomizations,hr,po -A
}

function setup {
  preflight_check
  load_env_vars
}

function load_env_vars {
  ENV_FILE=./.env
  if [ -f $ENV_FILE ]; then
    export $(grep -v '^#' .env | xargs)
  fi

  env_vars=( REGISTRY1_USERNAME REGISTRY1_CLI_SECRET GIT_USERNAME GIT_ACCESS_TOKEN GIT_BRANCH_NAME BB_TEMPLATE_REPO )

  for var in "${env_vars[@]}"; do
    if [ -z $(printenv | grep $var) ]; then
      echo "Load env vars failed"
      echo "ERROR: $var not set, please review README.md"
      exit 1
    fi
  done
}

function preflight_check {
  pre_reqs=( kubectl kind kustomize docker git gpg sops )

  for cmd in "${pre_reqs[@]}"; do
    if [ ! $(command -v $cmd) ]; then
      echo "Preflight checks failed"
      echo "ERROR: $cmd not found, please install"
      exit 1
    fi
  done
}

# On non-zero exit codes, cleanup after ourselves
trap cleanup EXIT
function cleanup {
  if [ "$?" != "0" ]; then
    echo -e "\nSomething broke, executing teardown..."
    source teardown.sh
  fi
}

# On ctrl-c exit, let the user know how to cleanup since it
trap ctrlc 2
function ctrlc {
  echo -e "\nCaught ctrl-c"

  if [ "$WAITING_ON_BIGBANG" -eq "1" ]; then
    echo -e "\nUse ./teardown.sh to cleanup your bigbang, or it will happen automatically on non-zero exit codes."
    exit 0
  else
    exit 1
  fi
}

# silence pushd/popd default behaviors
function pushd {
  command pushd "$@" > /dev/null
}

function popd {
  command popd "$@" > /dev/null
}

main ${@}
