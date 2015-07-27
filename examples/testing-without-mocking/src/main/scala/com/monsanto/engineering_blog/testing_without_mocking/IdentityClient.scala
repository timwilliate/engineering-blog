package com.monsanto.engineering_blog.testing_without_mocking

import com.monsanto.engineering_blog.testing_without_mocking.JsonStuff._

import scala.concurrent.Future

import scala.concurrent.ExecutionContext.Implicits.global

class IdentityClient(howToCheck: String => Future[JsonResponse])  {

  def fetchIdentity(accessToken: String) : Future[Option[Identity]] = {
    howToCheck(accessToken).map {
      case JsonResponse(OkStatus, json) => Some(Identity.from(json))
      case _ => None
    }
  }

}
