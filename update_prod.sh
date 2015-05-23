#!/bin/bash
# this is necessary because we use plugins not support by GitHub Pages

set -e

origin="origin"
master="master"
pages="gh-pages"
develop="develop"
self=`basename $0`
tmpl=`git log | head -n1 | cut -d" " -f2`
tmpd="/tmp/$tmpl"

echo "---> Updating gh-pages with master generated content"
ldir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $ldir

echo "---> Fetching $origin"
git fetch $origin

echo "---> Changing to $master"
git checkout -B $master $origin/$master

echo "---> Merge changes from $develop branch into $master"
git merge -m "merging from $origin/$develop on `date`" $origin/$develop

echo "---> Building from latest master to $tmpd"
jekyll build -d $tmpd

echo "---> Changing to $pages branch"
git checkout -B $pages $origin/$pages

echo "---> Removing existing content from $pages branch"
git rm -qr .

echo "---> Copying new content into $pages branch"
cp -r $tmpd/. .

echo "---> Cleaning up unneeded files"
rm ./$self
rm -r $tmpd

echo "---> Publishing to $pages branch"
git add -A
git commit -m "publishing updates to $pages on `date`"
git push origin $pages

echo "---> Changing back to $master branch"
git checkout $master

echo "---> Pushing $master branch to $origin"
git push $origin $master

echo "---> Update complete"

exit 0
