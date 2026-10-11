import SwiftData
import SwiftUI

struct HealthTimelineView: View {
    var pet: Pet

    @Environment(Router.self) private var router
    @Query(sort: \DailyCheckIn.day, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query private var events: [TimelineEvent]

    private struct Entry: Identifiable {
        enum Kind { case checkIn, photos([PhotoRef]), export }
        var day: Date
        var kind: Kind
        var title: String
        var subtitle: String
        var id: Date { day }
    }

    /// One card per day: an export wins, then photos added on earlier days, then the check-in itself.
    private var entries: [Entry] {
        let usual = BaselineEngine.baseline(checkIns.map(\.sample))
        let calendar = Calendar.current
        var byDay: [Date: Entry] = [:]
        for checkIn in checkIns {
            let photos = checkIn.photos
            if !photos.isEmpty, !calendar.isDateInToday(checkIn.day) {
                byDay[checkIn.day] = Entry(day: checkIn.day, kind: .photos(photos),
                                           title: "Added \(photos.count) photo\(photos.count == 1 ? "" : "s")", subtitle: "")
            } else {
                byDay[checkIn.day] = Entry(day: checkIn.day, kind: .checkIn, title: "Check-in completed",
                                           subtitle: BaselineEngine.daySummary(checkIn.sample, usual: usual))
            }
        }
        for event in events {
            byDay[event.day] = Entry(day: event.day, kind: .export, title: event.title, subtitle: event.subtitle)
        }
        return byDay.values.sorted { $0.day > $1.day }
    }

    var body: some View {
        let entries = self.entries
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if entries.isEmpty {
                    Text("Your check-ins will appear here.").font(.pp(14)).foregroundStyle(PP.subtext).card()
                }
                ForEach(entries) { entry in
                    row(entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .screen("Health Timeline")
    }

    private func row(_ entry: Entry) -> some View {
        let isToday = Calendar.current.isDateInToday(entry.day)
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if isToday { Text("Today").font(.pp(13, .semibold)).foregroundStyle(PP.teal) }
                Text(entry.day.mediumLabel).font(.pp(13)).foregroundStyle(PP.text)
            }
            Button { open(entry) } label: { cardContent(entry) }
                .buttonStyle(.plain)
        }
        .padding(.leading, 24)
        .padding(.bottom, 18)
        .background(alignment: .topLeading) {
            VStack(spacing: 4) {
                Circle().fill(PP.teal).frame(width: 9, height: 9).padding(.top, 4)
                Rectangle().fill(PP.teal.opacity(0.3)).frame(width: 1.5).frame(maxHeight: .infinity)
            }
            .frame(width: 9)
        }
    }

    private func cardContent(_ entry: Entry) -> some View {
        HStack(spacing: 12) {
            switch entry.kind {
            case .export:
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(PP.teal)
                    .frame(width: 46, height: 46)
                    .background(PP.mint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            default:
                PhotoTile(ref: pet.avatar, size: 46)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.pp(14, .semibold)).foregroundStyle(PP.navy)
                if case .photos(let photos) = entry.kind {
                    HStack(spacing: 6) {
                        ForEach(Array(photos.prefix(3).enumerated()), id: \.offset) { item in
                            PhotoTile(ref: item.element, size: 40, radius: 8)
                        }
                    }
                } else {
                    Text(entry.subtitle).font(.pp(12)).foregroundStyle(PP.subtext)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(PP.subtext)
        }
        .card(radius: 14, padding: 10)
    }

    private func open(_ entry: Entry) {
        switch entry.kind {
        case .export: router.path.append(.vetSummary)
        case .checkIn where Calendar.current.isDateInToday(entry.day): router.path.append(.checkIn)
        default: router.path.append(.changes)
        }
    }
}
