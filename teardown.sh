#!/bin/bash
export $(grep -v '^#' .env | xargs)
cd bb-template
git checkout main
git push --delete origin $GIT_BRANCH_NAME
git branch -D $GIT_BRANCH_NAME
kind delete clusters bigbang
cd ..; rm -rf bb-template
rm -rf ~/.gnupg