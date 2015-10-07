---
layout: post
title: "Demystifying IAM Roles"
subtitle: "Navigating the AWS IAM Role CloudFormation Labyrinth"
description: "AWS IAM Roles provide a powerful and secure way to assign privileges to your resources, but figuring out how to create and configure them, especially in CloudFormation, can be tricky."
header-img: "img/mon-hello-1.jpg"
authors:
    -
        name: "David Dooling"
        githubProfile : "ddgenome"
        twitterHandle : "ddgenome"
        avatarUrl : "https://avatars1.githubusercontent.com/u/57881?v=3"
tags: [cloud, iam, aws]
---

## TL;DR

The step-by-step process for creating IAM Roles and associating them
with EC2 Instances in CloudFormation.

1.  Create the assumeRolePolicyStatement and assumeRolePolicyDocument
1.  Create an AWS::IAM::Role for your EC2 instance, associating that role with the assumeRolePolicyDocument
2.  Create an AWS::IAM::InstanceProfile associated with your AWS::IAM::Role
3.  Create a PolicyStatement that defines the allowed action
4.  Put that PolicyStatement in a PolicyDocument
5.  Create an AWS::IAM::Policy for your PolicyDocument and associate it with all the AWS::IAM::Role, i.e.,
    instances, that need that role
6.  Finally, when you create your instance resource, associate your AWS::IAM::InstanceProfile with your instance
    using the IamInstanceProfile property

## Managing EC2 Instance Privileges

If you have used [AWS EC2][ec2] for any length of time you have come
across the need for an EC2 instance to create or access another AWS
resource on your behalf.  For example, perhaps you have needed an EC2
instance to be able to publish notifications on an SNS topic, get a
script or configuration from a private S3 bucket, or even spin up or
terminate another EC2 instance it was monitoring.

[ec2]: http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ec2-instance.html (CloudFormation EC2 Instance)

When first encountering this problem, you may have decided to put your
API key and secret somewhere on the instance and then point the CLI or
SDK to those credentials.  While this is expedient, it is not very
safe.  As the name implies, your API secret is not something you
really want getting out.  If you choose this pattern and hard code
your API key and secret everywhere, if one of the instances gets
compromised you are going to have a lot of cleaning up to do&hellip;
and probably a lot of explaining too.

A more secure approach would be to create an [IAM User][iam-user] for
each task that needs to be accomplished.  This user would then only be
assigned the permissions it needed to accomplish its task.  An API key
and secret could be generated for that user and then used on the
instances that needed that permission.  Then, should an instance be
compromised, anyone who got a hold of that key would only be able to
do a specific task and you would only need to deactivate one key and
clean up and reconfigure a hopefully smaller list of instances.  This
approach still has its disadvantages.  First, there is more overhead
and management of IAM Users.  Second, best practices dictate that you
should rotate your API keys regularly.  If you need lots of users for
lots of different tasks, it can be quite a bit of work to adhere to
that best practice.

[iam-user]: https://aws.amazon.com/iam/details/manage-users/ (AWS IAM User Documentation)

An even better approach for securely granting privileges to your EC2
instances is to use [IAM Roles for EC2][iam-roles].  With IAM Roles,
you create a role with the permission your EC2 instance needs and
assign that role to your instance.  AWS, through the
[instance metadata][metadata], provides an API key and secret to your
instance that has the desired permissions.  AWS automatically manages
the API key rotation and all the AWS SDKs and CLI know to look in the
instance metadata for the API key and secret.  Sounds great, right?
Well, it is great, but creating roles and assigning them to instances
is a bit more complicated than it sounds, especially when using
[AWS CloudFormation][cloudformation].

[iam-roles]: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html (AWS IAM Roles for EC2)
[metadata]: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html (AWS EC2 Instance Metadata Documentation)
[cloudformation]: https://aws.amazon.com/cloudformation/ (AWS CloudFormation Documentation)

Since at Monsanto we use [CloudFormation extensively][cftg-blog],
we've thought a lot about how best to leverage IAM Roles when we
create templates using our
[CloudFormation Template Generator (CFTG)][cftg].  We think we've come
up with a straightforward, easy to comprehend way to create IAM Roles
and assign them to EC2 instances in CloudFormation templates.  So how
do we do it?

[cftg-blog]: http://engineering.monsanto.com/2015/07/10/cloudformation-template-generator/ (CloudFormation Template Generator blog post)
[cftg]: https://github.com/MonsantoCo/cloudformation-template-generator (CloudFormation Template Generator GitHub)

### Boilerplate

The first thing you want to do when dealing with IAM Roles and EC2
instances in CloudFormation is get some boilerplate code out of the
way.  Specifically, you need to create a PolicyStatement with a
PolicyDocument that allows EC2 instances to assume IAM Roles.  Using
CFTG, that looks like this:

```scala
val allow: String = "Allow"

// 0. Common Policy Statments and Documents
val assumeRolePolicyStatement = PolicyStatement(
  Effect    = allow,
  Principal = Some(DefinedPrincipal(Map("Service" -> Seq("ec2.amazonaws.com")))),
  Action    = Seq("sts:AssumeRole")
)

val assumeRolePolicyDocument = PolicyDocument(
  Statement = Seq(assumeRolePolicyStatement)
)
```

The first thing we do is create a `val` for the string `"Allow"` since
we are going to use that string so often.  Then we create our
`assumeRolePolicyStatement` with EC2 as the principal and AssumeRole
as the action.  We then create the associated PolicyDocument,
`assumeRolePolicyDocument`, that holds the PolicyStatement.  You will
see this pattern when dealing with IAM roles in CloudFormation over
and over: creating standalone PolicyStatements that then get added to
PolicyDocuments.  It is the PolicyDocument that is referenced by other
resources.

### Roles for each instance type

The next thing you do is to create an "empty" role for each type of
instance you need, associating the role with the
`assumeRolePolicyDocument` just created.  This association tells AWS
what kind of role this is.  In this case, a role that allows EC2
instances to assume roles.  See how it starts to get confusing?  Below
is the CFTG code for two different instance types, a NAT instance role
and a bastion instance role.

```scala
val natRoleResource = `AWS::IAM::Role`(
  name                     = "NATRole",
  AssumeRolePolicyDocument = assumeRolePolicyDocument,
  Path                     = Some("/")
)

val bastionRoleResource = `AWS::IAM::Role`(
  name                     = "BastionRole",
  AssumeRolePolicyDocument = assumeRolePolicyDocument,
  Path                     = Some("/")
)
```

You can see that there is not much in these roles as currently
defined.  Other than giving them a name and associating them with the
`assumeRolePolicyDocument`, we only specify a path.  Here, we give the
root path, `/`, but you could use the [path][] to restrict where this
policy an be applied.

[path]: http://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html#identifiers-friendly-names (AWS IAM Path Documentation)

### Instance profiles for each instance role

For each instance role you created above, you next need to create an
InstanceProfile. There is a one-to-one mapping between instance roles
and InstanceProfiles.  Using CFTG, that looks like:

```scala
val natInstanceProfileResource = `AWS::IAM::InstanceProfile`(
  name  = "NATProfile",
  Path  = "/",
  Roles = Seq(ResourceRef(natRoleResource))
)

val bastionInstanceProfileResource = `AWS::IAM::InstanceProfile`(
  name  = "BastionProfile",
  Path  = "/",
  Roles = Seq(ResourceRef(bastionRoleResource))
)
```

Again, not much to see here.  Other than setting the name and the
association with the role, we set a non-restrictive path.

### Policy statements for each action

Now we finally get to actually defining what actions we want the
instances to be able to assume.  In doing this, we change our point of
view.  Rather than thinking about the instance types, we think about
the actions we want any instance to take.  A single instance type
could need more than one type of action.  Example CFTG code is below.

```scala
val natTakeOverPolicyStatement = PolicyStatement(
  Effect = allow,
  Action = Seq(
    "ec2:DescribeInstances",
    "ec2:DescribeRouteTables",
    "ec2:CreateRoute",
    "ec2:ReplaceRoute",
    "ec2:StartInstances",
    "ec2:StopInstances"
  ),
  Resource = Some("*")
)

val staxS3PolicyStatement = PolicyStatement(
  Effect   = allow,
  Action   = Seq("s3:GetObject"),
  Resource = Some(`Fn::Join`("", Seq("arn:aws:s3:::", `AWS::StackName`, "/*")))
)
```

Above we define two different sets of actions using two
PolicyStatements.  The first PolicyStatement,
`natTakeOverPolicyStatement`, defines the types of actions a NAT box
would need to terminate and recreate it high-availability (HA) NAT
partner and take over its route while it is down.  Unfortunately, it
does not restrict the application of these policies to only its HA NAT
partner.  Those actions can be executed on any EC2 instance (`Resource
= Some("*")`) in your account.  It would be better to restrict these
actions to the [VPC in which the NAT instances reside][iam-vpc].  The
second PolicyStatement allows read-only access to the S3 bucket with
the same name as the CloudFormation stack.

[iam-vpc]: http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_IAM.html#subnet-ami-example-iam (Scope IAM to a VPC)

### Policy documents to hold the statements

Remember near the beginning when we said you will often see
PolicyStatements associated with PolicyDocuments?  Well, that is all
we are doing here.

```scala
val natTakeOverPolicyDocument = PolicyDocument(Statement = Seq(natTakeOverPolicyStatement))

val staxS3PolicyDocument      = PolicyDocument(Statement = Seq(staxS3PolicyStatement))
```

It is worth noting that a PolicyDocument can hold more than one
PolicyStatement, as implied by the value being a `Seq()`, should that
be useful to you.

### Creating IAM Policies

The next step is to create IAM Policies.  The role of an IAM Policy is
to associate a PolicyDocument with one or more of the instance roles.
In other words, there is a one-to-one mapping of an IAM Policy to a
PolicyDocument but the IAM Policy can hold more than one instance
role.

```scala
val natTakeoverPolicyResource = `AWS::IAM::Policy`.from(
  name           = "NatTakeoverPolicy",
  PolicyDocument = natTakeOverPolicyDocument,
  PolicyName     = "NatTakeover",
  Groups         = None,
  Roles          = Some(Seq(ResourceRef(natRoleResource))),
  Users          = None
)

val staxS3PolicyResource = `AWS::IAM::Policy`.from(
  name           = "StaxS3Policy",
  PolicyDocument = staxS3PolicyDocument,
  PolicyName     = "StaxS3",
  Groups         = None,
  Roles          = Some(Seq(ResourceRef(natRoleResource), ResourceRef(bastionRoleResource))),
  Users          = None
)
```

Above we are using the `AWS::IAM::Policy` helper method `from` to
create the IAM Policy resource.  You can see in each case we give the
IAM::Policy resource a name, associate it with a single
PolicyDocument, and give the policy a name.  We do not associate the
policy to any groups or users.  In the case of
`natTakeoverPolicyResource`, we associate it with a single instance
role, `natRoleResource`.  For the `staxS3PolicyResource`, we associate
it with two instance roles, both the `natRoleResource` and the
`bastionRoleResource`.

### Putting it all together

We now have several IAM Policies that associate a set of actions as
contained within the PolicyDocument with instance roles.  Those
instance roles, in turn, are associated with InstanceProfiles.  It is
those InstanceProfiles that are used when creating EC2 instances.

```scala
def natInstance(number: Int, subnet: `AWS::EC2::Subnet`) = {
  val name = "NAT" + number + "Instance"
  Builders.ec2(
    name               = name,
    InstanceType       = ParameterRef(natInstanceTypeParameter),
    KeyName            = ParameterRef(keyNameParameter),
    ImageId            = `Fn::FindInMap`[AMIId](MappingRef(awsNATAMIMapping), `AWS::Region`, "AMI"),
    SecurityGroupIds   = Seq(),
    SubnetId           = subnet,
    Tags               = AmazonTag.fromName(name),
    Metadata           = Some(Map("Comment1" -> (s"Create NAT $nat1"))),
    IamInstanceProfile = Some(natInstanceProfileResource),
    SourceDestCheck    = Some("false"),
    UserData           = Some(`Fn::Base64`(`Fn::Join`("", Seq[Token[String]](...))))
  )
val nat1Instance = natInstance(1, pubSubnet1)
val nat2Instance = natInstance(2, pubSubnet2)
```

Here, since we are creating two NAT instances, we have defined a
simple method to create them using the CFTG EC2 builder method, `ec2`,
and I have removed the UserData. Ignoring the unimportant bits, you
see that the `IamInstanceProfile` is set to
`natInstanceProfileResource`, the InstanceProfile we created above
and, using the IAM Policy, associated with the
`natTakeOverPolicyDocument` and the `staxS3PolicyDocument` through the
`natRoleResource`.

Similarly the bastion instance uses the
`bastionInstanceProfileResource` as its IamInstanceProfile.

```scala
val bastion = "BastionInstance"
val bastionInstance = Builder.ec2(
  name               = bastion,
  InstanceType       = ParameterRef(bastionInstanceTypeParameter),
  KeyName            = ParameterRef(keyNameParameter),
  ImageId            = `Fn::FindInMap`[AMIId](MappingRef(amazonLinuxAMIMapping), `AWS::Region`, "AMI"),
  IamInstanceProfile = Some(bastionInstanceProfileResource),
  SecurityGroupIds   = Seq(),
  SubnetId           = pubSubnet1,
  Tags               = AmazonTag.fromName(bastion),
  UserData           = Some(`Fn::Base64`(`Fn::Join`("",Seq[Token[String]](...))))
)
```

### JSON

The JSON created by all that CFTG code is shown below.

```json
"NATRole": {
  "Properties": {
    "AssumeRolePolicyDocument": {
      "Statement": [{
        "Effect": "Allow",
        "Principal": {
          "Service": ["ec2.amazonaws.com"]
        },
        "Action": ["sts:AssumeRole"]
      }]
    },
    "Path": "/"
  },
  "Type": "AWS::IAM::Role"
},
"BastionRole": {
  "Properties": {
    "AssumeRolePolicyDocument": {
      "Statement": [{
        "Effect": "Allow",
        "Principal": {
          "Service": ["ec2.amazonaws.com"]
        },
        "Action": ["sts:AssumeRole"]
      }]
    },
    "Path": "/"
  },
  "Type": "AWS::IAM::Role"
},
"BastionProfile": {
  "Properties": {
    "Path": "/",
    "Roles": [{
      "Ref": "BastionRole"
    }]
  },
  "Type": "AWS::IAM::InstanceProfile"
},
"NATProfile": {
  "Properties": {
    "Path": "/",
    "Roles": [{
      "Ref": "NATRole"
    }]
  },
  "Type": "AWS::IAM::InstanceProfile"
},
"StaxS3Policy": {
  "Properties": {
    "PolicyDocument": {
      "Statement": [{
        "Effect": "Allow",
        "Action": ["s3:GetObject"],
        "Resource": {
          "Fn::Join": ["", ["arn:aws:s3:::", {
            "Ref": "AWS::StackName"
          }, "/*"]]
        }
      }]
    },
    "PolicyName": "BastionRoleStaxS3",
    "Roles": [{
      "Ref": "NATRole"
    }, {
      "Ref": "BastionRole"
    }]
  },
  "Type": "AWS::IAM::Policy"
},
"NatTakeoverPolicy": {
  "Properties": {
    "PolicyDocument": {
      "Statement": [{
        "Effect": "Allow",
        "Action": ["ec2:DescribeInstances", "ec2:DescribeRouteTables", "ec2:CreateRoute", "ec2:ReplaceRoute", "ec2:StartInstances", "ec2:StopInstances"],
        "Resource": "*"
      }]
    },
    "PolicyName": "NatRoleNatTakeover",
    "Roles": [{
      "Ref": "NATRole"
    }]
  },
  "Type": "AWS::IAM::Policy"
},
"NAT1Instance": {
  "Properties": {
    "ImageId": {
      "Fn::FindInMap": ["AWSNATAMI", {
        "Ref": "AWS::Region"
      }, "AMI"]
    },
    "UserData": {
      "Fn::Base64": {
        "Fn::Join": ["", [...]]
      }
    },
    "KeyName": {
      "Ref": "KeyName"
    },
    "InstanceType": {
      "Ref": "NATInstanceType"
    },
    "Tags": [{
      "Key": "Name",
      "Value": {
        "Fn::Join": ["-", ["NAT1Instance", {
          "Ref": "AWS::StackName"
        }]]
      }
    }],
    "SourceDestCheck": "false",
    "IamInstanceProfile": {
      "Ref": "NATProfile"
    },
    "SubnetId": {
      "Ref": "PublicSubnet1"
    }
  },
  "Metadata": {
    "Comment1": "Create NAT #1"
  },
  "Type": "AWS::EC2::Instance"
},
"NAT2Instance": {
  "Properties": {
    "ImageId": {
      "Fn::FindInMap": ["AWSNATAMI", {
        "Ref": "AWS::Region"
      }, "AMI"]
    },
    "UserData": {
      "Fn::Base64": {
        "Fn::Join": ["", [...]]
      }
    },
    "KeyName": {
      "Ref": "KeyName"
    },
    "InstanceType": {
      "Ref": "NATInstanceType"
    },
    "Tags": [{
      "Key": "Name",
      "Value": {
        "Fn::Join": ["-", ["NAT2Instance", {
          "Ref": "AWS::StackName"
        }]]
      }
    }],
    "SourceDestCheck": "false",
    "IamInstanceProfile": {
      "Ref": "NATProfile"
    },
    "SubnetId": {
      "Ref": "PublicSubnet2"
    }
  },
  "Metadata": {
    "Comment1": "Create NAT #2"
  },
  "Type": "AWS::EC2::Instance"
},
"BastionInstance": {
  "Properties": {
    "ImageId": {
      "Fn::FindInMap": ["AmazonLinuxAMI", {
        "Ref": "AWS::Region"
      }, "AMI"]
    },
    "UserData": {
      "Fn::Base64": {
        "Fn::Join": ["", [...]]
      }
    },
    "KeyName": {
      "Ref": "KeyName"
    },
    "InstanceType": {
      "Ref": "BastionInstanceType"
    },
    "Tags": [{
      "Key": "Name",
      "Value": {
        "Fn::Join": ["-", ["BastionInstance", {
          "Ref": "AWS::StackName"
        }]]
      }
    }],
    "IamInstanceProfile": {
      "Ref": "BastionProfile"
    },
    "SubnetId": {
      "Ref": "PublicSubnet1"
    }
  },
  "Type": "AWS::EC2::Instance"
}
```

Note that some of those variables we defined ended up being serialized
into JSON several times in the resulting template.  Using CFTG, you
can avoid this duplication and possible future error by only have one
place to update when changes need to be made.

## Wrapping Up

We hope this walk through of how we create and assign IAM Roles in
CloudFormation is helpful.  If you have a different approach or ideas
on how to improve our approach, [we'd love to hear them][contact].

[contact]: http://engineering.monsanto.com/contact/ (Contact Us)
