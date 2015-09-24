---
layout: post
title: "Cloud Foundry Metrics"
subtitle: "Open Source Monitoring and Alerting for Cloud Foundry"
description: "Announcing CF-Metrics, an example of open source monitoring and alerting with Cloud Foundry"
header-img: "img/mon-chesterfield.jpg"
authors:
    -
        name: Mark Seidenstricker 
        githubProfile : "mjseid"
        avatarUrl : "https://avatars2.githubusercontent.com/u/4573660?v=3"
tags: [cloudfoundry, cf-metrics, monitoring]
---
In the second installation of our open source [Cloud Foundry (CF) toolbox series](http://engineering.monsanto.com/2015/07/22/building-an-open-source-cloud-foundry-toolbox/) we would like to introduce [CF-Metrics](https://github.com/MonsantoCo/cf-metrics), a comprehensive solution for Cloud Foundry monitoring and alerting based solely on open source projects.  In a world of unreliable cloud infrastructure and distributed micro service architectures, monitoring and alerting are as critical now as they've ever been.  Even when you learn to expect failure (or better yet [embrace it](https://github.com/strepsirrhini-army/chaos-lemur)) and build self healing platforms like Cloud Foundry, you still need monitoring and alerting to analyze why there was a failure and how to make it not happen again in the future.

## Lowering the Cost of Entry

When we first started with Cloud Foundry at Monsanto, monitoring was one of the key areas the team needed to tackle to feel comfortable running the platform. Maybe it's a placebo effect, but knowing I have the ability to graph any metric at will keeps me from loosing sleep at night.  And although this topic remains highly requested in meetups and mailing lists, publicized documentation and more importantly downloadable working implementations are still relatively sparse.

By releasing CF-Metrics, we hope to provide a solution which will help new community users get off the ground quicker by:

- Being one of the quickest and most painless ways to get up and running with a functional CF monitoring solution 
- Re-using existing components to eliminate the need to run custom plugins and/or forked releases

## The Setup
CF-Metrics is a combination of open source tools (Heka, InfluxDB, and Grafana) running as a docker compose application.  Packaging the tools via docker makes it compact and highly portable to a variety of hosting solutions.  We purposefully elected not to package the application as a BOSH release since it's best practice not to run your monitoring solution on the platform that it is monitoring.
<img src=/img/cf-metrics-arch.png  width=700 height=400/>

## Gathering the metrics
To gather metrics we are utilizing two components that have been a part of BOSH and Cloud Foundry for a long time time: CF collector and BOSH monitor.  CF collector is in charge of grabbing metrics from two built-in endpoints (/varz and /healthz) published by every job in the Cloud Foundry release.  By default it does this every thirty seconds and returns a wealth of statistics about the performance, utilization, and health of each job.  BOSH monitor talks to the BOSH agent installed on every VM in the releases it deploys and gathers OS related metrics such as CPU, swap, and disk utilization.

These components have the capability to forward their consolidated metric streams to a number of 3rd party tools via configuration in their release ymls.  For the purposes of our project, we are choosing to forward BOSH and CF metrics via the common graphite protocol and BOSH events via the new BOSH monitor consul plugin.

## Processing 
To process the metric and event stream, we chose Mozilla's open source stream processing system [Heka](http://hekad.readthedocs.org/en/latest/index.html).  Heka is lightweight and its lua sandbox functionality gives it the ability to perform a large variety of functions.  Once the metric and event data is sent to Heka, it is decoded from graphite to Heka format and then streamed through a variety of filters to accomplish our specific tasks.  

## Alerting
Alerting through Heka is done through configuration of sandbox filters.  There are filters which trigger on specific message types flowing through the system and perform logic to determine if an alert is required.  It then uses the built-in alert module to inject an alert message into the Heka stream and set a timer to throttle additional alerts of that type for the specified time.  Alert messages are then picked up by a separate sandbox and sent to a Heka output such as an email address or a slack channel.

We've included some alert filters we find useful such as swap utilization and DEA memory ratios, but creating your own is as easy as creating a new Heka filter with your custom logic.  Heka also has built in anomaly detection modules so if you're adventurous you can go beyond traditional threshold based alerting.

## Storing and Trending
Once the metric and event data has flowed through the filters a heka encoder and output are used to dump the metrics we want to persist to a InfluxDB database.  This data is then accessible via Grafana to create ad-hoc graphs or custom dashboards like the one below
![DEA Stats ](/img/cf-metrics-dea.png)

## Ready, Set, Go!
For a deeper look at CF-Metrics head over to the [github page](https://github.com/MonsantoCo/cf-metrics) to try it out for yourself.  If you make a feature enhancement or useful dashboard we'd love a PR to include it in the project.  Or if you have your own solution for Cloud Foundry monitoring and alerting, hopefully we've encouraged you to pay it forward and share it with the community.

