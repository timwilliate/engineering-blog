package com.monsanto.engineering_blog.testing_without_mocking

import spray.json.JsValue
import spray.json.DefaultJsonProtocol._

case class Identity(username: String)

object Identity {
  def from(json: JsValue): Identity = {
    // this is crappy code to make the example compile. Do not copy.
    val interpreted = json.convertTo[Map[String,Map[String,String]]]
    interpreted.get("identity").flatMap(_.get("id")).map(Identity(_)).get
  }
}
