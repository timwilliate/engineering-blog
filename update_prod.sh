#!/bin/bash

set -e

srce="master"
dest="gh-pages"
devl="develop"
self=`basename $0`
tmpl=`git log | head -n1 | cut -d" " -f2`
tmpd="/tmp/$tmpl"

echo "---> Updating gh-pages with master generated content"
ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $ldir

echo "---> Changing to $srce"
git checkout $srce

echo "---> Merging changes from $devl branch"
git pull; git merge -m "merging from $devl on `date`" $devl

echo "---> Building from latest master to $tmpd"
jekyll build -d $tmpd

echo "---> Changing to $dest branch"
git checkout $dest

echo "---> Syncing $dest  branch with any remote changes"
git pull

echo "---> Removing existing content from $dest branch"
git rm -qr .

echo "---> Copying new content into $dest branch"
cp -r $tmpd/. .

echo "---> Cleaning up unneeded files"
rm ./$self
rm -r $tmpd

echo "---> Publishing to $dest branch"
git add -A
git commit -m "publishing updates to $dest on `date`"
git push origin $dest

echo "---> Changing back to $srce branch"
git checkout $srce

echo "---> Update complete"

exit 0
