#!/bin/bash
export $(grep -v '^#' .env | xargs)
cd bb-template
git push origin --delete origin $GIT_BRANCH_NAME
git branch -D $GIT_BRANCH_NAME
kind clusters delete bigbang
