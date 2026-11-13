//
//  SubtitleParserTests.swift
//  Ororo-KitTests
//
//  Created by Max Ovtsin on 9/12/18.
//  Copyright © 2018 Max Ovtsin. All rights reserved.
//

import XCTest
@testable import OroroKit

class SubtitleParserTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func test_GivenStringWithVTT_ThenItShouldBeParsed() {
        let payload = """
                        WEBVTT\n\n
                        1\n00:02:51.000 --> 00:02:53.000\nCome, </br>come!<br>\n\n
                        2\n00:02:57.000 --> 00:02:59.000\n</i>Please!<i>\n\n
                      """

        let intervals = SubtitleParser.parse(payload: payload)

        XCTAssert(intervals.count == 2, "Must be equal to 3")

        let interval1 = intervals[0]
        XCTAssert(interval1.text == "Come, come!", "Text is wrong")
        XCTAssert(interval1.from == 171, "From label is wrong")
        XCTAssert(interval1.to == 173, "To label is wrong")

        let interval2 = intervals[1]
        XCTAssert(interval2.text == "Please!", "Text is wrong")
        XCTAssert(interval2.from == 177, "From label is wrong")
        XCTAssert(interval2.to == 179, "To label is wrong")
    }

    func test_GivenStringWithMarkupAndEntities_ThenOnlyDialogueRemains() {
        let payload = """
                        WEBVTT\n\n
                        1\n00:00:01.000 --> 00:00:02.000\n<font face="Trebuchet MS" size="24">Hello there</font>\n\n
                        2\n00:00:03.000 --> 00:00:04.000\n{\\an8}He said &quot;run&quot; &amp; hide\n\n
                        3\n00:00:05.000 --> 00:00:06.000\n<b>Bold</b> and <span style="color: red;">red</span>\n\n
                        4\n00:00:07.000 --> 00:00:08.000\nFirst<BR/>second\n\n
                      """

        let intervals = SubtitleParser.parse(payload: payload)

        XCTAssert(intervals.count == 4, "Must be equal to 4")
        XCTAssert(intervals[0].text == "Hello there", "Font tag must be stripped")
        XCTAssert(intervals[1].text == "He said \"run\" & hide", "Entities and ASS overrides must be decoded")
        XCTAssert(intervals[2].text == "Bold and red", "Attributed tags must be stripped")
        XCTAssert(intervals[3].text == "First\nsecond", "Line breaks must survive as newlines")
    }
}
