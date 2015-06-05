---
layout: post
title: "etcd Clustering in AWS"
subtitle: "How to configure a robust etcd cluster based upon AWS autoscaling groups"
header-img: "img/mon-field_rows.jpg"
author: "T.J. Corrigan"
tags: [aws, distributed systems, coreos]
---

## Overview

For the last few months our team has been focused on building a robust, highly automated [docker](https://www.docker.com) container infrastructure in [AWS](http://aws.amazon.com). We choose to use [CoreOS](https://coreos.com) as our base operating system due to its lightweight and docker-centric nature. In addition we are also using [fleet](https://github.com/coreos/fleet), another CoreOS project, to handle scheduling containers across a cluster of machines and keeping them running even in the original host they are running on is terminated. Both CoreOS and fleet need a shared view of the current state of all the machines and containers running in the cluster. This is where [etcd]( https://github.com/coreos/etcd), yet another CoreOS project, comes into play. etcd is a distributed, consistent key-value store used for storing shared configuration and information surrounding containers and service discovery. In a large production environment etcd is designed to run on a subset of machines in the system, preferable either 3 or 5 hosts.

![etcd clustering architecture](/img/etcd-cluster-architecture.png)
_[source](https://coreos.com/docs/cluster-management/setup/cluster-architectures/#production-cluster-with-central-services)_

## The Bootstrapping Problem

etcd requires an initial bootstrapping to form a cluster. This can be accomplished in several ways (see [link](https://github.com/coreos/etcd/blob/master/Documentation/clustering.md)). We ended up deciding to use the static method to reduce dependencies on external systems. 

Our initial approach was to create 3 dedicated EC2 instance in AWS via [CloudFormation](http://aws.amazon.com/cloudformation/). This allowed us access to the IPs of these machines to use in the cloud-config (see [link](https://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/#coreos)) in a block like:

``` yaml
coreos:
  etcd2:
    addr: localhost:4001    
    peer-addr: localhost:7001
    peers: $ip_from_this_machine$:7001,$ip_from_other_machine$:7001,$ip_from_another_machine$:7001
```
While this approach works adequately there are a few major disadvantages:

* Robustness
  
  These etcd server machines are critically important to the infrastructure and require special treatment. We were using hardcoded IPs, setting cloud watch alarms, and doing extra monitoring. Phil Cryer, a colleague of mine, recently did a talk on Pets vs Cattle (TODO add link) and how we should avoid this sort of 'special' design, especially in an environment like AWS where Amazon doesn't guarantee the health of any given EC2 instance. 

* CloudFormation Updates

  Occassionaly we needed to make changes to our infrastructure. To do this we would use CloudFormation to update our configuration. If there were any changes to these etcd machines AWS would reboot them to apply the changes, potentially all at the same time. If this happened our cluster would become unavailable and may have troubles re-establishing.
  
### The Solution

In thinking of potential solutions we turned to a feature we were already using for our worker machines, [AWS auto scaling groups](http://aws.amazon.com/autoscaling). In this case we don’t really want to scale up and down the number of etcd servers but do want to maintain a fixed cluster size, even if a host were to fail. However, this presented a new challenge in figuring out how to coordinate the bootstrapping of etcd. 

Around this time CoreOS released etcd2 into their alpha builds. This new version brought with it changes to bootstrapping and dynamic reconfiguration which gives us the flexibility we needed to manage cluster membership with auto scaling groups. Our first concern was to automate the bootstrapping process. Since we no longer had fixed IPs like in our previous approach we needed a mechanism to discover the other leaders. 

Fortunately, the [Amazon CLI](http://aws.amazon.com/cli/) provides us with the tools we need. However, since we are using CoreOS we couldn’t just install the cli but needed to create a container for the job. The next concern was how to get the credentials needed to use the cli. Here we used an [Instance Role](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html?console_help=true) to give our server machines read-only permissions to `ec2:Describe*` and `autoscaling:Describe*`. Anyways with these minor issues out of the way we wrote a bash script:

```bash
ec2_instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

ec2_instance_ip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

asg_name=$(aws autoscaling describe-auto-scaling-groups --region us-east-1 \
  | jq --raw-output ".[] map(select(.Instances[].InstanceId | contains(\"$ec2_instance_id\"))) | .[].AutoScalingGroupName")

etcd_peer_urls=$(aws ec2 describe-instances --region us-east-1 --instance-ids \
  $(aws autoscaling describe-auto-scaling-groups --region us-east-1 --auto-scaling-group-name $asg_name | jq .AutoScalingGroups[0].Instances[].InstanceId | xargs) \
  | jq -r '.Reservations[].Instances | map("http://" + .NetworkInterfaces[].PrivateIpAddress + ":2379")[]')
```

This script starts off by querying the instance id and ip from Amazon using their metadata endpoints ([documenatation](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html)). With this information we are able to retrieve the name of the auto scaling group that this particular instance belongs to by using the cli and [jq](http://stedolan.github.io/jq/). From this we are then able to query for all the ips of the machines in this auto scaling group. We then write this information to file:

```bash
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_NAME=$ec2_instance_id
ETCD_INITIAL_CLUSTER="$etcd_initial_cluster"
```

and then instruct etcd to load this information when it starts up. With these changes we were reliably able to boostrap etcd from an autoscaling group without any hardcoding!

## Maintaining Cluster Membership

Normally etcd is expecting that a machine would either remove itself from the cluster before exiting or would rejoin at a later time (like in the event of a restart). We wanted to build something more robust where we could kill a machine and replace it with an entirely new machine without an hiccups in availability. Of course there were a few challenges...

### Detecting New vs Existing Cluster

The first thing we discovered is that you needed to explicitly tell etcd if this was a new cluster or if you were joining an existing cluster for etcd to work correctly. After a bit of trial and error we arrived at:

```bash
etcd_existing_peer_urls=
etcd_existing_peer_names=
etcd_good_member_url=

for url in $etcd_peer_urls; do
    case "$url" in
        *$ec2_instance_ip*) continue;;
    esac

    etcd_members=$(curl -f -s $url/v2/members)

    if [[ $? == 0 && $etcd_members ]]; then
        etcd_good_member_url="$url"
		echo "etcd_members=$etcd_members"
        etcd_existing_peer_urls=$(echo "$etcd_members" | jq --raw-output .[][].peerURLs[0])
		etcd_existing_peer_names=$(echo "$etcd_members" | jq --raw-output .[][].name)
	break
    fi
done

if [[ $etcd_existing_peer_urls && $etcd_existing_peer_names != *"$ec2_instance_id"* ]]; then
    echo "joining existing cluster"
else
    echo "creating new cluster"
fi
```

The basic idea here is that we try to connect to each machine in the auto scaling group to see if any of them are currently running etcd and if so what are the members of the cluster. We assume that if no one responds this must be a new cluster. Now if someone does respond back with a list of potential members we could still potential be in a bootstrapping situation. Remember that the first machine to come up will still likely know about the other machines in the auto scaling group and will already be loaded in with their IDs/IPs. So if our instance ID is in the list we assume we are just late to the party but still part of the initial bootstrapping. 

### Adding / Removing Members

Once we know that we are joining an existing cluster as well as the members of the cluster we can set about to make the cutover to the machine. 

```bash
    # eject bad members from cluster
    peer_regexp=$(echo "$etcd_peer_urls" | sed 's/^.*http:\/\/\([0-9.]*\):[0-9]*.*$/contains(\\"\1\\")/' | xargs | sed 's/  */ or /g')

    bad_peer=$(echo "$etcd_members" | jq --raw-output ".[] | map(select(.peerURLs[] | $peer_regexp | not )) | .[].id")

    if [[ $bad_peer ]]; then
        for bp in $bad_peer; do
            echo "removing bad peer $bp"
            curl -f -s "$etcd_good_member_url/v2/members/$bp" -XDELETE
        done
    fi
    
    etcd_initial_cluster=$(curl -s -f "$etcd_good_member_url/v2/members" | jq --raw-output '.[] | map(.name + "=" + .peerURLs[0]) | .[]' | xargs | sed 's/  */,/g')$(echo ",$ec2_instance_id=http://${ec2_instance_ip}:2380")

    echo "adding instance ID $ec2_instance_id with IP $ec2_instance_ip"
    curl -f -s -XPOST "$etcd_good_member_url/v2/members" -H "Content-Type: application/json" -d "{\"peerURLs\": [\"http://$ec2_instance_ip:2380\"], \"name\": \"$ec2_instance_id\"}"
```

The first step is to try and detect whether any members of the cluster have been terminated. This can be deduced by comparing the list of members reported by etcd to the list of machines in the autoscaling group. Once we find the bad host(s) we can go ahead and send a rest call to one of the good member of the cluster to remove the dead machine. Afterwards we can now add the new machine to the cluster through another rest call before starting etcd. 

### etcd Bugs

At this point we thought we had a great pattern for dealing with adding and removing machines from the cluster and started some scale testing. Whenever we terminated machines we saw that the cluster remained healthy (with 1 unhealthy node) until we tried to run the remove command. At this point the cluster went unhealthy. Forunately everything eventually sorted itself out and the cluster regained stability after a few minutes. Once healthy again we were able to add the new machine and be back to a good state. This was still all automated when we put in the appropriate retry logic but still wasn't what we were hoping for. I put in a [bug report](https://github.com/coreos/etcd/issues/2888) with the CoreOS team and very quickly got a response and a solution (big kudos to the CoreOS team!). I've tested out their new builds and am happy to report we now have a reliable solution. The changes are merged in and hopefully we'll see a new release in the next week or two.

## Conclusion

We have now built a fully automated solution to build etcd clusters ontop of AWS auto scaling groups. I'm happy to announce that we have open-sourced our efforts ([github](https://github.com/MonsantoCo/etcd-aws-cluster/), [dockerhub](https://registry.hub.docker.com/u/monsantoco/etcd-aws-cluster/)) and hope they will be of use to the broader community. We welcome issues, contributions, comments, and questions.
