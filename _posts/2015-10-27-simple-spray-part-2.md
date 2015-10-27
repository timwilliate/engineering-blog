---
layout: post
title: "Building a simple Spray application Part 2: Improving routes and responses"
subtitle: "Making first contact with Spray as painless as possible"
header-img: "img/mon-field_rows.jpg"
authors: 
    -
        name: Scott MacDonald 
        githubProfile : "samus42"
        avatarUrl : "https://avatars1.githubusercontent.com/u/1211796?v=3&s=460"
tags: [open source, spray, scala]
---
[Last time we spoke](http://engineering.monsanto.com/2015/08/11/simple-spray/) we went through the simple building blocks to creating a Spray application.  As you go forward though, you will want to have more options in composing your routes, and making sure the routes are constructed correctly.

You can feel free to download the [code](https://github.com/MonsantoCo/simple-spray-with-routing) and follow along.  I've separated the different sections into their own packages, so when running the code change the import demo.PACKAGE.ServiceActor in Main.scala to the appropriate package.

## Organizing your routes
Last time we ended up with a single Trait class that contained all our routes, and a single Actor that extended it.  Summarized, it looked something like this:
```scala
import akka.actor.Actor
import spray.routing.HttpService
import scala.concurrent._

class SampleServiceActor extends Actor with SampleRoute {
    def actorRefFactory = context
    def receive = runRoute(routes)
}

trait SampleRoute extends HttpService {
	import spray.httpx.SprayJsonSupport._
    import Stuff._
    import spray.http.MediaTypes
    implicit def executionContext: ExecutionContextExecutor = actorRefFactory.dispatcher
	val routes = {
    	path("stuff") { 
        	respondWithMediaType(MediaTypes.`application/json`) {
	        	get {
    	        	complete(Stuff(1, "my stuff"))
        	    } ~ 
            	post {
            		entity(as[Stuff]) { stuff =>
                		complete(Stuff(stuff.id + 100, stuff.data + " posted"))
                }
            }
        } ~ 
        pathPrefix("junk") {
            pathPrefix("mine") {
                pathEnd {
                    get {
                        complete("MINE!")
                    }
                }
            } ~ pathPrefix("yours") {
                pathEnd {
                    get {
                        complete("YOURS!")
                    }
                }
            }
        }
    }
}
```

For a simple situation, doing everything in one trait is fine.  However you're probably going to end up doing something much larger, and stuffing everything together will get very confusing with all the nesting that goes on.  Also there's not really a good relationship between *junk* and *stuff*, so separating that is probably a good idea.

###Separating your routes
Separating the routes into their own traits is as straighforward as it sounds

```scala
import demo.Stuff._
import spray.http.MediaTypes
import spray.httpx.SprayJsonSupport._
import spray.routing.HttpService

trait StuffRoute extends HttpService {
    implicit def executionContext = actorRefFactory.dispatcher

    val routes = {
        path("stuff") {
            respondWithMediaType(MediaTypes.`application/json`) {
                get {
                    complete(Stuff(1, "my stuff"))
                } ~
                  post {
                      entity(as[Stuff]) { stuff =>
                          complete(Stuff(stuff.id + 100, stuff.data + " posted"))
                      }
                  }
            }
        }
    }
}

trait JunkRoute extends HttpService {
    val routes = pathPrefix("junk") {
        pathPrefix("mine") {
            pathEnd {
                get {
                    complete("MINE!")
                }
            }
        } ~ pathPrefix("yours") {
            pathEnd {
                get {
                    complete("YOURS!")
                }
            }
        }
    }
}
```
Note that in each trait I've defined a *routes* property.  This is simply a convention, you can call it whatever you wish.  However having this convention has a small price.  Recall our service actor:
```scala
class SampleServiceActor extends Actor with SampleRoute {
    def actorRefFactory = context
    def receive = runRoute(route)
}
```
We extend the route trait and pass in the routes property to the *runRoute* method to setup the required *receive* action.  If we always call the property *routes* on all our traits, we're going to hit some conflicts when we extend all of these traits.  The solution is to no longer extend them, but to instantiate them inside our actor instead.  This also means we need to extend from *HttpServiceActor* instead of *Actor* since we are no longer extending a trait that contains the framework we need.  The final code looks like this:
```scala
import spray.routing.HttpServiceActor

class ServiceActor extends HttpServiceActor {
    override def actorRefFactory = context

    val stuff = new StuffRoute {
        override implicit def actorRefFactory = context
    }

    val junk = new JunkRoute {
        override implicit def actorRefFactory = context
    }
    def receive = runRoute(stuff.routes ~ junk.routes)
}
```
As you can see, we utilize the ~ operator to combine the routes. 

###Ordering matters
While it's a good idea to separate your different contexts this way, you can possibly run into an issue where you have path conflicts.  To show this, append the end of each trait's *routes* property:
```scala
~ get { complete("root from stuff|junk") }
```
Run the app and access your root, you should only see the message from the *stuff* service.  Change the ordering of the routes in the *runRoute* method and try again, you should see the *junk* service's response.  It get's worse, now try to access the */stuff* context, you'll notice the same root message again.

Remember that Spray looks for the first match, so the order you link the routes matters.  If you have a general fallback in a trait early in the chain, it will never resolve to the other paths that are probably more appropriate.  

If you need a general fallback strategy, make sure its in a different trait *at the end of the chain*.  The most common mistake here is tacking on a custom 404 for a context if nothing matches.  If put at too high a level, it will actually block all other contexts. 

Now that we know how to split up our services into more managable chunks, let's revisit how paths are built.

##Constructing paths more cleanly
Our *junk* context currently can support the paths *junk/mine* and *junk/yours*.  It does so by nesting pathPrefix & pathEnd statements like so:
```scala
val routes = pathPrefix("junk") {
        pathPrefix("mine") {
            pathEnd {
                get {
                    complete("MINE!")
                }
            }
        } ...
```
There is a way to condense this somewhat. While *path("junk/mine")* doesn't work, you can separate the strings with the */* character into something that does work.
```scala
val routes = path("junk" / "mine") {
        get {
            complete("MINE!")
        }
    } ~ path("junk" / "yours") {
        get {
            complete("YOURS!")
        }
    }
```
But the main benefit here is that it allows an easy way to grab path parameters.  To illustrate this, let's go back to our *stuff* route.  

Currently the *GET* operation just returns a single item, let's change that to return something by id, pretending we're talking to a data store.  Instead of putting another string after the */* we'll instead just put in a Spray type matcher.

```scala
val stuffMap = Map(1 -> Stuff(1, "my stuff"), 2 -> Stuff(2, "your stuff"))
val routes = {
	respondWithMediaType(MediaTypes.`application/json`) {
    	path("stuff" / IntNumber) { (id) =>
        	get {
            	complete(stuffMap(id))
            }
        } ~
        path("stuff") {
        	post {
            	entity(as[Stuff]) { stuff =>
                	complete(Stuff(stuff.id + 100, stuff.data + " posted"))
            	}
            }
        }
    }
}
```
Notice the (id) => expression, the matchers will map to that declaration in the order they are defined.  So you could do something like the following:
```scala
path("stuff" / IntNumber / "substuff" / IntNumber / "subsubstuff" / IntNumber) { 
	(id, subId, subsubId) => ....
}
```
Go ahead and modify your code with these changes and give it a try.  You should get different answers for a call to *stuff/1* vs *stuff/2*.

You might also want to try *stuff/3*, you'll see we get an internal server error, but that's not what we really want.  Which brings us to....

##Rejecting requests
In the case above, a **404 - Not Found** seems to be the response we really want.  Luckilly the *complete* method is overloaded to allow us to do this easily by passing a status (**import spray.http.StatusCodes._**) as the first parameter.  Let's see how this looks in our *stuff* service.

```scala
import spray.http.StatusCodes._
...
path("stuff" / IntNumber) { (id) =>
	get {
		stuffMap.get(id) match {
			case Some(stuff) => complete(stuff)
			case None => complete(NotFound -> s"No stuff with id $id was found!")
		}
	}
} ~
...
```
Go ahead and try that out, when you call the url *stuff/3* you should get the correct **404 - Not Found** error with our message included.  

###Validating Requests In The Path
In certain cases you might want a quick way to send a **400 - Bad Request** defined in your path structure.  For instance, we send a **404 - Not Found** if the id isn't available, but what if we wanted to tell the user that an *id* less than 1 wasn't only not found, but was an incorrect usage?  The *validate* directive gives us a quick way to do this.  Our code now looks like this:
```scala
...
path("stuff" / IntNumber) { (id) =>
	validate(id > 0, "Id must be greater than 0!") {
		get {
			stuffMap.get(id) match {
				case Some(stuff) => complete(stuff)
				case None => complete(NotFound -> s"No stuff with id $id was found!")
			}
		}
	}
}
...
```

###Using Exception Handlers
There's another way to handle common cases.  Let's say we want an *IllegalArgumentException* to automatically be translated into a **400 - Bad Request**.  In fact let's modify our *POST* call to *stuff* to make that happen if it receives and id less than 1
```scala
...
path("stuff") {
	post {
		entity(as[Stuff]) { stuff =>
			if (stuff.id <= 0) throw new IllegalArgumentException("Id cannot be less than 1!")
			complete(Stuff(stuff.id + 100, stuff.data + " posted"))
		}
	}
}
....
```
If you run this code as it is, you'll end up with an **500 - Internal Server Error**.  However, you can attach an *ExceptionHandler* to your *ServiceActor* class to automatically take care of this for you.

```scala
import spray.http.StatusCodes._
import spray.routing.{ExceptionHandler, HttpServiceActor}

class ServiceActor extends HttpServiceActor {
    override def actorRefFactory = context

    implicit def exceptionHandler = ExceptionHandler {
        case ex: IllegalArgumentException => complete(BadRequest -> ex.getMessage)
    }

    val stuff = new StuffRoute {
        override implicit def actorRefFactory = context
    }

    val junk = new JunkRoute {
        override implicit def actorRefFactory = context
    }

    def receive = runRoute(junk.routes ~ stuff.routes)

}
```
Try running the service now and do a *POST* with an id less than 1, you should see the correct HTTP response and message.

##In the end....
Spray gives you a lot of flexibility to setup your routes and responses in a way that works best for your application.  I recommend starting with the basic nesting and refactoring to other formats as you get more complex.  Decide early on your strategy of returning errors, so you're not just shimming it later.  Correct error responses will save you tons of support hours.

In the next installment I'll go over Unit Testing, and including Swagger documentation (and how that might affect your route construction).