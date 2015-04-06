#!/bin/bash

if [ ! -d '_site' ]; then
    echo "ERROR cannot find dist directory _site, run jekyll build to create it"
    exit 1
git push origin `git subtree split --prefix _site master`:gh-pages --force

exit 0


another possible method

git checkout gh-pages
git rebase master
git push
git checkout master

exit 0
