package com.monsanto.engineering_blog.testing_without_mocking

import com.monsanto.engineering_blog.testing_without_mocking.JsonStuff._

import scala.concurrent.Future

object RealAccessTokenService {

  def reallyCheckAccessToken(jsonClient:JsonClient)(accessToken: String): Future[JsonResponse] = jsonClient.getWithoutSession(
    Path("identity"),
    Params("access_token" -> accessToken)
  )


}
