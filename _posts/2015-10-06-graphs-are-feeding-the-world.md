---
layout: post
title: "Graphs are Feeding the World"
subtitle: "INSERT"
description: "INSERT"
header-img: "img/graph-lineDescendants.jpg"
authors:
    -
        name: "Tim Williamson"
        githubProfile : "timwilliate"
        twitterHandle : "TimWilliate"
        avatarUrl : "https://avatars1.githubusercontent.com/u/7853157?v=3"
tags: [genomics, graph, architecture, neo4j, graphconnect]
---

Humanity faces complex challenges as it adapts to the impacts of a global population projected to eclipse [9.5 billion by 2050](http://esa.un.org/unpd/wpp/). In addition to requiring a greater amount of food, a population of this magnitude stresses global agriculture production by expanding the urban footprint at the expense of arable land. In the world's developing nations, the growing middle class is frequently choosing to adopt sources of animal protein, which is more resource intensive to produce, as a larger portion of their diets. This all adds up to the realization that humanity will be required to grow more food than it ever has before, while using fewer resources to do so.

Humanity has several tools which will be leveraged to address the issue of feeding the world, and with one tool in particular, improving genetics of staple crops, we have several millenia of experience. [~10,000 years ago](http://learn.genetics.utah.edu/content/selection/corn/) ancient farmers began the process of transforming teosinte, the wild ancestor of modern corn, into the highly optimized solar powered calorie factory that we recognize today.

<img src="/img/graph-maizeEvolution.png" style="max-width: 400px;margin: 0 auto;border:none" alt = "Maize Evolution"/>

This transformation was possible because these early farmers made two key observations:

-  Across a field, certain individual plants displayed desirable traits, such as producing more seeds, while others did not
-  Choosing to only plant the seeds from plants with desirable traits, and allowing those plants to pollinate each other, frequently resulted in more plants that displayed the same desirable traits

These observable traits are known as [phenotypes](https://en.wikipedia.org/wiki/Phenotype), and the act of choosing to allow only plants displaying specific phenotypes to reproduce is called [artificial selection or selective breeding](https://en.wikipedia.org/wiki/Selective_breeding). The [selective pressure](https://en.wikipedia.org/wiki/Evolutionary_pressure) created through centuries of human-driven artificial selection allowed for the development of crops which yield substantially more food.

<img src="/img/graph-maizeHistoricYield.png" style="max-height: 400px;margin: 0 auto;border:none" alt = "Maize Historic Yield"/>

In modern times the quantity of grain yielded by a corn plant is measured in [bushels](https://en.wikipedia.org/wiki/Bushel)/[acre](https://en.wikipedia.org/wiki/Acre). To put those units in perspective, a single bushel of corn kernels weighs ~56 pounds, and a single acre of land is ~90% the area of an american football field. From the 1860’s, when the [United States Department of Agriculture (USDA)](http://www.ers.usda.gov/data-products/feed-grains-database/feed-grains-yearbook-tables.aspx) began collecting nation-wide corn yield data, until the late 1930's, the rate of gain in crop performance was nearly flat. Thankfully, humanity did not sit idly by for another several millennia and wait for the next great increase in genetic gain to develop. Just as technology advances in transistor fabrication have allowed the improvement in processor speed to keep pace with Moore’s Law, so too have scientific advances in our understanding of genetics allowed the obtainment of dramatic increases in the rate of genetic gain in corn, many other modern crops.


[Double-Cross Hybrid](http://passel.unl.edu/pages/informationmodule.php?idinformationmodule=1099683867&topicorder=5&maxto=6)

[Single-Cross Hybrid](http://passel.unl.edu/pages/informationmodule.php?idinformationmodule=1099683867&topicorder=4&maxto=9)

### **Genetic Gain is Created Through Breeding Cycles**

![Line Development Pipeline](/img/graph-lineDevelopmentPipeline.png)

A breeding cycle begins by selecting two parents, each displaying one or more desirable phenotypes, and crossing them to produce a large set of progeny plants which combine the genetics of both parents. This specific cross is frequently  called an **origin**. All progeny enter a selection pipeline which acts as a highly focused funnel of selective pressure. At each stage within the funnel only the progeny which display the desirable traits of both parents, without displaying any undesirable traits, are selected. Selected progeny are then crossed with each other and their progeny move onto the next round of selection. After each round of selection, the total number of progeny screened is reduced (the funnel narrows) until the cycle ends with a single progeny that displays all the best traits of the original parents. This seed from this plant will then go on to be used as a parent in future breeding cycles, or possibly in seed products sold to farmers.

At each stage of the selection pipeline decisions on which progeny will move forward are driven by the collection of two classes of dataset:

1.  **Genotype**: Plants are screened in the lab for genetic features predictive of phenotypes. This is called [genotype](https://en.wikipedia.org/wiki/Genotype) data and can be collected at high-throughput and low-cost
2.  **Phenotype**: Plants are screened in field trials in order to make direct obseravtions of phenotypes. Collecting this data is expensive and time-intensive, as it requires the allocation of both land and the labor to conduct the field trial. 

### **Every Breeding Cycle Extends a Growing Tree of Genetic Ancestry**

![Line Development Ancestry](/img/graph-lineDevelopmentAncestry.png)

- The newly bred parent, labeled “C”, has a tree of ancestors linking back to its origin cross
- Singly linked nodes represent “selfing” operations where progeny are crossed with each other as successive rounds of selection are performed
- The depth of any active ancestry tree often grows by four levels each year
- Each parent used in the cross will have it’s own tree of ancestors, going back several decades
- Each parent can and will be used in up to hundreds of origin crosses if that parent is of a high value
- Remember this parent, because things will get slightly more complicated


![Parent Descendants](/img/graph-lineDescendants.jpg)

![Ancestry RDBMS](/img/graph-ancestryInRDBMS.png)

![Benchmark Oracle](/img/graph-benchmarkOracle.png)

![Ancestry Neo4j](/img/graphs-ancestryInGraph.png)

![Oracle vs Neo4j](/img/graph-benchmarkOracleNeo4j.png)

![Sample Ancestry Tree](/img/graph-sampleAncestryTree.png)

<img src="/img/graph-sampleAncestryTree.png" style="max-height: 400px;margin: 0 auto;border:none" alt = "Sample Ancestry Tree"/>

```javascript
{
    "nodes": [
        {"id": 1},
        {"id": 2},
        {"id": 3},
        {"id": 4},
        {"id": 5},
        {"id": 6}
    ],
    "relationships": [
        {"from": 1, "to": 2, "relation": "PARENT"},
        {"from": 2, "to": 3, "relation": "PARENT"},
        {"from": 2, "to": 4, "relation": "PARENT"},
        {"from": 3, "to": 5, "relation": "PARENT"},
        {"from": 4, "to": 6, "relation": "PARENT"}
    ]
}
```

```javascript
{
    "female": {"id": 3},
    "male": {"id": 4}
}
```

```javascript
{
    "nodes": [
        {"id": 1},
        {"id": 2},
        {"id": 3},
        {"id": 4},
    ],
    "relationships": [
        {"from": 1, "to": 2, "relation": "PARENT"},
        {"from": 2, "to": 3, "relation": "PARENT"},
        {"from": 2, "to": 4, "relation": "PARENT"}
    ]
}
```
![Genotype Layer](/img/graphs-genotypeLayer.png)

```javascript
{
    "nodes": [
        {"id": 1, "genotypes": [{"id": 123}]},
        {"id": 2},
        {"id": 3},
        {"id": 4, "genotypes": [{"id": 456}]},
        {"id": 5, "genotypes": [{"id": 789}]}
    ],
    "relationships": [
        {"from": 1, "to": 2, "relation": "PARENT"},
        {"from": 2, "to": 3, "relation": "PARENT"},
        {"from": 2, "to": 4, "relation": "PARENT"},
        {"from": 3, "to": 5, "relation": "PARENT"},
        {"from": 4, "to": 6, "relation": "PARENT"}
    ]
}
```

![Expanded Pipeline](/img/graph-expandedLineDevelopmentPipeline.png)

[Using Big Data for Good](http://engineering.monsanto.com/2015/05/20/using-big-data-for-good/)

To avoid these pitfalls, when architecting solutions in the cloud, you
must design with the following five principles in mind.

1.  **Automation**: You must automate every aspect of your
    infrastructure and solution, ensuring your solution can be spun up
    reliably, rapidly, and repeatably.
2.  **Fault Tolerant**: Since cloud infrastructure is less reliable,
    you must create solutions that are fault tolerant, responding to
    and recovering from failures automatically.
3.  **Horizontally Scalable**: Your solution must be horizontally
    scalable so it can scale up to meet demand and scale back down to
    control costs.
4.  **Secure**: You must secure every aspect of your solution
    environment. Security is your job, not someone else's!
5.  **Cost Effective**: You have to use commodity, cost-effective
    components so that executing on the first four principles does not
    break the bank.

Done properly, cloud solutions can be more reliable and less costly.

To learn more about how to architect "cloud first" solutions, learn
about our journey to the cloud, and see how we use some of the tools
and libraries we have open sourced, be sure to attend our talk at AWS
re:Invent,
[Cloud First: New Architecture for New Infrastructure][reinvent], this
Thursday 8 October 2015 at 2:45 p.m. PT in Palazzo N.

[reinvent]: https://www.portal.reinvent.awsevents.com/connect/sessionDetail.ww?SESSION_ID=2547 (AWS re:Invent Cloud First talk)
