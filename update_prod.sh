#!/bin/bash

set -e

echo "---> Updating gh-pages with master generated content"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

SELF=`basename $0`
SOURCE_BRANCH="master"
DEST_BRANCH="gh-pages"
TMP_LOG=`git log | head -n1 | cut -d" " -f2`
TMP_DIR="/tmp/$TMP_LOG"

echo "---> Changing to master branch"
git checkout $SOURCE_BRANCH

echo "---> Building from master branch to $TMP_DIR"
jekyll build -d $TMP_DIR

echo "---> Changing to gh-pages branch"
git checkout $DEST_BRANCH

echo "---> Syncing branch with any remote changes"
git pull

echo "---> Removing existing content from gh-pages branch"
#git rm -qr .

echo "---> Copying new content into gh-pages branch"
cp -r $TMP_DIR/. .

echo "---> Cleaning up unneeded files"
rm ./$SELF
rm -r $TMP_DIR

echo "---> Publishing to gh-pages branch"
git add -A
git commit -m "Published updates on `date`"
git push origin $DEST_BRANCH

echo "---> Changing to master branch"
git checkout $SOURCE_BRANCH

echo "---> Update complete"

exit 0
