#!/bin/bash

echo "---> Updating gh-pages with master generated content"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

SELF=`basename $0`
SOURCE_BRANCH="master"
DEST_BRANCH="gh-pages"
TMP_LOG=`git log | head -n1 | cut -d" " -f2`
TMP_DIR="tmp-$TMP_LOG"

git checkout $SOURCE_BRANCH
jekyll build -d $TMP_DIR
git checkout $DEST_BRANCH
git rm -qr .
cp -r $TMP_DIR/. .
rm ./$SELF
rm -r $TMP_DIR
git add -A
git commit -m "Published updates on `date`"
git push origin $DEST_BRANCH
git checkout $SOURCE_BRANCH
echo "---> Update complete"

exit 0
