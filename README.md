# engineering-blog

## Function

This is the engineering blog of Monsanto engineers, where we’ll share ideas we have, open source software we use and have created. Watch this space for future articles.

## New Posts

To contribute a new post, Monsanto engineers should check out the `engineering-blog` repo, create a branch, create your new post in the `_posts` directory, check it in, create a new [pull request](https://github.com/MonsantoCo/engineering-blog/pulls), calling out your new branch. After submitted it will go through the approval process. Thanks

## Usage and development

* Our engineering blog is built by [Jekyll](http://jekyllrb.com/), so to work on it first install Jekyll. *If* you already have [Ruby](https://www.ruby-lang.org/) and [RubyGems](https://rubygems.org/) installed, this could be as easy as

```
gem install jekyll
```

If you need to install those first, check out the install documentation for [Ruby](http://jekyllrb.com/docs/installation/) and [RubyGems](https://rubygems.org/pages/download)

* Next, checkout the site code

```
git clone https://github.com/MonsantoCo/engineering-blog
```

* Change into the downloaded repo

```
cd engineering-blog
```

* Create a new page

If you're starting with html copy one of the exsting pages, for example `about.html` and make some changes

```
cp about.html new_page.html
vi new_page.html
```

If you're starting with markdown copy an existing page from the _posts directory and make some changes
```
cp _posts/2015-07-08-stax.md _posts/xxxx-xx-xx-newpost.md
vi _posts/xxxx-xx-xx-newpost.md
```

Be sure to update the 'frontmatter', that's the code between the `---` marks. Their functions are self-explanitory. After that build the site with Jekyll (see below) to see how it looks.

* Create a new post

Copy one of the exsting posts, and make some changes

```
cp _posts/2015-01-22-stoop-our-first-open-source-release.md _posts/2015-04-01-this-is-a-new-post.md
vi _posts/2015-04-01-this-is-a-new-post.md
```

Again, be sure to update the 'frontmatter', that's the code between the `---` marks. Their functions are self-explanitory. After that build the site with Jekyll (see below) to see how it looks.

* Build the site with Jekyll

```
jekyll build
```

This will build the site and put all files needed into the `_site` directory. At this point you can open the index file in a browser and view the site in a browser. In your browser just choose `File` > `Open file...` and point to the file _site/index.html

Or if you want to view the site running in jekyll with full css/image rendering simply run _jekyll s_ on the command line to start the jekyll server locally and point your browser to localhost:4000

* If you want to develop the site, you can edit it and have it automatically rebuild when it senses changes to any of the files

```
jekyll build --watch
```

* Once you are done editing, add, commit and push the changes to GitHub

```
git add .
git commit -m "This is what I did to the code"
git push (git fetch; git rebase)
```

## Push to production

**NOTE** we have a script `update_prod.sh` that automates all of these steps

Once the editing is done and the post have been approved, push the existing code to `production`, by pushing it to the `gh-pages` branch.

First add and commit, if you haven't already
```
git add .
git commit -m "updates added `date`"
```

Building the site from master branch to a temp diretory

```
git checkout master
jekyll build -d /tmp/new
``

Change to the gh-pages branch

```
git checkout gh-pages
```

Clear the current content from the gh-pages branch, then copy the new content into gh-pages branch

```
git rm -qr .
cp -r /tmp/new/. .
```

Cleaning up unneeded files

```
rm -r /tmp/new
```

Add/Commit/Push the new files to gh-pages branch

```
git add -A
git commit -m "Published updates on `date`"
git push origin gh-pages
```

Change back to the master branch

```
git checkout $SOURCE_BRANCH
```

Then do the actual push

```
git push origin gh-pages
```

Reload the site in a browser and enjoy!

**NOTE** we have a script `update_prod.sh` that automates all of these steps

## Questions?

Feel free to reach out on our [Contact page](http://engineering.monsanto.com/contact/) or open an [issue](https://github.com/MonsantoCo/engineering-blog/issues) for us to fix. As always, [pull requests](https://github.com/MonsantoCo/engineering-blog/pulls) are welcome!


## License

Copyright (c) 2015, MonsantoCo
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of engineering-blog nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

### Thanks
