---
layout: post
title: "Stoop: our first open source release"
subtitle: "A Scala DSL for interfacing with CouchDB"
header-img: "img/mon-field_rows.jpg"
authors: 
    -
        name: Phil Cryer
        githubProfile : "philcryer"
        twitterHandle : "fak3r"
        avatarUrl : "https://avatars0.githubusercontent.com/u/43070?v=3"
tags: [open source, scala, couchdb]
---

We are happy to annouce the release of our first open source software, [Stoop](https://github.com/MonsantoCo/stoop). Based on an existing [Haskell library](http://hackage.haskell.org/package/CouchDB), Stoop is a Scala DSL for interfacing with CouchDB. Implementation can be easily switched between talking to an actual Couch or a fake (mock) one for testing. We've released this under the Modified BSD License, so check it out and let us know if you have any questions, if you find bugs, or even if you have a [pull request](https://github.com/MonsantoCo/stoop/pulls) to fix something!

{% highlight scala %}
    name := "Stoop"
    version := "0.9.10-SNAPSHOT"
    scalaVersion := "2.10.3"
    scalacOptions += "-deprecation"
    scalacOptions += "-feature"
    resolvers += "Sonatype snapshots" at "http://oss.sonatype.org/content/repositories/snapshots/"
    resolvers += "Scalaz Bintray Repo" at "http://dl.bintray.com/scalaz/releases"
    resolvers += "spray repo" at "http://repo.spray.io"
    libraryDependencies ++= Seq("org.scalaz" %% "scalaz-core" % "7.1.0",
        "io.spray" %% "spray-json" % "1.2.5",
        "org.scalaz" %% "scalaz-effect" % "7.1.0",
        "org.scalaz" %% "scalaz-concurrent" % "7.1.0",
        "org.scalaz.stream" %% "scalaz-stream" % "0.6a")
    libraryDependencies += "net.databinder.dispatch" %% "dispatch-core" % "0.10.0"
    libraryDependencies += "org.scalatest" % "scalatest_2.10" % "2.0" % "test"
    libraryDependencies += "org.scalacheck" %% "scalacheck" % "1.10.1" % "test"
    publishMavenStyle := true
{% endhighlight %}
