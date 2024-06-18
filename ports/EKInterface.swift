import Foundation
import EventKit

let store = EKEventStore()

// Function to send messages with a 4-byte length prefix
func sendMessage(_ message: String) {
    guard let data = message.data(using: .utf8) else { return }
    var length = UInt32(data.count).bigEndian
    let lengthData = Data(bytes: &length, count: 4)
    let outputData = lengthData + data
    FileHandle.standardOutput.write(outputData)
}

// Function to read messages with a 4-byte length prefix
func readMessage() -> String? {
    let stdin = FileHandle.standardInput

    // Read the 4-byte length header
    let lengthData = stdin.readData(ofLength: 4)
    guard lengthData.count == 4 else {
        return nil
    }

    let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

    // Read the message data
    let messageData = stdin.readData(ofLength: Int(length))
    guard messageData.count == length else {
        return nil
    }

    return String(data: messageData, encoding: .utf8)
}

// Function to get calendar events
func getCalendarEvents() async {
    // Request full access to events
    do {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else {
            sendMessage("{\"error\": \"access_denied\"}")
            return
        }
    } catch {
        sendMessage("{\"error\": \"\(error.localizedDescription)\"}")
        return
    }

    let startDate = Date()
    let endDate = Calendar.current.date(byAdding: .day, value: 14, to: startDate)!

    let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
    let events = store.events(matching: predicate)

    let eventList = events.map { event -> [String: Any] in
        return [
            "title": event.title ?? "No Title",
            "startDate": ISO8601DateFormatter().string(from: event.startDate),
            "endDate": ISO8601DateFormatter().string(from: event.endDate),
            "calendar": event.calendar.title
        ]
    }

    if let jsonData = try? JSONSerialization.data(withJSONObject: eventList, options: []) {
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            sendMessage(jsonString)
        } else {
            sendMessage("{\"error\": \"json_encoding_failed\"}")
        }
    } else {
        sendMessage("{\"error\": \"json_serialization_failed\"}")
    }
}

// Start the main loop
func startMainLoop() {
    DispatchQueue.global(qos: .userInitiated).async {
        while let input = readMessage() {
            switch input.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "get_events":
                Task {
                    await getCalendarEvents()
                }
            default:
                sendMessage("{\"error\": \"unknown_command\"}")
            }
        }
    }
    // Keep the main thread alive to process UI events
    RunLoop.main.run()
}

startMainLoop()

