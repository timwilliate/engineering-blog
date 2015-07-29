name := "testing-without-mocking"

version := "1.0"

scalaVersion := "2.11.7"


libraryDependencies ++= Seq (
  "org.scalatest"             %% "scalatest"           % "2.2.4"  % "test"
  ,"io.spray"                   %%  "spray-json"         % "1.3.2"
)