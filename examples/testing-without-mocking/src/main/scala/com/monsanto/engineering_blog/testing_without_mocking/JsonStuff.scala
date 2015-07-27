package com.monsanto.engineering_blog.testing_without_mocking

import java.net.URL

import spray.json._
import spray.json.DefaultJsonProtocol._

import scala.concurrent.Future
import scala.concurrent.ExecutionContext.Implicits.global

object JsonStuff {

  // a pretend web framework to make the example compile

  trait JsonStatus
  case object OkStatus extends JsonStatus
  case object BadStatus extends JsonStatus

  case class JsonResponse(status: JsonStatus, body: JsValue)

  case class Path(to: String)
  case class Params(one: (String,String))

  class JsonClient(rootURL: URL){
    def getWithoutSession(path: Path, params: Params) : Future[JsonResponse] = {
      // pretend this makes a real service call
      Future(JsonResponse(OkStatus, Map("identity" -> Map("id" -> "whatever")).toJson))
    }
  }
}
