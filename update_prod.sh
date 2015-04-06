#!/bin/bash

git checkout gh-pages
git rebase master
git push
git checkout master

exit 0
