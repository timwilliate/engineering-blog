package com.monsanto.engineering_blog.testing_without_mocking

import com.monsanto.engineering_blog.testing_without_mocking.JsonStuff._
import org.scalatest.FunSpec

import scala.concurrent.{Await, Future}
import spray.json._
import spray.json.DefaultJsonProtocol._
import scala.concurrent.duration._

import scala.concurrent.ExecutionContext.Implicits.global

class IdentityClientTest extends FunSpec {

  describe("the IdentityClient") {

    it("returns a Identity when received") {
      val jsonBody = Map("identity" -> Map("id" -> "external_username")).toJson
      val identityClient = new IdentityClient(_ => Future(JsonResponse(OkStatus, jsonBody)))

      Await.result(identityClient.fetchIdentity("an_access_token"), 1.second) ===
        Some(Identity("external_username"))
    }
  }


  it("returns None when it gives us a 400 due to bad access token") {
    val identityClient = new IdentityClient(_ => Future(JsonResponse(BadStatus, Map[String,String]().toJson)))

    Await.result(identityClient.fetchIdentity("an_access_token"), 1.second) ===
      Some(None)
  }

}
