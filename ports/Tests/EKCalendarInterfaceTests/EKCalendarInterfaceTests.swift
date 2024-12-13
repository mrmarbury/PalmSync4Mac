import XCTest
import EventKit
@testable import EKCalendarInterface

class CalendarEventTests: XCTestCase {
    var mockEventStore: MockEventStore!

    override func setUp() {
        super.setUp()
        mockEventStore = MockEventStore()
    }

    override func tearDown() {
        mockEventStore = nil
        super.tearDown()
    }

    func testSendMessage() {
        let testMessage = "Test message"
        let expectedOutput = Data([0, 0, 0, UInt8(testMessage.count)]) + testMessage.data(using: .utf8)!

        let outputPipe = Pipe()
        sendMessage(testMessage, to: outputPipe.fileHandleForWriting)

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        XCTAssertEqual(outputData, expectedOutput, "sendMessage() output does not match expected output.")
    }

    func testReadMessageValidInput() {
        let inputMessage = "{\"command\":\"get_events\"}"
        let length = UInt32(inputMessage.count).bigEndian
        var lengthData = Data()
        withUnsafeBytes(of: length) { lengthData.append(contentsOf: $0) }

        let inputPipe = Pipe()
        inputPipe.fileHandleForWriting.write(lengthData + inputMessage.data(using: .utf8)!)

        let result = readMessage(from: inputPipe.fileHandleForReading)
        XCTAssertNotNil(result, "readMessage() should parse valid input correctly.")
        XCTAssertEqual(result?["command"] as? String, "get_events", "Parsed command does not match expected value.")
    }

    func testReadMessageInvalidInput() {
        let inputPipe = Pipe()
        inputPipe.fileHandleForWriting.write(Data([0, 0, 0, 0]))

        let result = readMessage(from: inputPipe.fileHandleForReading)
        XCTAssertNil(result, "readMessage() should return nil for invalid input.")
    }

    func testGetSelectedCalendarsWithName() {
        let calendar = EKCalendar(for: .event, eventStore: mockEventStore)
        calendar.title = "Test Calendar"
        mockEventStore.mockCalendars = [calendar]

        let calendars = getSelectedCalendars(named: "Test Calendar", store: mockEventStore)
        XCTAssertNotNil(calendars, "getSelectedCalendars() should find the specified calendar.")
        XCTAssertEqual(calendars?.first?.title, "Test Calendar", "Calendar name does not match.")
    }

    func testGetSelectedCalendarsWithoutName() {
        let calendars = getSelectedCalendars(named: nil, store: mockEventStore)
        XCTAssertNil(calendars, "getSelectedCalendars() should return nil if no name is specified.")
    }

    func testGetCalendarEventsAccessDenied() async {
        mockEventStore.shouldGrantAccess = false

        let requestId = 123
        await getCalendarEvents(days: 2, calendar: nil, requestId: requestId)

        // Verify the correct error was sent (mock or verify sendMessage output)
    }

    func testGetCalendarEventsValidCalendar() async {
        mockEventStore.shouldGrantAccess = true
        let calendar = EKCalendar(for: .event, eventStore: mockEventStore)
        calendar.title = "Test Calendar"
        mockEventStore.mockCalendars = [calendar]

        let requestId = 123
        await getCalendarEvents(days: 2, calendar: "Test Calendar", requestId: requestId)

        // Verify expected behavior and response
    }

}
