#!/bin/bash
# this is necessary because we use plugins not supported by GitHub Pages

set -e

origin="origin"
master="master"
pages="gh-pages"
develop="develop"
self=`basename $0`
: ${TMPDIR:=/tmp}
tmp_repo=$(mktemp -d -t $self)
tmp_site=$(mktemp -d -t $self-site)

echo "---> Updating gh-pages with master generated content"
ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$ldir"

echo "---> Determining remote url for $origin"
remote=$(git remote --verbose | awk "/^$origin/ { print \$2; exit 0 }")

echo "---> Fetching $origin"
git fetch "$origin"

echo "---> Changing to $master"
git checkout -B "$master" "$origin/$master"

echo "---> Merge changes from $develop branch into $master"
git merge -m "merging from $origin/$develop on `date`" $origin/$develop

echo "---> Getting commit SHA"
gitsha=$(git log | head -n1 | cut -d" " -f2)

echo "---> Building site from latest $master to $tmp_site"
jekyll build -d "$tmp_site"

echo "---> Cloning repo $remote to $tmp_repo"
git clone "$remote" "$tmp_repo"

echo "---> Changing to $tmp_repo"
cd "$tmp_repo"

echo "---> Changing to $pages branch"
git checkout "$pages"

echo "---> Removing content from $pages branch"
git symbolic-ref HEAD refs/heads/gh-pages
rm .git/index
git clean -fdx

echo "---> Copying new content into $pages branch"
cp -r $tmp_site/. .
touch .nojekyll

echo "---> Cleaning up jekyll build directory: $tmp_site"
rm -rf $tmp_site

echo "---> Publishing to $pages branch"
git add -A
git commit -m "publishing $master $gitsha build to $pages on `date`"
git push "$origin" "$pages"

echo "---> Changing back to original repo clone"
cd "$ldir"

echo "---> Cleaning up temp repo: $tmp_repo"
rm -rf "$tmp_repo"

echo "---> Changing back to $master branch"
git checkout "$master"

echo "---> Pushing $master branch to $origin"
git push "$origin" "$master"

echo "---> Switching back to $develop branch"
git checkout "$develop"

echo "---> Update complete"

exit 0
