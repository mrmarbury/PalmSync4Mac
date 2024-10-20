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

func readMessage() -> [String: Any]? {
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

    if let messageString = String(data: messageData, encoding: .utf8),
       let data = messageString.data(using: .utf8) {
        // Parse the JSON message
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return json
            }
        } catch {
            sendMessage("{\"error\": \"invalid_json\", \"details\": \"\(error.localizedDescription)\"}")
        }
    } else {
        sendMessage("{\"error\": \"invalid_encoding\"}")
    }
    return nil
}


// Function to get calendar events
// This is 0-based meaning:
//  0 -> today
//  1 -> today & tomorrow
//  2 -> today, tomorrow & the day after
//  6 -> next 7 days
// 13 -> next 14 days
// and so on
func getCalendarEvents(days: Int, requestId: Int?) async {
    // Request full access to events
    do {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else {
            sendMessage("{\"error\": \"access_denied\", \"request_id\": \(requestId ?? -1)}")
            return
        }
    } catch {
        sendMessage("{\"error\": \"\(error.localizedDescription)\", \"request_id\": \(requestId ?? -1)}")
        return
    }

    // Set startDate to today at 00:00
    let startDate = Calendar.current.startOfDay(for: Date())

    // Compute endDate based on the days parameter
    let endDate = Calendar.current.date(byAdding: .day, value: days + 1, to: startDate)!

    let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
    let events = store.events(matching: predicate)

    let eventList = events.map { event -> [String: Any] in
        return [
            "title": event.title ?? "Event",
            "startDate": ISO8601DateFormatter().string(from: event.startDate),
            "endDate": ISO8601DateFormatter().string(from: event.endDate),
            "calendar": event.calendar.title
        ]
    }

    let responseDict: [String: Any] = [
        "events": eventList,
        "request_id": requestId ?? -1
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: responseDict, options: []) {
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            sendMessage(jsonString)
        } else {
            sendMessage("{\"error\": \"json_encoding_failed\", \"request_id\": \(requestId ?? -1)}")
        }
    } else {
        sendMessage("{\"error\": \"json_serialization_failed\", \"request_id\": \(requestId ?? -1)}")
    }
}

func startMainLoop() {
    DispatchQueue.global(qos: .userInitiated).async {
        while let message = readMessage() {
            if let command = message["command"] as? String {
                let requestId = message["request_id"] as? Int
                switch command {
                case "get_events":
                    let days = message["days"] as? Int ?? 13 // Default to 14 days if not specified
                    Task {
                        await getCalendarEvents(days: days, requestId: requestId)
                    }
                default:
                    sendMessage("{\"error\": \"unknown_command\", \"request_id\": \(requestId ?? -1)}")
                }
            } else {
                sendMessage("{\"error\": \"invalid_message_format\"}")
            }
        }
    }
    RunLoop.main.run()
}

startMainLoop()
