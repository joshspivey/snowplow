/*
 * Copyright (c) 2012-2013 SnowPlow Analytics Ltd. All rights reserved.
 *
 * This program is licensed to you under the Apache License Version 2.0,
 * and you may not use this file except in compliance with the Apache License Version 2.0.
 * You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the Apache License Version 2.0 is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.
 */
package com.snowplowanalytics.snowplow.enrich.hadoop
package enrichments

// Specs2 & ScalaCheck
import org.specs2.mutable.{Specification => MutSpecification}
import org.specs2.{Specification, ScalaCheck}
import org.specs2.matcher.DataTables
import org.scalacheck._

// Scalaz
import scalaz._
import Scalaz._

/**
 * Tests the etlVersion variable.
 * Uses mutable.Specification.
 */
class EtlVersionTest extends MutSpecification {

  "The ETL version" should {
    "be successfully returned" in {
      MiscEnrichments.etlVersion must_== "hadoop-0.3.1"
    }
  }
}

/**
 * Tests the extractPlatform function.
 * Uses DataTables.
 */
class ExtractPlatformTest extends Specification with DataTables {

  val FieldName = "p"
  def err: (String) => String = input => "Field [%s]: [%s] is not a supported tracking platform".format(FieldName, input)

  def is =
    "Extracting platforms with extractPlatform should work" ! e1

  def e1 =
    "SPEC NAME"                      || "INPUT VAL" | "EXPECTED OUTPUT" |
    "valid web"                      !! "web"       ! "web".success     |
    "valid iot (internet of things)" !! "iot"       ! "iot".success     |
    "invalid empty"                  !! ""          !  err("").fail     |
    "invalid null"                   !! null        !  err(null).fail   |
    "invalid platform"               !! "ma"        !  err("ma").fail   |> {

      (_, input, expected) => MiscEnrichments.extractPlatform(FieldName, input) must_== expected
    }
}

/**
 * Tests the identity function.
 * Uses ScalaCheck.
 */
class IdentityTest extends Specification with ScalaCheck {

  def is =
    "The identity function should work for any pair of Strings" ! e1

  def e1 =
    check { (field: String, value: String) => MiscEnrichments.identity(field, value) must_== value.success }
}