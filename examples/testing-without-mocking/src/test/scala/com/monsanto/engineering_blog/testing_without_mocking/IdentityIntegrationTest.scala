package com.monsanto.engineering_blog.testing_without_mocking

import java.net.URL

import com.monsanto.engineering_blog.testing_without_mocking.JsonStuff.JsonClient
import org.scalatest.FunSpec


class IdentityIntegrationTest extends FunSpec {

  import IdentityClient._

  "Foo".capitalize

  // assuming the other service is running!

  describe("real life") {
    it("can make a call out to the real service") {

      val getRealInput = RealAccessTokenService.reallyCheckAccessToken(new JsonClient(new URL("http://whereisit"))) _

      // perform actual test
      fetchIdentity(getRealInput("realAccessToken"))
    }
  }

}
