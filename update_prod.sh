#!/bin/bash

set -e

# variables you can change
SRCE_BRANCH="master"
DEST_BRANCH="gh-pages"
DEVL_BRANCH="develop"

echo "---> Updating gh-pages with master generated content"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

SELF=`basename $0`
TEMP_LOG=`git log | head -n1 | cut -d" " -f2`
TEMP_DIR="/tmp/$TEMP_LOG"

echo "---> Changing to $SRCE_BRANCH"
git checkout $SRCE_BRANCH

echo "---> Merging changes from $DEVL_BRANCH branch"
git pull; git merge $DEVL_BRANCH

echo "---> Building from latest master to $TEMP_DIR"
jekyll build -d $TEMP_DIR

echo "---> Changing to $DEST_BRANCH branch"
git checkout $DEST_BRANCH

echo "---> Syncing $DEST_BRANCH  branch with any remote changes"
git pull

echo "---> Removing existing content from $DEST_BRANCH branch"
git rm -qr .

echo "---> Copying new content into $DEST_BRANCH branch"
cp -r $TEMP_DIR/. .

echo "---> Cleaning up unneeded files"
rm ./$SELF
rm -r $TEMP_DIR

echo "---> Publishing to $DEST_BRANCH branch"
git add -A
git commit -m "Published updates on `date`"
git push origin $DEST_BRANCH

echo "---> Changing back to $SRCE_BRANCH branch"
git checkout $SRCE_BRANCH

echo "---> Update complete"

exit 0
