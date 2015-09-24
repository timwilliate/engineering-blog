---
layout: post
title: "Better Spray metrics with Kamon"
subtitle: "Introducing spray-kamon-metrics"
description: "The Open Source spray-kamon-metrics library improves Spray-Kamon integration by providing better response metrics, detects timeouts, and reports Spray can server statistics."
header-img: "img/mon-monmouth.jpg"
authors: 
    -
        name: "Daniel Solano Gómez"
        githubProfile: "sattvik"
        twitterHandle: "deepbluelambda"
        avatarUrl: "https://avatars1.githubusercontent.com/u/152491?v=3&s=460"
tags: [open source, spray, scala, kamon]
---

At Monsanto, we have adopted [Kamon][] for monitoring our microservices
implemented in Scala with [Spray][].  Kamon provides an
[integration][kamon-spray] that will automatically instrument our services to
generate traces for each incoming request.  This is great, but we wanted more.
Some of the things we wanted to improve included:

* Providing better response metrics
* Detecting requests that time out
* Reporting Spray can server statistic through Kamon

To accomplish this, we have created and open sourced the
[spray-kamon-metrics][] library.  This library contains two independent pieces
of functionality:

1. `TracingHttpService`, a drop-in replacement for spray-routing’s
   `HttpService` class.  `TracingHttpService`  provides better trace metrics
   and handles timed out requests.
2. `KamonHttp`, a drop-in replacement for spray-can’s `Http` Akka I/O
   extension.  It will transparently collect Spray can’s server metrics.

For the rest of the post, we will explore in greater detail what the library
does and how it works.  Finally, we will wrap up by presenting some ideas for
future development.  If you like, you can visit [the project’s page on
GitHub][spray-kamon-metrics] for more details about how to integrate the
library into your application.

[Kamon]: http://www.kamon.io (The Open Source tool for monitoring applications running on the JVM)
[Spray]: http://spray.io/ (Elegant, high-performance HTTP for your Akka Actors)
[kamon-spray]: http://kamon.io/integrations/web-and-http-toolkits/spray/ (Kamon Spray integration)
[spray-kamon-metrics]: https://github.com/MonsantoCo/spray-kamon-metrics (Better metrics for Spray services)


## Improving service metrics with `TracingHttpService`

The `TracingHttpService` fulfils the first two of our goals:

1. Providing better response metrics
2. Detection and tracing of request timeouts


### Providing better response metrics

Kamon’s Spray integration is immensely useful.  However, we felt like the
default behaviour makes it difficult to really understand the application that
is being measured.  In particular:

1. It creates traces for each response, but they all have a default name of
   *UnnamedTrace*.  The intention is for application developers to give
   meaningful names to each response.  However, it would be nice if the library
   provided a more meaningful default.
2. There are metrics collected under the `http-server` category, but they only
   contain the trace name and resulting status code, and it is not easily to
   correlate the `http-server` metrics with corresponding traces, especially if
   we have not given the traces meaningful names.

While we could have resolved these issues to some extent by [providing a name
generator][pang], the core problem was that, even with more meaningful names,
there is no way to add tags to a trace that has already been established.  As a
result, the dimensionality of the metrics that are produced are restricted to
trace name and response status code.  We want more, including:

* What was the method of the request, e.g. `GET` or `POST`?
* What was the path of the request?
* Did the request time out?

At first we considered modifying the kamon-spray library, but it works by using
AspectJ.  That’s great because it means we can use it without making any
changes to our application.  Unfortunately, it also means that in order to be
able to use it, you need to have knowledge of both AspectJ and a very deep
understanding of the code you are trying to instrument (in this case, Spray
routing).  We had neither, so we opted to try something else.  However, in the
long run, moving spray-kamon-metrics’ functionality into kamon-spray seems like
a good idea.

Next, we looked to see if we could just create a new directive that captures
the information we wanted.  Thus, we could theoretically just do something like:

```scala
class ServiceActor extends HttpServiceActor {
  override def receive =
    runRoute {
      withKamonMetrics {
        serviceRoute
      }
    }
}
```

This works most of the time, but if the request results in an error or a
rejection, it fails.  The reason for this is that in the case of rejections and
errors not handled explicitly by the route, the route does not produce the
resulting `HttpResponse`.  As shown in [figure 1][fig1], when you use
`runRoute`, it *seals* your route with implicitly given rejection and exception
handlers.  It is these handlers that actually generate the `HttpResponse`
object that is sent to the client.

<figure>
  <figcaption><a name="fig1">Figure 1</a>: How <code>HttpService</code> handles rejections and exceptions</figcaption>
  <img src="/img/spray-kamon-http-service-base.png"
       alt="How HttpService handles rejections and exceptions">
</figure>

While it is possible to provide custom handlers, it becomes very difficult to
manage state (in particular, start time) across all of these different places.
We could make the directive itself provide rejection and exception handling,
but that departs from the norm and also does not solve the problem with
managing state.

In the end, what we decided to do is to replace `HttpService` with
`TracingHttpService`, which is largely identical to `HttpService`, the biggest
difference being in how it seals routes:

```scala
// from HttpService
def sealRoute(route: Route)(implicit eh: ExceptionHandler, rh: RejectionHandler): Route =
  (handleExceptions(eh) & handleRejections(sealRejectionHandler(rh)))(route)

// from TracingHttpService (simplified, no timeout handling included)
def sealRoute(route: Route)(implicit eh: ExceptionHandler, rh: RejectionHandler): Route = {
  mapRequestContext { ctx: RequestContext =r
    val path = ctx.request.uri.path.toString()
    val method = ctx.request.method.name
    val start = System.nanoTime()
    val tagBuilder = Map.newBuilder[String, String]
    tagBuilder += "path" -> path
    tagBuilder += "method" -> method
    ctx.withHttpResponseMapped { response =>
      val duration = System.nanoTime() - start
      tagBuilder += "status-code" -> response.status.intValue.toString
      Kamon.metrics.histogram(
           "spray-service-response-duration",
           tagBuilder.result(),
           Time.Nanoseconds)
        .record(duration)
      response
    }
  } {
    (handleExceptions(eh) & handleRejections(sealRejectionHandler(rh)))(route)
  }
}
```

As we can see, `HttpService.sealRoute` is simply a higher order function that wraps
a route with exception and rejection handlers.  In the case of
`TracingHttpService`, `sealRoute` just adds another wrap to the mix.  It still
wraps the route with the handlers, but it adds its own wrapper around that.
Before the internally sealed route runs, it records the start time and starts
building a set of tags.  Once the internal route completes, it records the
timing to a Kamon histogram.

Because we include these various tags, the metrics we collect are now much
richer.  It is now possible to filter and analyse the metrics based on the
tags, allowing us to answer questions such as ‘which types of request
(method/path) are resulting in errors?’ and ‘What is the average response time
for a particular type of request?’.

Additionally, creating our own version of `HttpService` allowed us to tackle
the next issue we had:  How do we know when a request times out?

[fig1]: #fig1 (How HttpService handles rejections and exceptions)
[PAng]: http://kamon.io/integrations/web-and-http-toolkits/spray/#providing-a-name-generator (Kamon Spray integration: Providing a Name Generator)


### Detecting requests that time out

Due to the asynchronous nature of the Spray server, [the way it handles request
timeouts][spray-timeouts] may be surprising to newcomers.

<figure>
  <figcaption><a name="fig2">Figure 2</a>: How Spray times out routes</figcaption>
  <img src="/img/spray-kamon-timeouts.png"
       alt="How Spray times out routes">
</figure>

[Figure 2][fig2] presents an overview of how Spray works (in particular, the
timeout route itself can time out, resulting in an invocation of a last ditch
timed out timeout route).  In particular there are couple of things to note:

1. A route will continue running until it completes, regardless of how long it
   is taking.  This may have an impact performance and resource utilisation.
   Unfortunately, Spray does not include any sort of mechanism for cooperative
   cancellation.
2. Spray invokes the timeout handler via a different mechanism than a standard
   request.

As a result of this, the instrumentation built into kamon-spray is completely
blind to the timeout mechanism.  It will record a requested that timed out as
if it completed normally, and it will not generate a trace.  In fact, that is a
reason for `EmptyTraceContext present while closing the trace with token`
showing up in your logs.

We want to measure both cases:

1. If a request times out, we want to make a note of it so we can see which
   requests are timing out and with what status code (is the timeout too short
   for what we need to do, or is hanging due to an error?).
2. We also want to know about the timeout responses, as they should be
   aggregated to response time and error count metrics.

To help us account for timeouts, we modify our `sealRoute` implementation:

```scala
def sealRoute(route: Route, timeoutNanos: Long, isTimeout: Boolean)
             (implicit eh: ExceptionHandler, rh: RejectionHandler): Route = {
  mapRequestContext { ctx: RequestContext =>
    val path = ctx.request.uri.path.toString()
    val method = ctx.request.method.name
    val start = System.nanoTime()
    val tagBuilder = Map.newBuilder[String, String]
    tagBuilder += "path" -> path
    tagBuilder += "method" -> method
    ctx.withHttpResponseMapped { response =>
      val duration = System.nanoTime() - start
      tagBuilder += "status-code" -> response.status.intValue.toString
      val timedOut = duration > timeoutNanos
      tagBuilder += "timed-out" -> timedOut.toString
      val realDuration = if (isTimeout) duration + timeoutNanos else duration
      Kamon.metrics.histogram(
          "spray-service-response-duration",
          tagBuilder.result(),
          Time.Nanoseconds)
        .record(realDuration)
      response
    }
  } {
    (handleExceptions(eh) & handleRejections(sealRejectionHandler(rh)))(route)
  }
}
```

A couple of notes about this method:

1. This method is called both when handling the regular route and when handling
   the timeout route.  The `isTimeout` flag lets us know which if the two we
   are handling.
2. We do not know for a fact that a non-timeout response timed out.  We use the
   heuristic that if the duration is greater than the request timeout, the
   request probably timed out.
3. Measuring an accurate duration for a timeout route is similarly tricky.  The
   duration we calculate is only for the timeout route and does _not_ include
   the time that elapsed between when the request arrived and the timeout route
   was invoked.  As an approximation, we simply add the configured request
   timeout length to the measured duration.

With this code in place, now our `TracingHttpService` implementation will
now measure:

* Durations for all regular and timeout responses
* For each response:
    * The request method and path
    * The response status code
    * Did the response time out?

This data gives us a much better picture of what clients are experiencing and
helps us identify problematic routes within our services.  Now, we just want to
know a little more about the metrics the Spray can server itself is collecting.

[fig2]: #fig2 (How Spray times out routes)
[spray-timeouts]: http://spray.io/documentation/1.2.3/spray-can/http-server/#request-timeouts (Spray can: HTTP server: request timeouts)


## Getting Spray can server metrics with `KamonHttp`

The Spray can server automatically collects some statistic about its operation
and [provides a method for retrieving them][spray-metrics].  Hooking up these
metrics to Kamon  essentially requires two steps:

1. When a server socket is established, set up a job that periodically asks the
   server for its latest statistics.
2. Each time those statistics are collected, update a Kamon entity with their
   values.

This is not difficult to do, but neither is it a one-liner that can be
trivially done.  Arguably, the trickiest bit is setting up the job that will
monitor the server.  To review, you set up a new server by sending an
`Http.Bind` message the Spray can’s `Http` Akka I/O extension.

```scala
IO(Http) ! Http.Bind(myServiceActor, interface = "localhost", port = 80)
```

The tricky bit is that we need to capture the reference to the actor that
replies to this message, which the application may never do.  Furthermore, if
the application does want to get a reference to the responder, the library
should not interfere with that.  What is the solution?

[spray-metrics]: http://spray.io/documentation/1.2.3/spray-can/http-server/#server-statistics (Spray can: HTTP server: server statistics)


### Proxying Spray

The solution we settled on was to create a new Akka I/O extension that proxies
the Spray extension, which sounds much more complex than it actually is.  To do
this,  there is a little bit of boilerplate to ensure that Akka will find the
extension, but, beyond that, an Akka extension is just an actor.  For
`KamonHttp`, this actor is called `SprayProxy`, a slightly simplified version
of which is listed below:

```scala
class SprayProxy extends Actor {
  import constext.system

  private val ioActor = IO(Http)

  override def receive = {
    case x: Http.Bind =>
      val proxied = sender()
      val monitor = context.actorOf(SprayMonitor.props(proxied))
      ioActor.tell(x, monitor)
    case x => ioActor.forward(x)
  }
}
```

This class instantiates an instance of Spray’s extension and stores it in
`ioActor`.  From that point forward, this actor does one of two things:

1. If a `Http.Bind` message arrives, instantiate a `SprayMonitor` actor, which
   we will cover next.  As part of this, we pass in a reference to the actor
   that sent the original message.  Finally, we send the `Http.Bind` message to
   Spray, but do so in a matter so that Spray believes that the monitor actor
   we just created was the original sender.
2. For any other message, we simply forward it to Spray without changing the
   sender, rendering our extension invisible.


### Monitoring Spray

Next, let us review what this Spray monitor does.  This actor is slightly more
complex.  It exists in one of two states:

1. The initial state is _binding_, which means we have sent the `Http.Bind`
   message to Spray and we are waiting to hear the result of the operation.
2. In the _bound_ state, the server is up and running and we periodically poll
   it for its statistics.

These two states exist as methods on the actor, each of which returns a
`Receive`.  Let’s take a look at `binding` first.

```scala
def bindind: Receive = {
  case x: Http.CommandFailed =>
    proxied.forward(x)
    context.stop(self)
  case x @ Http.Bound(address) =>
    proxied.forward(x)
    context.become(bound(address))
}
```

In this state, we have handle two possible messages: `Http.Bound` and
`Http.CommandFailed`.  These indicate whether Spray succeeded in binding a new
server.  In both cases, we forward the message to the original sender of the
`Http.Bind` message, rendering our proxy effectively invisible.  In the case
were the bind fails, we simply shut down.  In the case where the bind
succeeded, we `become` into the bound state, which we will examine next.

```scala
def bound(address: InetSocketAddress): Receive = {
  import context.dispatcher

  val httpListener = sender()
  context.watch(httpListener)

  val updateTask = context.system.scheduler.schedule(
    15 seconds, 15 seconds, httpListener, Http.Getstats)
  val metricsName = s"${address.getHostName}:${address.getPort}"
  val metrics = Kamon.metrics.entity(SprayServerMetrics, metricsName)

  {
    case _: Terminated =>
      updateTask.cancel()
      Kamon.metrics.removeEntity(metricsName, SprayServerMetrics.category)
      context.stop(self)
    case s: Stats =>
      metrics.updateStats(s)
  }
}
```

When we become `bound`, a few things take place:

1.  We capture the reference to the sender of the `Http.Bound` message.  This is
    the _HTTP listener_ actor which handles all connections to that particular
    server.
2.  We start watching the listener.  When it dies, that means the server has
    died, so we should stop monitoring and shut down.
3.  We schedule a task that will send the listener a `Http.GetStats` every 15
    seconds (this is configurable in the real code).  Keep in mind that when we
    create this task, it uses the `self` implicit value as the sender, meaning
    that as far as the listener is concerned, it is the monitor that is sending
    these messages.
4.  We instantiate a Kamon entity we created specifically for recording the
    Spray server metrics.  Its name is generated from the host name and port
    where the server is listening.
5.  Finally we have the partial function that handles the two types of messages
    that our actor will receive from this point forward:
    -   When we get a `Terminated` message, that means the server has stopped.
        As a result, we clean up by cancelling the recurring task, removing the
        Kamon entity, and finally stopping ourselves.
    -   In the case where we get new `Stats`, we update the Kamon entity with
        the new values.

All in all, this code is relatively straightforward.  However, we are not quite
done, yet.  Updating the Kamon entity’s metrics was not as straightforward as
we initially thought.


### Reporting the statistics to Kamon

It might seem like having dealt with all of the Akka bits, we would be out of
the woods.  However, it turned out that what Spray is reporting is not entirely
in line with how Kamon’s instruments behave.  Spray reports the following
statistics:

* `connections`, the total number of connections over time
* `open-connections`, the number of currently open connections
* `max-open-connections`, the maximum number of open connections ever
* `requests`, the total number of requests over time
* `open-requests`, the number of currently open requests
* `max-open-requests`, the maximum number of open requests ever
* `request-timeouts`, the total number of request timeouts over time
* `uptime`, the current uptime of the server, in nanoseconds

Most of these fit nicely into one of Kamon’s instrument types:

* `connections`, `requests`, and `request-timeouts` all work will as Kamon
  counters, which must be strictly increasing, and are reported as time-series
  data
* `open-connections` and `open-requests` are conceptually gauges, but given
  that we are already dealing with sampled data, we decide to map these to
  Kamon histograms.

This leaves:

* We could have treated `max-open-connections` and `max-open-requests` like
  their non-max counterparts, but given that these values rarely change, we
  really only want to report the latest value.
* `uptime`, which is conceptually a type of counter, but we do not want that to
  be reported as time-series data, i.e.  the server was up 15 seconds in the
  last 15 seconds.  We really want to report the latest value.

So how, did we deal with this?  Well, for the most part, we just [defined our
own entity recorder][dyoer].  However, it does contains a couple of twists
worth sharing:

```scala
class SprayServerMetrics(instrumentFactory: InstrumentFactory)
  extends GenericEntityRecorder(instrumentFactory) {
  private val stats = new AtomicReference[Stats](new Stats(0.nanoseconds, 0, 0, 0, 0, 0, 0, 0))
  private val connections = counter("connections")
  private val openConnections = histogram("open-connections")
  private val requests = counter("requests")
  private val openRequests = histogram("open-requests")
  private val requestTimeouts = counter("request-timeouts")

  override def collect(collectionContext: CollectionContext): EntitySnapshot

  def updateStats(newStats: Stats): Unit
}
```

We keep a copy of the most recent statistics, starting with a value of all
zeroes.  Next, for the metrics that map nicely to Kamon’s instruments, we do
that.


```scala
override def collect(collectionContext: CollectionContext): EntitySnapshot = {
  val parentSnapshot = super.collect(collectionContext)
  val metrics = parentSnapshot.metrics ++ Map(
    counterKey("uptime", Time.Nanoseconds) → CounterSnapshot(stats.uptime.toNanos),
    counterKey("max-open-connections") → CounterSnapshot(stats.maxOpenConnections),
    counterKey("max-open-requests") → CounterSnapshot(stats.maxOpenRequests)
  )
  new DefaultEntitySnapshot(metrics)
}
```

When it is time for Kamon to `collect` the values for our entity, that is were
things get a little tricky.  We need to do a combination of both the default
behaviour for the Kamon-friendly statistics along with some custom behaviour
for those that are not.  Luckily this was not too difficult:

1. We invoke the parent class’s `collect` method to get a snapshot that
   includes all of the Kamon-friendly statistics.
2. From that snapshot, we can get the recorded instrument snapshot and append
   to it fabricated instrument snapshots with the values that we want.  We use
   report `uptime`, `max-open-connections`, and `max-open-requests` as
   counters.
3. Finally, we construct a new snapshot with our custom metrics.

Last, we just need to be sure to deal with the updates:

```scala
def updateStats(newStats: Stats): Unit = {
  openConnections.record(newStats.openConnections)
  openRequests.record(newStats.openRequests)
  connections.increment(newStats.totalConnections - stats.totalConnections)
  requests.increment(newStats.totalRequests - stats.totalRequests)
  requestTimeouts.increment(newStats.requestTimeouts - stats.requestTimeouts)
  stats = newStats
}
```
The implementation here should not come as a surprise.

1. Both `open-connections` and `open-requests` are histograms, so we just
   record their new values.
2. For `connections`, `requests`, and `request-timeouts`, we simply record how
   much each of these has increased since the last time.
3. Finally, we keep a copy of the statistics.  Note that we do not have to do
   anything for the other values as those metrics are generated during
   `collect`.

And that is how we take the statistics from Spray to report them from a custom
Kamon entity recorder.


[dyoer]: http://kamon.io/core/metrics/core-concepts/#defining-your-own-entity-recorder (Kamon metrics, core concepts: Defining your entity recorder)


## Moving forward

We are generally pretty happy with our work in spray-kamon-metrics, but that is
not to say there is not room for improvement.  A few of ideas come to mind:

1. Figure out if there is a better way to handle request timeouts.
2. See if it is possible to implement any of this using AspectJ, making it as
   simple to use as kamon-spray.
3. Especially if we can acheive the last goal, perhaps it would be good to
   merge this into `kamon-spray` itself.

Can you think of anything else you like the library to do?
