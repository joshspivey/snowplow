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
package com.snowplowanalytics.snowplow.hadoop.hive

// Specs2
import org.specs2.mutable.Specification

// SnowPlow Utils
import com.snowplowanalytics.util.Tap._

// Deserializer
import test.{SnowPlowDeserializer, SnowPlowEvent, SnowPlowTest}

class StructEventTest extends Specification {

  // Toggle if tests are failing and you want to inspect the struct contents
  implicit val _DEBUG = false

  // Transaction item
  val row = "2012-05-27  11:35:53  DFW3  3343  99.116.172.58 GET d3gs014xn8p70.cloudfront.net  /ice.png  200 http://www.psychicbazaar.com/2-tarot-cards/genre/all/type/all?p=5 Mozilla/5.0%20(Windows%20NT%206.1;%20WOW64;%20rv:12.0)%20Gecko/20100101%20Firefox/12.0  &e=ev&ev_ca=Mixes&ev_ac=Play&ev_la=MRC%2Ffabric-0503-mix&ev_pr=mp3&ev_va=0.0&tid=191001&duid=ea7de42957742fbb&vid=1&aid=CFe23a&lang=en-GB&f_pdf=0&f_qt=1&f_realp=0&f_wma=1&f_dir=0&f_fla=1&f_java=1&f_gears=0&f_ag=0&res=1920x1080&cookie=1&url=file%3A%2F%2F%2Fhome%2Falex%2Fasync.html"
  val expected = new SnowPlowEvent().tap { e =>
    e.dt = "2012-05-27"
    e.collector_dt = "2012-05-27"
    e.collector_tm = "11:35:53"
    e.event = "struct" // Structured event
    e.event_vendor = "com.snowplowanalytics"
    e.txn_id = "191001"
    e.ev_category = "Mixes"
    e.ev_action = "Play"
    e.ev_label = "MRC/fabric-0503-mix"
    e.ev_property = "mp3"
    e.ev_value = "0.0"
  }

  "The SnowPlow event row \"%s\"".format(row) should {

    val actual = SnowPlowDeserializer.deserialize(row)

    // General fields
    "have dt (Legacy Hive Date) = %s".format(expected.dt) in {
      actual.dt must_== expected.dt
    }
    "have collector_dt (Collector Date) = %s".format(expected.collector_dt) in {
      actual.collector_dt must_== expected.collector_dt
    }
    "have collector_tm (Collector Time) = %s".format(expected.collector_tm) in {
      actual.collector_tm must_== expected.collector_tm
    }
    "have event (Event Type) = %s".format(expected.event) in {
      actual.event must_== expected.event
    }
    "have event_vendor (Event Vendor) = %s".format(expected.event_vendor) in {
      actual.event_vendor must_== expected.event_vendor
    }
    "have a valid (stringly-typed UUID) event_id" in {
      SnowPlowTest.stringlyTypedUuid(actual.event_id) must_== actual.event_id
    }
    "have txn_id (Transaction ID) = %s".format(expected.txn_id) in {
      actual.txn_id must_== expected.txn_id
    }

    // The event fields
    "have ev_category (Event Category) = %s".format(expected.ev_category) in {
      actual.ev_category must_== expected.ev_category
    }
    "have ev_action (Event Action) = %s".format(expected.ev_action) in {
      actual.ev_action must_== expected.ev_action
    }
    "have ev_label (Event Label) = %s".format(expected.ev_label) in {
      actual.ev_label must_== expected.ev_label
    }
    "have ev_property (Event Property) = %s".format(expected.ev_property) in {
      actual.ev_property must_== expected.ev_property
    }
    "have ev_value (Event Value) = %s".format(expected.ev_value) in {
      actual.ev_value must_== expected.ev_value
    }
  }
}