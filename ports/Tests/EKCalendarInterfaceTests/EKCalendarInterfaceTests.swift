import XCTest
@testable import EKCalendarInterface
import EventKit

final class CalendarEventsTests: XCTestCase {

    var mockStore: MockEventStore!
    var savedOutputHandle: FileHandle?

    override func setUp() {
        super.setUp()
        mockStore = MockEventStore()
        store = mockStore
        savedOutputHandle = outputHandle
    }

    override func tearDown() {
        if let saved = savedOutputHandle {
            outputHandle = saved
        }
        store = EKEventStore()
        mockStore = nil
        savedOutputHandle = nil
        super.tearDown()
    }

    // MARK: - Helpers

    func withCapturedOutput(_ block: () async -> Void) async -> String {
        let pipe = Pipe()
        outputHandle = pipe.fileHandleForWriting

        await block()

        pipe.fileHandleForWriting.closeFile()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard data.count >= 4 else { return "" }
        let payload = data.subdata(in: 4..<data.count)
        return String(data: payload, encoding: .utf8) ?? ""
    }

    func withRawCapturedOutput(_ block: () async -> Void) async -> Data {
        let pipe = Pipe()
        outputHandle = pipe.fileHandleForWriting

        await block()

        pipe.fileHandleForWriting.closeFile()
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }

    func captureError(_ block: () -> Void) -> String {
        let tmpFile = NSTemporaryDirectory() + "ektest_stderr_\(UUID().uuidString)"
        let originalStderr = dup(STDERR_FILENO)
        freopen(tmpFile, "w", stderr)

        block()

        fflush(stderr)
        dup2(originalStderr, STDERR_FILENO)
        close(originalStderr)

        let data = FileManager.default.contents(atPath: tmpFile)
        try? FileManager.default.removeItem(atPath: tmpFile)
        guard let data = data, data.count >= 4 else {
            return data.map { String(decoding: $0, as: UTF8.self) } ?? ""
        }
        let payload = data.subdata(in: 4..<data.count)
        return String(data: payload, encoding: .utf8) ?? ""
    }

    func createInputPipe(with json: [String: Any]) -> FileHandle {
        let pipe = Pipe()
        let writeHandle = pipe.fileHandleForWriting
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
            var length = UInt32(jsonData.count).bigEndian
            let lengthData = Data(bytes: &length, count: 4)
            writeHandle.write(lengthData + jsonData)
        } catch {
            XCTFail("Failed to serialize JSON: \(error)")
        }
        writeHandle.closeFile()
        return pipe.fileHandleForReading
    }

    // MARK: - Existing Tests (Fixed)

    func testAccessDenied() async {
        mockStore.shouldGrantAccess = false
        let output = await withCapturedOutput {
            await getCalendarEvents(days: 0, calendar: nil, requestId: 999)
        }
        XCTAssertTrue(output.contains("\"error\": \"access_denied\""), "got: \(output)")
        XCTAssertTrue(output.contains("\"request_id\": 999"), "got: \(output)")
    }

    func testCalendarNotFound() async {
        mockStore.shouldGrantAccess = true
        let output = await withCapturedOutput {
            await getCalendarEvents(days: 3, calendar: "NonExistent", requestId: 123)
        }
        XCTAssertTrue(output.contains("\"error\": \"calendar_not_found\""), "got: \(output)")
        XCTAssertTrue(output.contains("\"request_id\": 123"), "got: \(output)")
    }

    func testCalendarFoundNoEvents() async {
        mockStore.shouldGrantAccess = true
        let testCalendar = EKCalendar(for: .event, eventStore: mockStore)
        testCalendar.title = "Test Calendar"
        mockStore.mockCalendars = [testCalendar]

        let output = await withCapturedOutput {
            await getCalendarEvents(days: 2, calendar: "Test Calendar", requestId: 789)
        }

        guard let jsonData = output.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let events = jsonObject["events"] as? [[String: Any]]
        else {
            XCTFail("Unable to parse JSON. Output: \(output)")
            return
        }
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(jsonObject["request_id"] as? Int, 789)
    }

    func testCalendarFoundWithEvents() async {
        mockStore.shouldGrantAccess = true
        let calendar = EKCalendar(for: .event, eventStore: mockStore)
        calendar.title = "Work"
        mockStore.mockCalendars = [calendar]

        let e1 = EKEvent(eventStore: mockStore)
        e1.title = "Meeting"
        e1.startDate = Date()
        e1.endDate = Date().addingTimeInterval(3600)
        e1.calendar = calendar

        let e2 = EKEvent(eventStore: mockStore)
        e2.title = "Code Review"
        e2.startDate = Date().addingTimeInterval(7200)
        e2.endDate = Date().addingTimeInterval(10800)
        e2.calendar = calendar

        mockStore.mockEvents = [e1, e2]

        let output = await withCapturedOutput {
            await getCalendarEvents(days: 7, calendar: "Work", requestId: 555)
        }

        guard let jsonData = output.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let events = jsonObject["events"] as? [[String: Any]]
        else {
            XCTFail("JSON parsing failed. Output: \(output)")
            return
        }

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0]["title"] as? String, "Meeting")
        XCTAssertEqual(events[1]["title"] as? String, "Code Review")
        XCTAssertEqual(jsonObject["request_id"] as? Int, 555)
    }

    // MARK: - getSelectedCalendars Tests

    func testGetSelectedCalendarsAllCalendars() {
        let result = getSelectedCalendars(named: nil, store: mockStore)
        XCTAssertNil(result)
    }

    func testGetSelectedCalendarsByName() {
        let testCalendar = EKCalendar(for: .event, eventStore: mockStore)
        testCalendar.title = "Work"
        mockStore.mockCalendars = [testCalendar]

        let result = getSelectedCalendars(named: "Work", store: mockStore)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?.first?.title, "Work")
    }

    func testGetSelectedCalendarsNotFound() {
        let testCalendar = EKCalendar(for: .event, eventStore: mockStore)
        testCalendar.title = "Work"
        mockStore.mockCalendars = [testCalendar]

        let result = getSelectedCalendars(named: "Personal", store: mockStore)
        XCTAssertNil(result)
    }

    // MARK: - sendMessage Tests

    func testSendMessageLengthPrefix() async {
        let testJSON = "{\"status\": \"ok\"}"
        let outputData = await withRawCapturedOutput {
            sendMessage(testJSON)
        }

        guard outputData.count >= 4 else {
            XCTFail("Output too short for length prefix")
            return
        }

        let lengthPrefix = outputData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let payload = outputData.subdata(in: 4..<outputData.count)
        let payloadString = String(data: payload, encoding: .utf8)

        XCTAssertEqual(Int(lengthPrefix), payload.count)
        XCTAssertEqual(payloadString, testJSON)
    }

    // MARK: - readMessage Tests

    func testReadMessageValidJSON() {
        let inputHandle = createInputPipe(with: ["command": "test", "request_id": 1])
        let result = readMessage(from: inputHandle)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["command"] as? String, "test")
        XCTAssertEqual(result?["request_id"] as? Int, 1)
    }

    func testReadMessageInvalidLength() {
        let pipe = Pipe()
        let writeHandle = pipe.fileHandleForWriting
        writeHandle.write(Data([0x00, 0x01]))
        writeHandle.closeFile()
        let result = readMessage(from: pipe.fileHandleForReading)
        XCTAssertNil(result)
    }

    func testReadMessageInvalidJSON() {
        let pipe = Pipe()
        let writeHandle = pipe.fileHandleForWriting
        let invalidJSON = "not valid json!"
        let bodyData = invalidJSON.data(using: .utf8)!
        var length = UInt32(bodyData.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)
        writeHandle.write(lengthData + bodyData)
        writeHandle.closeFile()

        let readHandle = pipe.fileHandleForReading
        let errorOutput = captureError {
            let result = readMessage(from: readHandle)
            XCTAssertNil(result)
        }
        XCTAssertTrue(errorOutput.contains("invalid_json"), "got: \(errorOutput)")
    }

    func testReadMessageTruncatedBody() {
        let pipe = Pipe()
        let writeHandle = pipe.fileHandleForWriting
        var length = UInt32(100).bigEndian
        let lengthData = Data(bytes: &length, count: 4)
        let shortBody = Data(repeating: 0x41, count: 10)
        writeHandle.write(lengthData + shortBody)
        writeHandle.closeFile()
        let result = readMessage(from: pipe.fileHandleForReading)
        XCTAssertNil(result)
    }

    // MARK: - Command Dispatch Tests

    func testUnknownCommand() {
        let response = processMessage(["command": "fly_to_moon", "request_id": 42])
        XCTAssertTrue(response.contains("unknown_command"))
        XCTAssertTrue(response.contains("\"request_id\": 42"))
    }

    func testInvalidMessageFormat() {
        let response = processMessage(["not_command": true])
        XCTAssertTrue(response.contains("invalid_message_format"))
    }
}
