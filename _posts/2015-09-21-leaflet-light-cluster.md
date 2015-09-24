---
layout: post
title: "Cluster Lightly"
subtitle: "Organizing Geospatial Data Without Overwhelming Your Browser"
header-img: "img/light-cluster-view.jpg"
authors: 
    -
        name: "Caleb Courier"
        githubProfile : "CalebCourier"

tags: [leaflet, geospatial, clustering, map]
---

As the amount of available technology increases so does the amount of available data.  Of this newly available data,
much of it is concerned with two major questions:

 - When?

 and
 
 - Where?

The ability to associate data throughout time and space has allowed the development of applications that can make
informed decisions based on someone's position at a particular time.
These machine-made suggestions can be as commonplace as what route to take home during rush hour from applications such
as Waze or Google Maps, or as seemingly complex as deciding where to get brunch by typing something ridiculous like
"open breakfast diners with really big omelets near me" into a search engine on your smartphone. Machine made decisions
like this are made possible by the growing amount of geospatial data, i.e., information that is related to a specific
location.  The problem that we face now is not where to get the data or even how to store it necessarily, but rather
how to visually represent this large amount of data in a meaningful way.  This is where clustering comes into play.

Clustering geospatial data is not a new concept. It has been used in GIS related fields for centuries for reasons
such as Dr. John Snow's method to track cholera outbreaks in the mid 1800's to modern day classification algorithms
used in image analysis.  However, as developers, one of the challenges we face is when and how to actually cluster the
data we have.  Plenty of libraries and modules exist that will take your data into a black box and spit out some
clustered objects, and these work phenomenally under certain conditions.  For example, if you don't have a terrible
amount of data, say just a few thousand objects, or if you don't mind handing your data over to a third party via a
webservice then these are great options.  On the other hand, if you're dealing with millions of objects or points you
probably won't be able to, and won't want to, do heavy processing with them on the client.  This is where LightCluster
comes in.

In short, LightCluster is an extension for the Leaflet.js mapping library that allows you to use a server side
clustering solution for geospatial data.  Unlike other javascript clustering libraries, LightCluster doesn't want all
the data up front in order to run clustering algorithms on the client; instead it expects a minimized cluster object
consisting of a lat-long pair to know where to place it, a bounding box to show the area of the data it represents, and
a count of how many objects it's representing.  You may be thinking "Hold on now, what exactly does it do then?". The
answer to that is: Whatever you tell it to.  Upon initialization this simple extension will take in an anonymous
function which you define for updating the data and, depending on the options you pass in, it will use your update
function when handling all of the click, drag, and zoom events on the map.  It also keeps track of how many
points/objects are in the cluster and will reduce the cluster to a standard leaflet marker if the count is only one.
Because of this simplification on the client you can define and execute all the intense processing on the server side
where it should be.  Granted, this requires you to develop your own clustering solution in order to generate these
light weight cluster objects.  The good news is it's not as hard as it sounds.  One extremely simple solution is to use
[geohash](http://www.movable-type.co.uk/scripts/geohash.html).  Since geohash already represents points/areas in a
unique way that can be directly related at various amounts of precision, most of the work of correlating your data into
related geospatial regions is already done.  Since this method is so simple it's actually what I used to generate the
sample data used in the [demo project](https://github.com/CalebCourier/Leaflet.LightCluster). Of course if you would
rather use something more traditional or statistical feel free.  Some of the more commonly used clustering algorithms
include DBSCAN and K-means both of which you can find code implementations with a simple Google search. No matter what
you do, LightCluster will take it and perform its simple task of rendering and updating keeping your client code light
and your map performant.
