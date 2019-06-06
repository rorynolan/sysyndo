#!/bin/bash

echo "Checkout master: "
git checkout master

Rscript -e "knitr::knit('report.Rmd')"
