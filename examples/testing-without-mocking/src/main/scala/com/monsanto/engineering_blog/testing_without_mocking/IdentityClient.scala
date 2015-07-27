package com.monsanto.engineering_blog.testing_without_mocking

import com.monsanto.engineering_blog.testing_without_mocking.JsonStuff._

import scala.concurrent.Future

import scala.concurrent.ExecutionContext.Implicits.global

class IdentityClient(jsonClient: JsonClient)  {

  def fetchIdentity(accessToken: String) : Future[Option[Identity]] = {
    jsonClient.getWithoutSession(
      Path("/identity"),
      Params("access_token" -> accessToken)
    ).map {
      case JsonResponse(OkStatus, json) => Some(Identity.from(json))
      case _ => None
    }
  }
}
