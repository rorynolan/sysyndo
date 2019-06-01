#!/bin/bash

Rscript -e "bookdown::render_book('report.Rmd')"
git remote add origin https://${GITHUB_PAT}@github.com/rorynolan/sysyndo.git
git commit -m "Daily auto build of report.md."
git push origin master
