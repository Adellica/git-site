  [CHICKEN]: http://call-cc.org/
  
# git-site

Serve your static website content directly from a git repository on
disk. The repository's contents will be available as regular URL's,
with the first part of the URL-path being a branch/tag.

The files are read directly from the git repository, no working directory
or temporary files are used.

## Usage

```
$ cd projects/my-website
$ ls
index.html index.js index.css
$ git tag
master
v1.x
v2.x
bleeding
$ git-site ./ 8080 &
$ curl localhost:8080/master/index.js
$ curl localhost:8080/v1.x/index.css
$ # or point your browser to localhost:8080 and see all versions
```

### Production usage example

```
$ git clone --bare "http://github.com/company/project.git"
$ git config remote.origin.fetch 'refs/heads/*:refs/heads/*' # important for git fetch to update branch refs
$ git-site project.git 8080
$ curl localhost:8080/master/file.txt # get latest version
$ curl localhost:8080/_fetch # fetch remote
$ curl localhost:8080/master/file.txt # get latest version again
```

The special url `_fetch` will issue a `git fetch --all` in project.git
directory. It can be used as a
[github webhook](https://developer.github.com/webhooks/), for example.

## Installation

This is a [CHICKEN]-egg. Install like this:

```
$ sudo apt-get install chicken-bit # or chicken or something similar
$ git clone <this-repo> && cd <this-repo>
$ chicken-install -s
```

