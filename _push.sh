#!/bin/bash

setup_git() {
  git config --global user.email "travis@travis-ci.org"
  git config --global user.name "Travis CI"
}

commit_files() {
  git add -u
  git commit -m "Daily auto build of report.md. Travis build: ${TRAVIS_BUILD_NUMBER}."
}

upload_files() {
  git remote add origin https://${GITHUB_PAT}@github.com/rorynolan/sysyndo.git > /dev/null 2>&1
  git push --set-upstream origin master
}

echo "Setup: "
setup_git
echo "Commit: "
commit_files
echo "Upload: "
upload_files