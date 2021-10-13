#!/bin/bash
set -eux
# Setup ENV Variables
export $(grep -v '^#' .env | xargs)

# Start Kind Cluster
kind create cluster --name bigbang --config bigbang.yaml

# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.10.3/manifests/metallb.yaml

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

# Clone BB customer template
git clone $BB_TEMPLATE_REPO
cd bb-template
# git checkout all-apps
git checkout -b $GIT_BRANCH_NAME

# Generate GPG if not present
if [ -z ${fp+x} ]
then
  gpg --batch --gen-key ../gpg-key.cfg
  export fp=`gpg --list-keys | sed -e 's/ *//;4q;d;'`

  echo '' | gpg --pinentry-mode loopback --batch --no-tty --yes --passphrase-fd 0 --quick-add-key $fp rsa4096 encr
  gpg --quick-set-expire $fp 14d
fi

# Set fingerprint in .sops.yaml to encrypt files
sed -i "s/pgp: FALSE_KEY_HERE/pgp: $fp/" .sops.yaml

git add .sops.yaml
git commit -m "chore: update default encryption key"

# Setup cluster secrets to commit
cd base

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

# Configure GitOps w/ flux
cd ../dev/

sed -i "s,https://replace-with-your-git-repo.git,$BB_TEMPLATE_REPO,g" bigbang.yaml

sed -i "s/replace-with-your-branch/$GIT_BRANCH_NAME/g" bigbang.yaml

git add bigbang.yaml
git commit -m "chore: update git repo"

# Push all configuration to your branch

git push -u origin $GIT_BRANCH_NAME

# Install bigbang
kubectl create namespace bigbang

gpg --export-secret-key --armor $fp | kubectl create secret generic sops-gpg --from-file=bigbangkey.asc=/dev/stdin -n bigbang

kubectl create namespace flux-system

kubectl create secret docker-registry private-registry --docker-server=registry1.dso.mil --docker-username=$REGISTRY1_USERNAME --docker-password=$REGISTRY1_CLI_SECRET -n flux-system

kubectl create secret generic private-git --from-literal=username=$GIT_USERNAME --from-literal=password=$GIT_ACCESS_TOKEN -n bigbang

kustomize build https://repo1.dso.mil/platform-one/big-bang/bigbang.git//base/flux?ref=1.12.0 | kubectl apply -f -

kubectl get deploy -o name -n flux-system | xargs -n1 -t kubectl rollout status -n flux-system

kubectl apply -f bigbang.yaml

watch kubectl get kustomizations,hr,po -A
