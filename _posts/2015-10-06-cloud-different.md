---
layout: post
title: "Cloud Different"
subtitle: "A new architecture for a new platform"
description: "The cloud present new opportunities but also new challenges. Learn how to create successful solutions in the cloud using five architectural principles."
header-img: "img/mon-maui.jpg"
authors:
    -
        name: "David Dooling"
        githubProfile : "ddgenome"
        twitterHandle : "ddgenome"
        avatarUrl : "https://avatars1.githubusercontent.com/u/57881?v=3"
tags: [cloud, architecture, principles, reinvent]
---

Over the past several years, cloud computing of all types has gained a
lot of momentum. Because of the massive increase in mobile computing,
i.e., phones and tablets, more and more people are consuming cloud
services like GMail, DropBox, Instagram, and Office365. These Software
as a Service (SaaS) solutions are convenient for people on the go
because the information they need is always easily accessible through
a web browser or mobile app. This is possible because the user's data
and preferences are stored "in the cloud", using servers and services
managed by someone else, typically the operator of the SaaS
solution. While these SaaS solutions are convenient for end users,
they do not allow for much customization. To develop custom
capabilities in the cloud, you must turn to Infrastructure as a
Service (IaaS).

IaaS consists of virtualized compute, storage, and networking managed
by someone else that you can consume, typically on a pay-per-use
basis. The automation enabled by consuming infrastructure via services
allows you to spin up an entire data-center-like environment in less
than ten minutes! Many IaaS providers like Amazon Web Services,
Microsoft Azure, and Google Cloud Platform provide additional
capabilities like managed message queues, notifications, and even
databases delivered as a service. Using these building blocks of IT,
you can rapidly create solutions for your customers without purchasing
a single piece of hardware.

So what's the catch? While self-service infrastructure and paying only
for what you use sounds great, typically cloud infrastructure is less
reliable and over time becomes more expensive than on-site
resources. To reap the benefits of IaaS, you must think differently
about your solution architecture. If you don't, you'll end up with a
less reliable, more expensive solution.

![Cloud Different](/img/cloud-different.jpg)

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

Just as how you architect solutions in the cloud must change,
continuing to use the technology and processes that have been
optimized for internal operations is not going to lead to success in
the cloud.  At Monsanto, when we asked ourselves how we could be
successful in the cloud, we knew our people would have to adopt new
technologies and develop more agile processes. We would have to
transition from different teams managing different part of a custom
applications life cycle, i.e., one team for development, another for
testing, another for operation, and yet another for support, we should
have teams operating in a DevOps model, owning a capability from
cradle to grave and providing it as a service to their customers.

The cloud presents an amazing opportunity to increase the speed with
which companies can deliver capabilities to their customers. To
capitalize on the opportunity, you must embrace the cloud's
differences and use them to your advantage.  The architectural
principles outlined above coupled with more agile process and a
holistic DevOps model allow teams to create solutions that are more
secure, more reliable, more performant, and more cost effective than
on-premises solutions.  In addition, your teams will be able to
deliver solutions that delight your users much more quickly than
before.

To learn more about how to architect "cloud first" solutions, learn
about our journey to the cloud, and see how we use some of the tools
and libraries we have open sourced, be sure to attend our talk at AWS
re:Invent,
[Cloud First: New Architecture for New Infrastructure][reinvent], this
Thursday 8 October 2015 at 2:45 p.m. PT in Palazzo N.

[reinvent]: https://www.portal.reinvent.awsevents.com/connect/sessionDetail.ww?SESSION_ID=2547 (AWS re:Invent Cloud First talk)
