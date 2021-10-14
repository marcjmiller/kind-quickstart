#!/bin/bash

function main {
  echo "Cleaning up..."

  if [ -f '.env' ]; then
    echo "Cleanup environment..."
    export $(grep -v '^#' .env | xargs)
  fi

  if [ -d 'bb-template' ]; then
    echo "Cleanup bb-template directory..."
    pushd bb-template
      git checkout main
      git push --delete origin $GIT_BRANCH_NAME
      git branch -D $GIT_BRANCH_NAME
    popd

    # remove bb-template directory
    rm -rf bb-template
  fi

  if [ ! -z $(kind get clusters 2> /dev/null | grep bigbang) ]; then
    echo "Deleting bigbang cluster"
    kind delete clusters bigbang
  fi

  export fp=`gpg --list-keys bigbang-sops 2> /dev/null | sed -e 's/ *//;2q;d;'`
  if [ ! -z "$fp" ]; then
    echo "Cleanup GPG keys..."
    gpg --batch --yes --delete-secret-keys $fp > /dev/null 2>&1
    gpg --batch --yes --delete-keys $fp > /dev/null 2>&1
    echo "Deleted bigbang-sops key"
  fi

  echo "All done!"
}

# silence pushd/popd default behaviors
function pushd {
  command pushd "$@" > /dev/null
}

function popd {
  command popd "$@" > /dev/null
}

main