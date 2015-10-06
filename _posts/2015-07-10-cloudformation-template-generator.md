---
layout: post
title: "CloudFormation Template Generator"
subtitle: "or A Tour of Scala Type System Features"
header-img: "img/mon-hands_grains.jpg"
authors: 
    -
        name: "Ryan Richt"
        githubProfile : "ryan-richt"
        twitterHandle : "ryan_richt"
        avatarUrl : "https://avatars2.githubusercontent.com/u/541228?v=3"
tags: [types, scala, aws, tutorials]
extra_css:
  - implicits-intro.css
---

## TL;DR

CloudFormation gives you a declarative specification to stand up complex AWS topologies. You can simplify creation of templates with potentially thousands of lines using our open source, type-safe [library ](https://github.com/MonsantoCo/cloudformation-template-generator) to generate templates with the full power of Scala. We use a variety of strategies to simplify creation of resources as well as encode consistency checks in Scala's type system.

## Hand-crafted Template Woes

At Monsanto we have a reasonably complex infrastructure topology for managing Microservice applications in AWS. You may have seen our post open sourcing our [Stax](http://engineering.monsanto.com/2015/07/08/stax/) tool for simplifying interactions with AWS and managing our VPCs. Or maybe you're jumping into the new AWS [Service Catalog](http://aws.amazon.com/servicecatalog/).

Stax, AWS Service Catalog, and underlying [CloudFormation](http://aws.amazon.com/cloudformation/) all work on a BYOT model - bring your own template. Our problem was, as our topology become more complex and many members of our team spent more and more time making changes, our template ballooned to ~5,000 lines of JSON. Worse, CloudFormation entries are not self-contained but also contain internal references:

```json
"MyAutoScaleGroup": {
      "Type": "AWS::AutoScaling::AutoScalingGroup",
      "Properties": {
        "LoadBalancerNames": [{
          "Ref": "MyLoadBalancerA"
        }, {
          "Ref": "MyLoadBalancerB"
        }],
        ...
```

meaning that changes to a template may require simultaneous edits to far-flung parts of the template you might not even know exist.

Today we have reduced our template to ~500 lines of Scala that make use of our [CloudFormation Template Generator library](https://github.com/MonsantoCo/cloudformation-template-generator) which is now open source under the BSD 3-clause license.

## Goals

In designing CFTG, we wanted to eliminate repetition and many common errors that we saw in working with complex templates:

* Support generation of repetitive elements
* Constrain "References" to entities that actually exist
* Check the types of Maps and Functions like Fn::If
* Lift all of the stringly-typed parameters like AMI's or CIDR blocks into strong types
* Explicitly model optional fields
* Disallow the many mutually exclusive parameter settings described in the CloudFormation documentation

We also wanted to create a "layered" set of abstractions. At the bottom most layer, we have objects that map directly to CloudFormation JSON objects and we are continuing to work on higher-order Builder functions to create groups of meaningful functionality, such as autoscaling groups with reasonable launch configs.

In early versions and after aggressive refactoring we also noticed that the majority of our remaining template code concerned Security Groups and In/Egress Rules so we also created a DSL for ingress rules and a construct for implicit security groups we call "SecurityGroupRoutables."

Why didn't we use [Terraform](https://www.terraform.io) or roll-our-own API calls? While these might be great solutions for some, Terraform did not (and still does not yet) support all of the resources types we needed to use. We also wanted the full power of a Turing-complete language like Scala to abstract complex elements. As fans of "immutable infrastructure" we also liked the idea of using CloudFormation where we have an authoritative, declarative specification of our entire environment without drift.

## Low-Level Bits

We love [Spray-JSON](https://github.com/spray/spray-json) and its type-class based system for mapping classes to JSON. All of our Resource classes look something like this:

```scala
case class `AWS::EC2::Subnet`(
  name:             String,
  VpcId:            Token[ResourceRef[`AWS::EC2::VPC`]],
  AvailabilityZone: Token[String],
  CidrBlock:        Token[CidrBlock],
  Tags:             Seq[AmazonTag],
  override val Condition: Option[ConditionRef] = None
  ) extends Resource[`AWS::EC2::Subnet`]{

  def when(newCondition: Option[ConditionRef] = Condition) = copy(Condition = newCondition)
}
object `AWS::EC2::Subnet` extends DefaultJsonProtocol {
  implicit val format: JsonFormat[`AWS::EC2::Subnet`] = jsonFormat6(`AWS::EC2::Subnet`.apply)
}
```
The Resource companion objects always define an implicit [Spray-JSON](https://github.com/spray/spray-json) type class instance.

OK so it's not quite a perfect mapping to the JSON. In CloudFormation, top level entities are held in a map with a user specified name as a key. In CFTG each Resource or Parameter has a "name" property that holds this label _inside_ each object so that it can be be more easily referenced from others.

But we do try to map as closely to CloudFormation as possible. We have non-idiomatic Scala capital field names in Resources to match that CloudFormation standard. We use Scala's back-tick labels to preserve the CloudFormation ```AWS::EC2::Subnet``` style names for better search-ability and familiarity with raw CloudFormation. We also support Conditions on resource which result in conditional creation, including a "when" convenience function that you can also use through:

```scala
import com.monsanto.arch.cloudformation.model.simple.Builders._

object Example{
	...
	val conditionalResource = when(someCondition){
		someResource
	}
}
```

## More Types

This `AWS::EC2::Subnet` Resource also highlights a few other central concepts in CFTG: our reference types, our common usage of wrapper types for things like CIDR Blocks and Amazon's Tags, and the mysterious "Token" type.

In CloudFormation, you can reference Resources, Parameters, Mappings and Conditions by name. In CFTG we force all of these to be by object reference using `ResourceRef`, `ConditionRef`, `ParameterRef`, and `MappingRef`. These references contain a type parameter of what they point to. For instance, to define an `AWS::EC2::Subnet` you have to pass in a `VpcId: Token[ResourceRef[AWS::EC2::VPC]]`. In stock CloudFormation this parameter is just a string, as are CIDR blocks, AMI IDs, etc., but in CFTG we have strict types for almost everything.

Many of these types do have implicit conversions to make them easier to use: you can always pass a Resource instance, like an `AWS::EC2::Instance` to something that takes a `ResourceRef[AWS::EC2::Instance]` and it will be converted for you. Similarly for classes like CidrBlock which is defined like this:

```scala
case class IPAddressSegment(value: Int){ require( value <= 255 && value >= 0 ) }
object IPAddressSegment {
  implicit def fromInt(i: Int): IPAddressSegment = IPAddressSegment(i)
}

case class IPMask(value: Int){ require( value <= 32 && value >= 0 ) }
object IPMask {
  implicit def fromInt(i: Int): IPMask = IPMask(i)
}

case class CidrBlock(
	a: IPAddressSegment, 
	b: IPAddressSegment, 
	c: IPAddressSegment, 
	d: IPAddressSegment, 
	mask: IPMask
)
...
```

This makes it valid to write simply:

```scala
val myBlock = CidrBlock(10, 10, 0, 0, 16)
```

but have the type checking of:

```scala
val myBlock = CidrBlock(
	IPAddressSegment(10), IPAddressSegment(10), IPAddressSegment(0), IPAddressSegment(0), 
	IPMask(16)
)
```

You'll note this is one of the few places we "cheat" with run-time (but remember this is template _generation_ runtime, not template instantiation runtime) with some [Design-by-contract](https://en.wikipedia.org/wiki/Design_by_contract) style checks for valid numerical ranges of IP segments.

## Typed Functions

OK, so what is that funny `Token[T]` thing? It might be a terrible name ([Pull Requests welcome](https://github.com/MonsantoCo/cloudformation-template-generator/pulls)), but it's purpose is to abstract over "a literal `T`" or "an Amazon function that returns a `T`." In CFTG, we have versions of the built-in Amazon functions like:

* `Fn::GetAtt`
* `Fn::Join`
* `Fn::FindInMap`
* `Fn::Base64`
* `Fn::Equals`
* `Fn::Not`
* `Fn::And`
* `Fn::Or`
* `Fn::If`

Consider the implementation of `Fn::If`:

```scala
case class `Fn::If`[R : JsonFormat](
	conditionName : Token[String], 
	valIfTrue: Token[R], 
	valIfFalse: Token[R]
) extends AmazonFunctionCall[R]("Fn::If"){
	type CFBackingType = (Token[String], Token[R], Token[R])
	val arguments = (conditionName, valIfTrue, valIfFalse)
...
}
```

Here `R` is the logical return type of the `Fn::If` in CFTG (logical because this is _our_ notion of a return type, not stock CloudFormation's). For instance I could have a: 

```scala

val gatewayServiceELBSecGroup = // Security group with 80 ingress rules
val gatewayServiceELBSSLSecGroup = // Security group with 443 ingress rules

val serviceElbOrElbSSL: Token[ResourceRef[`AWS::EC2::SecurityGroup`]] =
  `Fn::If`[ResourceRef[`AWS::EC2::SecurityGroup`]](
    "ServiceELBSSLCertNameIsNotDefined",
    gatewayServiceELBSecGroup,
    gatewayServiceELBSSLSecGroup
  )
```

I've shown the explicit return type parameter of this `Fn::If` which here is a ``Token[ResourceRef[`AWS::EC2::SecurityGroup`]]``, not just a string! In this way I could pass this value confidently to an `AWS::EC2::Instance` constructor that requires a Security Group.

Back to Tokens, while you can explicitly wrap a Resource (and sometimes other values) you can always just pass a Resource or a Function return value and it will be promoted into a Token value using the implicit conversions:

```scala
sealed trait Token[R]
object Token extends DefaultJsonProtocol {
  implicit def fromAny[R: JsonFormat](r: R): AnyToken[R] = AnyToken(r)

  implicit def fromOptionAny[R: JsonFormat](or: Option[R]): Option[AnyToken[R]] =
    or.map(r => Token.fromAny(r))

  implicit def fromString(s: String): StringToken = StringToken(s)

  implicit def fromFunction[R](f: AmazonFunctionCall[R]): FunctionCallToken[R] =
    FunctionCallToken[R](f)

  implicit def fromSome[R](oR: Some[R])(implicit ev1: R => Token[R]): Some[Token[R]] =
    oR.map(ev1).asInstanceOf[Some[Token[R]]]

  implicit def fromOption[R](oR: Option[R])(implicit ev1: R => Token[R]): 
  	Option[Token[R]] = oR.map(ev1)

  implicit def fromResource[R <: Resource[R]](r: R)(implicit conv: (R) => ResourceRef[R]): 
  	Token[ResourceRef[R]] = fromAny(conv(r))

  implicit def fromSeq[R <: Resource[R]](sR: Seq[R])(implicit toRef: R => ResourceRef[R]): 
  	Seq[Token[ResourceRef[R]]] = sR.map(r => fromAny(toRef(r)))
```

This includes the ability to automatically wrap options of things (including a more specific conversion to maintain Somes as such, more on that later), each of a sequence of Resources, etc.

## Patterns for Encoding Complex Constraints

There are several Amazon resources with documentation like:

> AWS::Route53::RecordSet  
> ...  
> AliasTarget  
> *Alias resource record sets only:* Information about the domain to which you are redirecting traffic.  
> ...  
> TTL  
> The resource record cache time to live (TTL), in seconds. *If you specify this property, do not specify the AliasTarget property.* For alias target records, the alias uses a TTL value from the target.  
> ...

If this is relatively simple, we can (did) just create a class with a private constructor and a set of defined factory methods, like this real example:

```scala
class `AWS::Route53::RecordSet` private (
  val name:            String,
  val RecordName:      Token[String],
  val RecordType:      Route53RecordType,
  val HostedZoneName:  Option[Token[String]],
  val HostedZoneId:    Option[Token[String]],
  val ResourceRecords: Option[Seq[Token[String]]] = None,
  val TTL:             Option[Token[String]]      = None,
  val AliasTarget:     Option[Route53AliasTarget] = None,
  override val Condition: Option[ConditionRef]    = None
  ) extends Resource[`AWS::Route53::RecordSet`]{
  ...
  }
object `AWS::Route53::RecordSet` {
  ...
  def generalRecord(...) = new `AWS::Route53::RecordSet`(...)
  def aliasRecord(...) = new `AWS::Route53::RecordSet`(...)
}
  
```

So we try to do this in a variety of places in CFTG to ensure we are creating AWS resources that are "correct by construction."

Elsewhere, we use a more sophisticated pattern, that is obvious in Scala but we haven't seen documented anywhere, that we call the "Valid Combo Pattern." For this AWS resource:

>AWS::EC2::Route
>
>Creates a new route in a route table within a VPC. The route's target can be either a gateway attached to the VPC or a NAT instance in the VPC.  
>...  
>GatewayId  
>...  
>Required: Conditional. **You must specify only one of the following properties: GatewayId, InstanceId, NetworkInterfaceId, or VpcPeeringConnectionId.**

Here to avoid writing a long constructor method four times, we specify a set of implicits values, one for each valid combo, from a class with a private constructor that others cannot create new instances of:

```scala
@implicitNotFound("A Route can only have exactly ONE of GatewayId, InstanceId, NetworkInterfaceId or VpcPeeringConnectionId set")
class ValidRouteCombo[G, I] private ()
object ValidRouteCombo{
  implicit object valid1T extends 
  	ValidRouteCombo[Some[Token[ResourceRef[`AWS::EC2::InternetGateway`]]], None.type]
  
  implicit object valid2T extends 
  	ValidRouteCombo[None.type , Some[Token[ResourceRef[`AWS::EC2::Instance`]]]]
  ...
}
```

Then our factory method uses type parameters and implicits to make sure that a caller is filling in a valid set of Somes and Nones according to the defined implicits:

```scala
object `AWS::EC2::Route` extends DefaultJsonProtocol {
...
  def apply[
    G <: Option[Token[ResourceRef[`AWS::EC2::InternetGateway`]]],
    I <: Option[Token[ResourceRef[`AWS::EC2::Instance`]]]
  ](
    name:                         String,
    RouteTableId:                 Token[ResourceRef[`AWS::EC2::RouteTable`]],
    DestinationCidrBlock:         CidrBlock,
    GatewayId:                    G = None,
    InstanceId:                   I = None,
    Condition: Option[ConditionRef] = None
   )(implicit ev1: ValidRouteCombo[G, I]) = 
   		new `AWS::EC2::Route`(
   			name, RouteTableId, DestinationCidrBlock, GatewayId, InstanceId, Condition
   		)
}	
```

You can see the implicit parameter ev1 (evidence 1) witnesses that G,I are part of one of the valid combinations that we encoded above, namely that only one of the options can be a Some.

Now we could implement the other `ValidRouteCombo`'s for NetworkInterfaceId and VpcPeeringConnectionId each with one line of new code instead of 9 lines each of another constructor for each. Further, the Valid Combo Pattern encodes much more explicitly in the type system what is valid than the private constructor + factories approach.

## YAML Support

In addition to our templates including lots of Amazon resources, they eventually accumulated many large and increasing complex [CloudConfig](https://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/) configuration files to setup individual hosts. Some of the components formerly hand-coded in CloudFormation JSON were duplicated across many files.

We support 2 features to abstract these common pieces and compose them back together:

```scala
object LoggingSupport {
  private val logrotateYaml = "/cloudconfig/logrotate.yaml"
  private val logspoutYaml = "/cloudconfig/logspout.yaml"
  private val journalspewYaml = "/cloudconfig/journalctl.yaml"

  val loggingUnits =
    yaml"" // yes this is supposed to be """, but I can't figure out how to make Markdown happy
      -- $logspoutYaml
      -- $logrotateYaml
    ""
}
...
    yaml"" // this one too
      |#cloud-config
      |
      |coreos:
      |  units:
      |    ${LoggingSupport.loggingUnits}
    ""
```

First, we provide a YAML string interpolator that allows you to compose bits of YAML together, accounting for indenting. You can see this in the bottom section where we include a YAML list into the CoreOS units map.

Second, as you can see at the top, instead of a bit of YAML, you can instead provide a file path to your YAML files, in this case files under src/main/resources/cloudconfig, and the contents of that file will be transcluded (with indenting) into the interpolating YAML.

## Higher-Order Builders

For simpler topologies, we have a set of convenience methods to more easily create common entities. For instance, many types of Resources, like `AWS::EC2::Instance`'s require a constructor parameter for VPC and Subnet in which that instance will be contained. Our methods allow you to express a template in a way that visually resembles a diagram of your architecture. Logical/network containment is express in nested code blocks:

```scala
withVpc(ParameterRef(vpcCidrParameter)){ implicit vpc =>
	withAZ(ParameterRef(availabilityZone1Parameter)){ implicit az1 =>
      withSubnet("Public", 1, ParameterRef(publicSubnet1CidrParameter)){ implicit pubSubnet1 =>
      	  ec2(
             "myInstance",
             InstanceType = "t2.micro",
             KeyName = ParameterRef(keyNameParameter),
             ImageId = `Fn::FindInMap`[AMIId](MappingRef(amazonLinuxAMIMapping), `AWS::Region`, "AMI"),
             SecurityGroupIds = Seq(),
             Tags = AmazonTag.fromName("myInstance"),
             UserData = None
            )
          )
      } ++
      withSubnet("Private", 1, ParameterRef(privateSubnet1CidrParameter)){ implicit priSubnet1 =>
      	...
      }
   } ++
   withAZ(ParameterRef(availabilityZone2Parameter)){ implicit az2 =>
      withSubnet("Public", 2, ParameterRef(publicSubnet2CidrParameter)){ implicit pubSubnet2 =>
      	...
      } ++
      withSubnet("Private", 2, ParameterRef(privateSubnet2CidrParameter)){ implicit priSubnet2 =>
      	...
      }
   }
}
```

This method above returns a `Template` whose JSON serialization is a CloudFormation template. The convenience methods `withVPC`, `withAZ` and `withSubnet` each take a few parameters, internally create a resource of the specified type and then take a block or function passing that resource along. Each of these expect you to return a `Template` and note that `Template`s can be composed with `++`. While `withVPC` is stand alone, some of the others also take implicit parameters, for instance:

```scala
  def withSubnet(visibility: String, ordinal: Int, cidr: Token[CidrBlock])
    (f: (`AWS::EC2::Subnet`) => Template)(implicit vpc: `AWS::EC2::VPC`, az: AZ): Template = { ... }
```

Subnets require a VPC and an AZ. To express this most succinctly, above we marked the passed along resources (vpc, az1, pubSubnet1, etc) as `implicit`. Turns out you can add the `implicit` modifier in front of parameters of lambdas in Scala, as in `Seq(1,2,3).map(implicit x => x + 1)` to bring `x` into implicit scope.

Then, methods like `ec2()`, `elb`, `asg()` (autoscaling group) or `securityGroup` also use these implicit parameters so you dont have to keep passing them around:

```scala
trait EC2 {
  def ec2(
    name:               String,
    InstanceType:       Token[String],
    KeyName:            Token[String],
    ImageId:            Token[AMIId],
    SecurityGroupIds:   Seq[ResourceRef[`AWS::EC2::SecurityGroup`]],
    Tags:               Seq[AmazonTag],
    Metadata:           Option[Map[String, String]] = None,
    IamInstanceProfile: Option[Token[ResourceRef[`AWS::IAM::InstanceProfile`]]] = None,
    SourceDestCheck:    Option[String] = None,
    UserData:           Option[`Fn::Base64`] = None,
    Monitoring:         Option[Boolean] = None,
    Volumes:            Option[Seq[EC2MountPoint]] = None,
    Condition: Option[String] = None
    )(implicit subnet: `AWS::EC2::Subnet`, vpc: `AWS::EC2::VPC`) = // IMPLICITS!
    SecurityGroupRoutable from `AWS::EC2::Instance`(
      name, InstanceType, KeyName, subnet, ImageId, Tags, SecurityGroupIds, Metadata,
      IamInstanceProfile, SourceDestCheck, UserData, Monitoring, Volumes
    )
}
```

We also have a few methods to do things like create EIPs or CloudWatch alarms from EC2 instances as in:

```scala
val myEIP = myEC2Instance.withEIP("NAT1EIP")
val myCloudWatch = myEC2Instance.alarmOnSystemFailure("NATInstanceAlarm", "nat-instance")
val myEC2AndOutput = myEC2Instance.andOutput("NAT1EIP", "NAT 1 EIP")
```

You can see these and other RichXYZ method pimps in com.monsanto.arch.cloudformation.model.simple.Builders.

## SecurityGroupRoutables

Above you might have noticed this sneaky `SecurityGroupRoutable` type. After using all of the techniques above, you'll still be left with lots of code to make security groups and to associate various ones to various resources. We've begun to create a new abstraction, `SecurityGroupRoutable`, currently supporting `AWS::EC2::Instance`'s, `AWS::ElasticLoadBalancing::LoadBalancer`'s and `AWS::AutoScaling::LaunchConfiguration`'s / `AWS::AutoScaling::AutoScalingGroup`'s. Instead of manually defining security groups for logically similar instances, we discovered it was less work overall to specify ingress rules point to point between all necessary Resource instances (or to define them in a function).

So a `SecurityGroupRoutable[R <: Resource[R]]` is a wrapper around a Resource that itself needs or can be associated with a security group, as well as an auto-generated security group specific for that `Resource` that is injected into the resource. In other words, every `Resource` that is wrapped in an SGR gets its own security group associated only to itself. Then instead of defining ingress/egress rules in the definition of that security group, we use the fact that CloudFormation also permits the definition of `AWS::EC2::SecurityGroupEgress` and `AWS::EC2::SecurityGroupIngress` rules as stand-alone resources that point to security groups.

Several of the higher-level methods for creating `Resource`'s above now return SGRs instead of bare `Resource`'s. Note that SGRs have a `.template` method that returns a template containing both the `Resource` and its `SecurityGroup`.

## Ingress Rule DSL

So now that we have methods to automate all of the above, the last major source of duplication and friction is in creating those Ingress and Egress rules between Security Groups or `SecurityGroupRoutables`. To solve this problem, we created a little DSL to specify the creation of many of these rules at once, and in an easy to grok syntax. A secondary goal was that these rules might be more easily audited by a non-developer security team.

```scala
    val securityGroupA = securityGroup("A", "Group A")
    val securityGroupB = securityGroup("B", "Group B")

    securityGroupA ->- 22 ->- securityGroupB
    securityGroupA ->- 22 / UDP ->- securityGroupB
    securityGroupA ->- 22 / ICMP ->- securityGroupB
    securityGroupA ->- 22 / ALL ->- securityGroupB
    securityGroupA ->- (1 to 65536) ->- securityGroupB
    securityGroupA ->- (1 to 65536) / ICMP ->- securityGroupB

    securityGroupA ->- Seq(22, 5601) ->- securityGroupB
    securityGroupA ->- Seq(22, (5601 to 5602) / UDP, 45 / ICMP, 14 / TCP) ->- securityGroupB


    securityGroupA ->- 22 -<- securityGroupB
    securityGroupA -<- 22 ->- securityGroupB
```

So yes, we do have this one symbolic operator in CFTG, and we read it as "flow." Each expression like `x ->- 22 / TCP ->- y` generates a list of ingress rules, in this case it generates a single rule that allows ingress traffic on port 22 over the TCP protocol from security group `x` to security group `y`.

As you can see above, you can leave off `/ TCP` as it is the default. We also support other protocols such as ` / UDP` or ` / ICMP` or the wildcard ` / ALL`. We read `/` as "over," as in "22 over TCP" like you'd say "JSON over HTTP." (OK so I guess we have two, TWO symbolic operators.) We also support port ranges, which use Scala ranges of ports like `(1 to 1024)`, as well as cherry-picked sequences of ports like `Seq(22, 5601)`. Ranges also support protocols, and sequence elements can both have protocols and themselves be nested ranges.

You can flow in either direction, because who wants to have to remember which ways the arrows are "supposed to go", meaning you can write the same ingress rule as either:

```scala
a ->- 22 ->- b
//or
b -<- 22 -<- a
```

More importantly, you can use arrows facing in opposite directions to express bi-directional flows, meaning a pair of ingress rule lists, allowing ingress into each of the two security groups:

```scala
// either server can accept SSH traffic from the other
a ->- 22 -<- b
//same as
a -<- 22 ->- b
```

## Summary

Clearly this library is far from complete. Writing this post, it is obvious that we should replace `Fn::If`'s first parameter (now a string Condition name) with a `ConditionRef`, it would be nice if we generated Egress rules in addition to Ingress rules from "flows," etc. And if anyone has a great idea for modeling cross-cutting concerns like ASGs in a beautiful way, pull requests are always welcome!

We hope though that CFTG is sufficiently advanced that you can use it in your work. We certainly use it to generate our complex Microservice environment templates at Monsanto, and are delighted to share it with all of you.
