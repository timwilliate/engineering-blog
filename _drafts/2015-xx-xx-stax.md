---
layout: post
title: "Stax"
subtitle: "Creates and manage CloudFormation stacks in AWS"
header-img: "img/mon-field_rows.jpg"
category: code
tags: [open source, aws, stax, cloudformation]
---

# Stax

Install [aws-cli](https://github.com/aws/aws-cli) (Universal Command
Line Interface for Amazon Web Services) on your client.


## License

Stax runs, and has been fully tested, on Linux (Debian GNU/Linux 7 and
Ubuntu 14.04, but others should work fine) and Apple OS X (tested
on 10.10 and 10.9).


## About
Several templates are provided with stax, below are brief descriptions.

Stax creates and manages CloudFormation stacks (aka stax) in AWS
([Amazon Web Services](aws.amazon.com)).  Several CloudFormation
templates are provided with stax.  More can be generated using the
[cloudformation-template-generator](https://github.com/MonsantoCo/cloudformation-template-generator).

<!--more-->

As an illustration, `stax` can create a set of entities in AWS like
those shown in the diagram below.

![AWS Stax Diagram](aws-stax.png)




```bash
$ ./stax
Usage: stax [OPTIONS] COMMAND

Options:
  -c,--config=CONFIG       Use file CONFIG rather than config/vpc-default.json
  -d,--debug               Turn on verbose messages
  -h,--help                Output this message
  -j,--jump=IP             SSH through host with IP address IP
  -m,--module=MOD          Use config/MOD.json and template/MOD.json
  -t,--template=TEMPLATE   Use file TEMPLATE rather than template/vpc-default.json
  -v,--version             Print name and version information
  -y,--yes                 Do not prompt for confirmation

If an argument is required for a long option, so to the short. Same for
optional arguments.

Commands:
  add                Add functionality to an existing VPC
  check              Run various tests against an existing stax
  connect [TARGET]   Connect to bastion|gateway|service in the VPC stax over SSH
  create             Create a new VPC stax in AWS
  describe           Describe the stax created from this host
  delete             Delete the existing VPC stax
  dockerip-update    Fetch docker IP addresses and update related files
  fleet              Run various fleetctl commands against the fleet cluster
  help               Output this message
  history            View history of recently created/deleted stax
  list               List all completely built and running stax
  rds PASSWORD       Create an RDS instance in the DB subnet
  rds-delete RDSIN   Delete RDS instance RDSIN
  remove ADD         Remove the previously added ADD
  services           List servers that are available to run across a stax
  start SERVICE      Start service SERVICE in the fleet cluster
  test               Automated test to exercise functionality of stax
  validate           Validate CloudFormation template

For more help, check the docs: https://github.com/MonsantoCo/stax
```

The stax project started off with ideas from the following projects:

* [emmanuel/coreos-skydns-cloudformation](https://github.com/emmanuel/coreos-skydns-cloudformation)
* [xueshanf/coreos-aws-cloudformation](https://github.com/xueshanf/coreos-aws-cloudformation)
* [kelseyhightower/kubernetes-coreos](https://github.com/kelseyhightower/kubernetes-coreos)


The MIT License (MIT)

Copyright (c) 2015 philcryer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Stax Studio

Stax, besides being a clever take on the word stacks, is named after
the famous Stax Recording Studio in Memphis, TN. If you're ever in
Memphis, visit the awesome
[Stax Museum](http://www.staxmuseum.com/)... it's far more interesting
than Sun Studios, but I digress.

![Stax Museum](https://media-cdn.tripadvisor.com/media/photo-s/01/70/29/68/stax-recording-studio.jpg)
