package com.monsanto.engineering_blog.testing_without_mocking

import com.monsanto.engineering_blog.testing_without_mocking.JsonStuff._
import org.scalatest.FunSpec

import scala.concurrent.{Await, Future}
import spray.json._
import spray.json.DefaultJsonProtocol._
import scala.concurrent.duration._
import org.scalamock.scalatest.MockFactory

import scala.concurrent.ExecutionContext.Implicits.global

class IdentityClientTest extends FunSpec with MockFactory {

  describe("IdentityClient") {
    it("returns a Identity when received") {
      val jsonClient = mock[JsonClient]
      val path = Path("/identity")
      val params = Params("access_token" -> "an_access_token")
      val identityClient = new IdentityClient(jsonClient)
      val jsonBody = Map("identity" -> Map("id" -> "external_username")).toJson
      (jsonClient.getWithoutSession _).expects(path, params).returning(Future(
        JsonResponse(OkStatus, jsonBody)))

      Await.result(identityClient.fetchIdentity("an_access_token"), 1.second) ===
        Some(Identity("external_username"))
    }
  }
}
