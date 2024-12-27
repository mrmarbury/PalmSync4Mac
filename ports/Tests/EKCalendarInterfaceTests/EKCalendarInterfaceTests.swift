import XCTest
@testable import EKCalendarInterface
import EventKit

class MockEKEvent: EKEvent {
    private let mockID: String
    
    override var eventIdentifier: String {
        return mockID
    }
    
    init(eventStore: EKEventStore, identifier: String) {
        self.mockID = identifier
        super.init(eventStore: eventStore)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}

final class CalendarEventsTests: XCTestCase {

    var mockStore: MockEventStore!

    override func setUp() {
        super.setUp()
        
        mockStore = MockEventStore()
        
        var store = mockStore
    }

    override func tearDown() {
        var store = EKEventStore()
        
        mockStore = nil

        super.tearDown()
    }

    func captureOutput(_ block: (FileHandle) async -> Void) async -> String {
        let pipe = Pipe()
        let fileHandle = pipe.fileHandleForWriting
        
        await block(fileHandle)
        
        fileHandle.closeFile()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
    
    
    func testAccessDenied() async {
        mockStore.shouldGrantAccess = false
        
        let output = await captureOutput { handle in
            await getCalendarEvents(days: 0, calendar: nil, requestId: 999)
        }
        
        XCTAssertTrue(output.contains("\"error\": \"access_denied\""))
        XCTAssertTrue(output.contains("\"request_id\": 999"))
    }

    func testCalendarNotFound() async {
        mockStore.shouldGrantAccess = true

        let output = await captureOutput { handle in
            await getCalendarEvents(days: 3, calendar: "NonExistent", requestId: 123)
        }
        
        XCTAssertTrue(output.contains("\"error\": \"calendar_not_found\""))
        XCTAssertTrue(output.contains("\"request_id\": 123"))
    }

    func testCalendarFoundNoEvents() async {
        mockStore.shouldGrantAccess = true
        
        let testCalendar = EKCalendar(for: .event, eventStore: mockStore)
        testCalendar.title = "Test Calendar"
        mockStore.mockCalendars = [testCalendar]

        let output = await captureOutput { handle in
            await getCalendarEvents(days: 2, calendar: "Test Calendar", requestId: 789)
        }

        XCTAssertTrue(output.contains("\"events\":"))
        XCTAssertTrue(output.contains("\"request_id\": 789"))
        
        if let jsonData = output.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let events = jsonObject["events"] as? [[String: Any]] {
            XCTAssertTrue(events.isEmpty, "Expected zero events from the mock.")
        } else {
            XCTFail("Unable to parse JSON or missing 'events' array.")
        }
    }

    func testCalendarFoundWithEvents() async {
        mockStore.shouldGrantAccess = true

        let calendar = EKCalendar(for: .event, eventStore: mockStore)
        calendar.title = "Work"
        mockStore.mockCalendars = [calendar]

        class LocalMockStore: MockEventStore {
            override func events(matching predicate: NSPredicate) -> [EKEvent] {
                let e1 = MockEKEvent(eventStore: self, identifier: "evt1")
                e1.title     = "Meeting"
                e1.startDate = Date()
                e1.endDate   = Date().addingTimeInterval(3600)
                e1.calendar  = mockCalendars.first
                
                let e2 = MockEKEvent(eventStore: self, identifier: "evt2")
                e2.title     = "Code Review"
                e2.startDate = Date().addingTimeInterval(7200)
                e2.endDate   = Date().addingTimeInterval(10800)
                e2.calendar  = mockCalendars.first
                
                return [e1, e2]
            }
        }
        
        let localMock = LocalMockStore()
        localMock.shouldGrantAccess = true
        localMock.mockCalendars = [calendar]
        
        var store = localMock

        let output = await captureOutput { handle in
            await getCalendarEvents(days: 7, calendar: "Work", requestId: 555)
        }
        
        guard let jsonData = output.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let events = jsonObject["events"] as? [[String: Any]]
        else {
            XCTFail("JSON parsing failed.")
            return
        }

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0]["apple_event_id"] as? String, "evt1")
        XCTAssertEqual(events[1]["apple_event_id"] as? String, "evt2")
        XCTAssertEqual(jsonObject["request_id"] as? Int, 555)
    }
}

