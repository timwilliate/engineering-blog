---
layout: post
title: "etcd Clustering in AWS"
subtitle: "Configuring a robust etcd cluster in an AWS Auto Scaling Group"
header-img: "img/mon-field_rows.jpg"
authors: 
    -
        name: "T.J. Corrigan"
        githubProfile : "tj-corrigan"
        twitterHandle : "sm_tjc"
        avatarUrl : "https://avatars3.githubusercontent.com/u/1248896?v=3"
tags: [aws, distributed systems, coreos, tutorials]
---

## Overview

For the last few months our team has been focused on building a robust, highly automated [Docker](https://www.docker.com) container infrastructure in [AWS](http://aws.amazon.com). We choose to use [CoreOS](https://coreos.com) as our base operating system because it is lightweight and container-centric. We are using [fleet](https://github.com/coreos/fleet), another CoreOS project, to handle scheduling containers across a cluster of machines and keeping them running even if the original host they are running on is terminated. Both CoreOS and fleet need a shared view of the current state of all the machines and containers running in the cluster. This is where [etcd]( https://github.com/coreos/etcd), yet another CoreOS project, comes in to play. etcd is a distributed, consistent key-value store used for storing shared configuration and information in a cluster. In a large production environment, etcd is designed to run on a subset of machines in the system, preferably either three or five hosts.

![etcd clustering architecture](/img/etcd-cluster-architecture.png)
*[source](https://coreos.com/docs/cluster-management/setup/cluster-architectures/#production-cluster-with-central-services)*

## The Bootstrapping Problem

etcd requires an initial bootstrapping to form a cluster. This can be accomplished in [several ways](https://github.com/coreos/etcd/blob/master/Documentation/clustering.md). Initially we used the [etcd discovery service](https://discovery.etcd.io/), but we saw strange behavior when using this with AWS Auto Scaling Groups, namely ghost IP addresses in the list the service would return. Plus, the discovery service does not handle the post-bootstrap problem of members joining and leaving the cluster. In the end, we chose the static method to reduce dependencies on external systems.

Our initial approach, using etcd 0.4, was to create 3 dedicated EC2 instances in AWS via [CloudFormation](http://aws.amazon.com/cloudformation/). This allowed us access to the IPs of these machines to use in the [cloud-config](https://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/#coreos) in a block like:

```yaml
coreos:
  etcd:
    addr: localhost:4001    
    peer-addr: localhost:7001
    peers: $ip_from_this_machine$:7001,$ip_from_other_machine$:7001,$ip_from_another_machine$:7001
```
While this approach works adequately there are a few disadvantages:

* **Robustness**

	These etcd server machines are critically important to the infrastructure and require special treatment. We were using static IPs, setting CloudWatch alarms, and doing extra monitoring. [Phil Cryer](https://twitter.com/fak3r), a colleague of mine, has been championing the concept of [Pets vs Cattle] (https://blog.engineyard.com/2014/pets-vs-cattle) and how we should avoid this sort of 'special' design, especially in an environment like AWS where Amazon doesn't guarantee the health of any given EC2 instance. 

* **CloudFormation Updates**

	Occasionally we needed to make changes to our infrastructure. To do this we would use CloudFormation to update our configuration. If there were any changes to these etcd machines, AWS would reboot them to apply the changes, potentially all at the same time. If this happened our cluster would become unavailable and may have trouble re-clustering.
  
## The Solution

In thinking of potential solutions we turned to a feature we were already using for our worker machines, [AWS Auto Scaling Groups](http://aws.amazon.com/autoscaling). In this case we don’t really want to scale up and down the number of etcd servers but do want to maintain a fixed cluster size, even if a host were to fail. However, this presented a new challenge in figuring out how to coordinate the bootstrapping of etcd. 

Around this time CoreOS released etcd2 into their alpha channel builds. This new version brought with it changes to bootstrapping and dynamic reconfiguration which gives us the flexibility we needed to manage cluster membership with Auto Scaling Groups.

### Bootstrapping

Our first concern was to automate the bootstrapping process. Since we no longer had fixed IPs like in our previous approach we needed a mechanism to discover the other leaders. 
Fortunately, the [Amazon CLI](http://aws.amazon.com/cli/) provides us with the tools we need. However, since we are using CoreOS we couldn’t just install the cli but needed to create a container for the job. The next concern was how to get the credentials needed to use the cli. Here we used an [IAM Instance Role](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html?console_help=true) to give our server machines read-only permissions to `ec2:Describe*` and `autoscaling:Describe*`. With these tools, we can accomplish what we need with a simple BASH script:

```bash
ec2_instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

ec2_instance_ip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

asg_name=$(aws autoscaling describe-auto-scaling-groups --region us-east-1 \
  | jq --raw-output ".[] map(select(.Instances[].InstanceId | contains(\"$ec2_instance_id\"))) | .[].AutoScalingGroupName")

etcd_peer_urls=$(aws ec2 describe-instances --region us-east-1 --instance-ids \
  $(aws autoscaling describe-auto-scaling-groups --region us-east-1 --auto-scaling-group-name $asg_name | jq .AutoScalingGroups[0].Instances[].InstanceId | xargs) \
  | jq -r '.Reservations[].Instances | map("http://" + .NetworkInterfaces[].PrivateIpAddress + ":2379")[]')
```

This script starts off by querying the EC2 instance ID and IP address from AWS using their [instance metadata endpoint](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html). With this information we are able to retrieve the name of the Auto Scaling Group that this particular instance belongs to by using the CLI and [jq](http://stedolan.github.io/jq/). From this we are then able to query for all the IPs of the machines in this Auto Scaling Group. We then write this information to file:

```bash
ETCD_INITIAL_CLUSTER_STATE=new
ETCD_NAME=$ec2_instance_id
ETCD_INITIAL_CLUSTER="$etcd_initial_cluster"
```

and then instruct etcd to load this information when it starts up. With these changes we were reliably able to boostrap etcd from an autoscaling group without any hardcoding!

### Maintaining Cluster Membership

Normally etcd is expecting that a machine would either remove itself from the cluster before exiting or would rejoin at a later time (e.g., in the event of a restart). We wanted to build something more robust where we could kill a machine and replace it with an entirely new machine without any hiccups in availability. Of course there were a few challenges&hellip;

#### Detecting New vs Existing Cluster

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

The basic idea here is that we try to connect to each machine in the Auto Scaling Group to see if any of them are currently running etcd and if so, what are the members of the cluster. We assume that if no one responds this must be a new cluster. Now if someone does respond back with a list of potential members we could still potentially be in a bootstrapping situation. Remember that the first machine to come up will still likely know about the other machines in the Auto Scaling Group and will already know their instance IDs or IPs. So if our instance ID is in the list we assume we are just late to the party but still part of the initial bootstrapping. 

#### Adding / Removing Members

Once we know that we are joining an existing cluster and the members of the cluster, we can begin the steps to add the new member to the existing cluster.

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

The first step is to try and detect whether any members of the cluster have been terminated. This can be deduced by comparing the list of members reported by etcd to the list of machines in the Auto Scaling Group. Once we find the bad host(s) we can go ahead and send a REST call to one of the good members of the cluster to remove the dead machine. Afterwards we can add the new machine to the cluster through another REST call before starting etcd. 

### etcd Bugs

At this point we thought we had a great pattern for dealing with adding and removing machines from the cluster and started some scale testing. Whenever we terminated a machine we saw that the cluster remained healthy, with one unhealthy node, until we tried to remove the dead node. After removing the dead node using the API, the cluster became unhealthy and would not accept writes. After a few minutes in this state, the cluster sorted things out and became healthy again. Once healthy, we were able to add the new machine and write to the cluster. I filed a [bug report](https://github.com/coreos/etcd/issues/2888) with the CoreOS team about this minutes-long unhealthy state after dead node removal and very quickly got a response and a solution (big kudos to the CoreOS team!). I've tested out their new builds and am happy to report we now have a reliable solution. Their fixes are merged in and hopefully we'll see them in a new release in the next week or two.

## Conclusion

We have now built a fully automated solution to build etcd clusters on AWS Auto Scaling Groups. I'm happy to announce that we have open-sourced our efforts ([GitHub](https://github.com/MonsantoCo/etcd-aws-cluster/)/[DockerHub](https://registry.hub.docker.com/u/monsantoco/etcd-aws-cluster/)) and hope they will be of use to the broader community. We welcome issues, contributions, comments, and questions.
