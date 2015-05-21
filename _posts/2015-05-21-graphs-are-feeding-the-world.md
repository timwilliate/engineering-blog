---
layout: post
title: "Graphs are Eating - and Feeding - the World"
subtitle: "Scaling Genetic Ancestry tracking with Graph Databases"
header-img: "img/mon-chesterfield.jpg"
author: "Jason Clark"
tags: [big data, nosql, genomics]
---

Monsanto's Global Research and Development pipeline has long leveraged internally built software solutions to track seed material as it progresses through the research phase and into commercialization as a product in Monsanto's portfolio.  Prior to the age of NoSQL and polyglot persistence these systems heavily relied on storing a majority of the data in a RDBMS like Oracle.  For years, these systems did a tremendous job of supporting the R&D pipeline and allowing for easy(-ish) analysis of data for the agronomists and bench scientists that work daily to fulfill our company's vision of producing more with less, allowing our business counterparts to focus on the science as opposed to having to worry about every little bit of information and where it is "saved" at.  

As we continue to move into a world where agriculture relies heavily on [Big Data](http://engineering.monsanto.com/2015/05/20/using-big-data-for-good/) and the [Internet of Things](https://twitter.com/monsantoiot/status/497043884632211458), it's important for our systems to evolve and scale properly.  With the NoSQL technologies that are available today, "scaling" doesn't always mean throwing Map/Reduce or a large amount of compute resources at a problem.  In what began over a lunch conversation, a few engineers here set out to re-think the solution to managing one of our core datasets and wound up with a solution that scales thanks to applying the right storage solution and mathematical theory for a data set, rather than simply paying for more compute power.

Building software to track our R&D pipeline means that you need to track millions of new plant populations each year that are created by conventional pollination procedures across all of our global plant breeding sites.  For isolated analysis of a given seed packet a RDBMS is a perfectly scalable solution.  As an example, let's say we want to track a new seed packet produced by harvesting a Corn plant.  We can start with a simple relational database table that tracks a seed and its two parents:

| **Packet_Name** | **Parent_1** | **Parent_2** |
| -------------------| ----------- | ------------ |
|  Packet 3        |  Packet 1 | Packet 2 |
	
What if we want to take a single seed packet and know the two seed packets that were crossed to produce it?  No problem…that's easy enough in SQL:

```
	SELECT parent_1, parent_2 FROM seed_packet WHERE packet_name = 'Packet 3';
```

We can run that query against our relational database and in the matter of milliseconds we'll have packet 1 and packet 2 returned as our parents.  Let's start to introduce some complexity into our use case.  One simple case that our system would need to handle is the case of self pollination, where the pollen from a plant is placed onto the silks of the same plant to produce something that is genetically inbred in an effort to conserve important genetic traits.  We could make our parent_2 column nullable, but we're already starting to pollute our model a bit.  However, the pollution of the model isn't the straw that breaks the relational database's back.  What if we wanted to get information about seed packet 3's grandparents, or even it's great-great-great grandparents?  Not only is our SQL query going to grow in complexity, but we are eventually going to suffer from the lack of [index-free adjacency](http://neo4j.com/blog/demining-the-join-bomb-with-graph-queries/) due to the way our Relational Database works.  Stack 25+ years of genetic ancestry data tracking on top of our simple example above and we'll have quite an issue with that recursive SQL query.  As a few of us sat around at lunch in the cafe a few years ago, we invoked our mathematics and computer science backgrounds and talked about how our Ancestry data closely resembles a graph structure.

After lunch, we scurried to the whiteboard in an abandon conference room and scribbled out a few examples of what our ancestry graph could look like.  Though we were representing it in table form, drawing the example when discussing business use cases always resulted in something similar to the following:

<div style="text-align:center"><img src ="/img/binary-cross.png" /></div>
*Imagine this same pattern, with slight variations, repeated 2-3 times a year over the course of 25 years.*

At the first R&D IT innovation day we spent some time proving out our idea.  We unloaded a fair amount of data from our relational database and loaded that into a [Neo4j Community](http://www.neo4j.com) instance running on a laptop.  Within 4 hours we had our first use case, which was considerably more complex than the example above, climbing a moderately complex lineage and returning results that took several minutes to retrieve from our relational database.  

After demonstrating our Innovation Day project at the demo day and going on a bit of a "road show" to talk about our solution, our leadership in IT helped us to dedicate our time during the workday to building our Genetic Ancestry graph out into a full fledged, production grade product that could be used across both IT and our business customers to allow for exceptional performance and open doors to new ancestral analysis.

As we worked to build out the full product, we continued to identify increasingly more complex patterns in our data that represented important plant breeding features in a Genetic Ancestry.  There is a common technique in plant breeding called [backcross breeding](http://passel.unl.edu/pages/informationmodule.php?idinformationmodule=959009357&topicorder=3&maxto=9) that presents a slightly more complex pattern in a seed's ancestry.

<div style="text-align:center"><img src ="/img/backcross-pattern.png" /></div>

Using the graph database, we were able to leave the data in it's raw graph form shown above and still codify a graph algorithm that could identify the individual seeds in a given lineage that were part of a backcrossing operation.

### Shameless Plug
If you are interested in hearing more about how we leverage graph databases and graph theory to manage Genetic Ancestry at Monsanto, please come see us and check out our [talk](http://stampedecon.com/sessions/managing-genetic-ancestry-at-scale-with-neo4j-and-kafka/) at [StampedeCon](http://stampedecon.com/) conference in St. Louis, MO this coming July!

### Want more?
If you'd like to learn more on our focus on traditional plant breeding, head over to our [Discover](http://www.monsanto.com/improvingagriculture/pages/modern-breeding-techniques.aspx) site.
