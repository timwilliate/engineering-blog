# engineering-blog

## Function

This is the engineering blog of Monsanto engineers, where we’ll share ideas we have, open source software we use and have created. Watch this space for future articles.

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

Copy one of the exsting pages, for example `about.html` and make some changes

```
cp about.html new_page.html
vi new_page.html
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

* Push to production

Once the editing is done and the post have been approved, push the existing code to `production`, by pushing it to the `gh-pages` branch.

First add and commit, if you haven't already
```
git add .
git commit -m "updates added `date`"
```

Then do the actual push

```
git push origin gh-pages
```

(NOTE: we have a script `promote_to_prod.sh` that automates these steps)

## Questions?

Feel free to reach out on our [Contact page](http://ec2-54-174-166-239.compute-1.amazonaws.com/contact/) or open an [issue](https://github.com/MonsantoCo/engineering-blog/issues) for us to fix. As always, [pull requests](https://github.com/MonsantoCo/engineering-blog/pulls) welcome!


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
