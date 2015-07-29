package com.monsanto.engineering_blog.testing_without_mocking

import com.monsanto.engineering_blog.testing_without_mocking.JsonStuff._

import scala.concurrent.Future

import scala.concurrent.ExecutionContext.Implicits.global

object IdentityClient  {
  def fetchIdentity(accessTokenInfo: Future[JsonResponse]) : Future[Option[Identity]] = {
    accessTokenInfo.map {
      case JsonResponse(OkStatus, json) => Some(Identity.from(json))
      case _ => None
    }
  }
}
