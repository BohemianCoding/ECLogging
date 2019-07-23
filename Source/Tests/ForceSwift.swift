//  Created by Hamster on 23/07/2019.
//  Copyright © 2019 Elegant Chaos. All rights reserved.

import XCTest

class ForceSwift: XCTestCase {

    func testForeceSwift() {
        // This is needed in order to get the swift libaries into the ECLoggingTestsMac.xctest bundle
		// Even though "ALWAYS_EMBED" is set, because the swift is needed indirectly by Choclat,
		// that's not enough for it to be loaded.
		XCTAssertTrue(1 == 1)
    }


}
