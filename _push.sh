#!/bin/bash


setup_git() {
  git config --global user.email "rorynolan@gmail.com"
  git config --global user.name "Rory Nolan"
}

commit_files() {
  git add -u
  git commit -m "Daily auto build of report.md. Travis build: ${TRAVIS_BUILD_NUMBER}."
}

upload_files() {
  git remote set-url origin https://${GITHUB_PAT}@github.com/rorynolan/sysyndo.git
  git push --set-upstream origin master
}

echo "Status: "
git status
echo "Setup: "
setup_git
echo "Commit: "
commit_files
echo "Upload: "
upload_files
echo "Status: "
git status