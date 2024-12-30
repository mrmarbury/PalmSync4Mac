import EventKit

class MockEventStore: EKEventStore {
    var shouldGrantAccess: Bool = false
    var mockCalendars: [EKCalendar] = []

    override func requestFullAccessToEvents() async throws -> Bool {
        return shouldGrantAccess
    }

    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars
    }

    override func predicateForEvents(
        withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?
    ) -> NSPredicate {
        return NSPredicate(value: true)
    }

    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return []
    }
}
