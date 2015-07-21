---
layout: post
title: "PaaSify your Apps"
subtitle: "Building an Open Source Cloud Foundry Toolbox"
header-img: "img/mon-field_rows.jpg"
author: Mark Seidenstricker 
githubProfile : "mjseid"
avatarUrl : "https://avatars2.githubusercontent.com/u/4573660?v=3"
tags: [open source, cloudfoundry, cf-portal, cf-users, cf-metrics]
---

The age of cloud computing is already here, and companies who don't adapt are at serious risk of getting left in the dust.  At monsanto we have fully embraced the transformation this revolution has brought and are diligently on the path towards a modern IT landscape focused around public cloud, microservices, open source technologies, and [12 factor apps](http://12factor.net/).  Transformations however, rarely happen overnight and like most enterprise companies we were starting the journey with a datacenter full of legacy and not-so-cloudy apps.  So our first step was to adopt
[Cloud Foundry](https://docs.cloudfoundry.org/concepts/overview.html), an open platform as a service which allowed our dev teams to start learning/adopting cloud designs on top of an agile platform in the safety of our private datacenter.  

We've been using Cloud Foundry for over a year now, and the core project is fairly comprehensive with extensions and tooling being contributed by the [community](https://github.com/cloudfoundry-community) on a regular basis.  But there are still a few areas which lack open source solutions to address the capabilities seen in the branded CF offerings.  In addition to using some of the existing community [tools](https://github.com/cloudfoundry-incubator/admin-ui) we've also added a few of our own and we'll be opening the first three projects from this toolbox to the community.

Starting with CF-Portal we will be doing a multi-part blog post over the coming weeks for each tool corresponding with its public release.  We hope these are useful to others using the platform, and we look forward to feedback/contribution to continue growing the cloud foundry community toolbox.

* [CF-Portal](https://github.com/MonsantoCo/cf-portal): Single Pane of Glass for Cloud Foundry Apps
* [CF-Users](https://github.com/MonsantoCo/cf-users): Self Service Team Management for Cloud Foundry
* [CF-Metrics](https://github.com/MonsantoCo/cf-metrics): Open Source Monitoring and Alerting for Cloud Foundry

