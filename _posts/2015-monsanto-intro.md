---
layout: post
title: "This is a new post"
subtitle: "This is the optional subtitle line"
header-img: "img/mon-field_rows.jpg"
#header-img: "img/mon-monmouth.jpg"
category: code
tags: [open source, introduction, overview]
---

At Monsanto, we are engineers: in our history we’ve engineered [molecules](https://en.wikipedia.org/wiki/Light-emitting_diode#Initial_commercial_development), [materials](https://en.wikipedia.org/wiki/AstroTurf), and [medicines](https://en.wikipedia.org/wiki/L-DOPA). Now as a purely agricultural company, we not only engineer plants, but the systems that develop, manufacture, monitor and deploy them.

Monsanto might not be the first company that springs to mind when you think of cutting-edge software engineering. We’re a bit different: instead of being highly focused on a narrow segment of IT like social media analytics, Monsanto is all about diversity (and [not just this kind](http://news.monsanto.com/press-release/corporate/monsanto-open-all-company-signs-human-rights-campaign-equality-pledge)). In the coming posts, we will share our experiences and code for dealing with a multitude of topics. We have several image analysis and computer vision teams, on projects like our robotic automated greenhouse (FIXME embed this [video](https://www.youtube.com/watch?v=nyAP1xmgur0)). We develop both the hardware and software to acquire [hyper-spectral](http://en.wikipedia.org/wiki/Hyperspectral_imaging) images both in controlled environments as well as in the field.

We have also have several computational biology teams, who mine petabytes of DNA sequence data for plants, microbes and insects. Thousand-core distributed analytics pipelines have been the norm here for a decade. Crossing over between research and manufacturing, we have a [globally distributed cloud-based Internet of Things (IoT) platform](http://www.fool.com/investing/general/2014/12/06/monsanto-might-be-best-internet-of-things-stock.aspx) to collect and analyze realtime planting, harvesting, and logistics data from a multitude of sensors, some of which we’ve built on top of RasPi, Arduino, and custom PCBs. On the commercial side, our IFS team has built a [predictive analytical model and cloud platform](http://www.monsanto.com/investors/documents/whistle%20stop%20tour%20vi%20-%20aug%202012/wst-ifs_posters.pdf) that combined with hundreds of data points per second from our [precision planters](http://www.precisionplanting.com/#/) optimizes yield using only software.

Monsanto is a large company, but we’ve aggressively pursued cutting-edge technology. In addition to the requisite relational and Oracle based applications, we’ve also running a variety of NoSQL in production. Since 2010, we’ve developed applications on top of Hadoop and CouchDB (and we’ve released a monadic Couch DB connector, [Stoop](https://github.com/monsantoco/stoop)). At an upcoming talk we’ll be showcasing one of our [Neo4J production applications](http://stampedecon.com/sessions/managing-genetic-ancestry-at-scale-with-neo4j-and-kafka/). We’re also using Riak, Rabbit, Kafka, and Cassandra in major production applications, in addition to our own multidimensional array database [Mandolin](https://github.com/TheClimateCorporation/mandoline).

While Java makes up the core of our applications at Monsanto, and we have pockets of Clojure, Python, R, Perl, .Net and other languages, Scala is now the standard back-end language at Monsanto. Most if not all of our new development is occurring in Scala. In our first few posts, we are excited to highlight and release our code for rapidly developing microservices applications on Scala/Docker/AWS. An upcoming post will introduce and release our synthetic “type system” we implemented on top of AWS CloudFormation in the Scala type system. Having used Scala at Monsanto since 2010, we can’t wait to share not only our libraries but other explorations in monads, type-level programming, and general type-foolery of the form (type members and refinements FTW!):

```
// TODO: Also add QueryParams object / type
case class GET[
                PathParameters,
                P <: Path{type Params = PathParameters},
                Body <: CanonicalModel[Body],
                PathMapperOut,
                R](
                    path:        P{type Params = PathParameters},
                    pathFactory: PathMapper[PathMapperOut, PathParameters],
                    bodyFactory: CanonicalModelFactory[Body]
                  )
                  (f: (PathMapperOut, Body) => R){

  def run(url: String, item: Body): Option[R] = path.parse(url).map(bits => f( pathFactory.tupled(bits), item))
}
```

IT at Monsanto is characterized by its amazing diversity. With modern tools, we are tackling exciting problems in domains as diverse as genomics and computer vision. Now we are opening up these tools and experiences to the community. We hope you’ll join us back here for our next post on automation in AWS.
