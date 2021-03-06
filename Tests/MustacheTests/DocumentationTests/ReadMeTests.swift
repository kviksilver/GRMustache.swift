// The MIT License
//
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import XCTest
import Mustache
import Foundation
import Bridging

class ReadMeTests: XCTestCase {

// GENERATED: allTests required for Swift 3.0
    static var allTests : [(String, (ReadMeTests) -> () throws -> Void)] {
        return [
            ("testReadmeExample1", testReadmeExample1),
            ("testReadmeExample2", testReadmeExample2),
            ("testReadmeExample3", testReadmeExample3),
            ("testReadMeExampleFormatter1", testReadMeExampleFormatter1),
            ("testReadMeExampleFormatter2", testReadMeExampleFormatter2),
            ("testDemo", testDemo),
        ]
    }
// END OF GENERATED CODE

    override func tearDown() {
        DefaultConfiguration = Configuration()
    }

    func testReadmeExample1() {
        let testBundle = FoundationAdapter.getBundle(for: type(of: self))
        let template = try! Template(named: "ReadMeExample1", bundle: testBundle)
        let data: [String: Any] = [
            "name": "Chris",
            "value": 10000,
            "taxed_value": 10000 - (10000 * 0.4),
            "in_ca": true]
        let rendering = try! template.render(with: Box(data))
        XCTAssertEqual(rendering, "Hello Chris\nYou have just won 10000 dollars!\n\nWell, 6000.0 dollars, after taxes.\n")
    }

    func testReadmeExample2() {
        // Define the `pluralize` filter.
        //
        // {{# pluralize(count) }}...{{/ }} renders the plural form of the
        // section content if the `count` argument is greater than 1.

        let pluralizeFilter = Filter { (count: Int?, info: RenderingInfo) -> Rendering in

            // Pluralize the inner content of the section tag:
            var string = info.tag.innerTemplateString
            if let count = count, count > 1 {
                string += "s"  // naive
            }

            return Rendering(string)
        }


        // Register the pluralize filter for all Mustache renderings:

        Mustache.DefaultConfiguration.registerInBaseContext("pluralize", Box(pluralizeFilter))


        // I have 3 cats.
        let testBundle = FoundationAdapter.getBundle(for: type(of: self))
        let template = try! Template(named: "ReadMeExample2", bundle: testBundle)
        let data = ["cats": ["Kitty", "Pussy", "Melba"]]
        let rendering = try! template.render(with: Box(data))
        XCTAssertEqual(rendering, "I have 3 cats.")
    }

    func testReadmeExample3() {
        // TODO: update example from README.md
        //
        // Allow Mustache engine to consume User values.
        struct User : MustacheBoxable {
            let name: String
            var mustacheBox: MustacheBox {
                // Return a Box that wraps our user, and knows how to extract
                // the `name` key of our user:
                return MustacheBox(value: self, keyedSubscript: { (key: String) in
                    switch key {
                    case "name":
                        return Box(self.name)
                    default:
                        return Box()
                    }
                })
            }
        }

        let user = User(name: "Arthur")
        let template = try! Template(string: "Hello {{name}}!")
        let rendering = try! template.render(with: Box(user))
        XCTAssertEqual(rendering, "Hello Arthur!")
    }

    func testReadMeExampleFormatter1() {
        let percentFormatter = NumberFormatter()
        percentFormatter.locale = Locale(identifier: "en_US_POSIX")
        percentFormatter.numberStyle = .percent

        let template = try! Template(string: "{{ percent(x) }}")
        template.registerInBaseContext("percent", Box(percentFormatter))

        let data = ["x": 0.5]
        let rendering = try! template.render(with: Box(data))
        XCTAssertEqual(rendering, "50%")
    }

    func testReadMeExampleFormatter2() {
        let percentFormatter = NumberFormatter()
        percentFormatter.locale = Locale(identifier: "en_US_POSIX")
        percentFormatter.numberStyle = .percent

        let template = try! Template(string: "{{# percent }}{{ x }}{{/ }}")
        template.registerInBaseContext("percent", Box(percentFormatter))

        let data = ["x": 0.5]
        let rendering = try! template.render(with: Box(data))
        XCTAssertEqual(rendering, "50%")
    }

    func testDemo() {
        let templateString = "Hello {{name}}\n" +
        "Your luggage will arrive on {{format(date)}}.\n" +
        "{{#late}}\n" +
        "Well, on {{format(real_date)}} due to Martian attack.\n" +
        "{{/late}}"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let template = try! Template(string: templateString)
        template.registerInBaseContext("format", Box(dateFormatter))

        let data: [String: Any] = [
            "name": "Arthur",
            "date": NSDate(),
            "real_date": NSDate().addingTimeInterval(60*60*24*3),
            "late": true
        ]
        let rendering = try! template.render(with: Box(data))
        XCTAssert(rendering.characters.count > 0)
    }
}
