import PhotosUI
import SwiftData
import SwiftUI

struct CheckInView: View {
    var pet: Pet
    /// Opens the voice check-in as soon as the screen appears, for the Home button, Siri and the control.
    var startsWithVoice = false

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]

    private enum Section: String, CaseIterable {
        case food, water, stool, activity, coat
    }

    @State private var expanded: Section?
    @State private var dryFood = 60.0
    @State private var wetFood = 80.0
    @State private var water = 120.0
    @State private var stoolCount = 2
    @State private var stoolNormal = true
    @State private var urinationNormal = true
    @State private var activity = 7.0
    @State private var mood = "Happy"
    @State private var coatNormal = true
    @State private var eyesNormal = true
    @State private var notes = ""
    @State private var photos: [Data] = []
    @State private var demoPhotos: [String] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var loaded = false
    @State private var showVoice = false

    private static let moods = ["Happy", "Calm", "Withdrawn", "Restless"]
    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var existing: DailyCheckIn? { checkIns.first { $0.day == today } }
    /// The pet's usual values from the days before today.
    private var usual: [Metric: Double] {
        BaselineEngine.baseline(checkIns.filter { $0.day != today }.suffix(BaselineEngine.windowDays).map(\.sample)).usual
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Label(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()), systemImage: "calendar")
                    .labelStyle(TrailingIconLabelStyle())
                    .font(.pp(13, .medium))
                    .foregroundStyle(PP.navy)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(PP.stroke, lineWidth: 1))

                voiceCard

                row(.food, .metric(.dryFood), "Food & Feeding", "How much did \(pet.name) eat?") {
                    SliderField(label: "Dry food", value: $dryFood, range: 0...150, step: 5, unit: "g")
                    SliderField(label: "Wet food", value: $wetFood, range: 0...200, step: 5, unit: "g")
                }
                row(.water, .metric(.water), "Water", "How much did \(pet.name) drink?") {
                    SliderField(label: "Water", value: $water, range: 0...300, step: 10, unit: "ml")
                }
                row(.stool, .metric(.stool), "Stool & Urination", "Any changes in stool or urination?") {
                    Stepper("Stools today: \(stoolCount)", value: $stoolCount, in: 0...8)
                    Toggle("Stool looked normal", isOn: $stoolNormal)
                    Toggle("Urination was normal", isOn: $urinationNormal)
                }
                row(.activity, .metric(.wetFood), "Activity & Behavior", "Energy level, mood, behavior?", symbol: "cat.fill") {
                    SliderField(label: "Energy level", value: $activity, range: 0...10, step: 1, unit: "/ 10")
                    Picker("Mood", selection: $mood) {
                        ForEach(Self.moods, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }
                row(.coat, .coat, "Coat, Skin & Eyes", "Any changes in appearance?") {
                    Toggle("Coat and skin look normal", isOn: $coatNormal)
                    Toggle("Eyes look normal", isOn: $eyesNormal)
                }

                photoCard

                VStack(alignment: .leading, spacing: 8) {
                    (Text("Notes ").font(.pp(14, .semibold)).foregroundColor(PP.navy)
                        + Text("(optional)").font(.pp(13)).foregroundColor(PP.subtext))
                    TextField("Anything else you'd like to note?", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .modifier(InputBox())
                }
                .padding(.top, 4)

                PrimaryButton("Save Check-in", action: save).padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screen("Daily Check-in")
        .fullScreenCover(isPresented: $showVoice) { VoiceCheckInView(pet: pet, onUse: apply) }
        .tint(PP.teal)
        .onAppear(perform: load)
        .onChange(of: VoiceCheckInRequest.shared.isPending) { openRequestedVoiceCheckIn() }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        photos.append(data.downscaledJPEG())
                    }
                }
                pickerItems = []
            }
        }
    }

    // MARK: Pieces

    private var voiceCard: some View {
        Button { showVoice = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(PP.buttonGradient, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Describe \(pet.name)'s day out loud").font(.pp(15, .semibold)).foregroundStyle(PP.navy)
                    Text("Speak naturally and PetPulse fills in the form for you.").font(.pp(12)).foregroundStyle(PP.subtext)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PP.teal)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PP.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PP.tealLight.opacity(0.6), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func row<Content: View>(_ section: Section, _ kind: IconKind, _ title: String, _ subtitle: String,
                                    symbol: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        let isOpen = expanded == section
        return VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded = isOpen ? nil : section }
            } label: {
                HStack(spacing: 12) {
                    if let symbol {
                        Circle().fill(Metric.wetFood.soft).frame(width: 42, height: 42)
                            .overlay { Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(PP.green) }
                    } else {
                        IconBadge(kind: kind, size: 42)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.pp(15, .semibold)).foregroundStyle(PP.navy)
                        Text(subtitle).font(.pp(12)).foregroundStyle(PP.subtext)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PP.subtext)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 10) { content() }
                    .font(.pp(14))
                    .foregroundStyle(PP.text)
            }
        }
        .card(padding: 12)
    }

    private var photoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(kind: .camera, size: 42)
            VStack(alignment: .leading, spacing: 10) {
                Text("Add Photos / Videos").font(.pp(15, .semibold)).foregroundStyle(PP.navy)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(allPhotos.enumerated()), id: \.offset) { item in
                            PhotoTile(ref: item.element)
                        }
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .images) {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundStyle(PP.subtext)
                                .frame(width: 62, height: 62)
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(PP.stroke, lineWidth: 1.5))
                        }
                        .accessibilityLabel("Add photos")
                    }
                    .padding(1)
                }
            }
        }
        .card(padding: 12)
    }

    private var allPhotos: [PhotoRef] { demoPhotos.map(PhotoRef.asset) + photos.map(PhotoRef.data) }

    // MARK: Data

    /// Starts from today's saved check-in, or from the pet's usual values so only changes need entering.
    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            dryFood = existing.dryFoodGrams
            wetFood = existing.wetFoodGrams
            water = existing.waterMl
            stoolCount = existing.stoolCount
            stoolNormal = existing.stoolNormal
            urinationNormal = existing.urinationNormal
            activity = existing.activity
            mood = existing.mood
            coatNormal = existing.coatNormal
            eyesNormal = existing.eyesNormal
            notes = existing.notes
            photos = existing.photoData
            demoPhotos = existing.demoPhotoNames
        } else {
            let usual = self.usual
            dryFood = ((usual[.dryFood] ?? dryFood) / 5).rounded() * 5
            wetFood = ((usual[.wetFood] ?? wetFood) / 5).rounded() * 5
            water = ((usual[.water] ?? water) / 10).rounded() * 10
            stoolCount = Int((usual[.stool] ?? Double(stoolCount)).rounded())
            activity = (usual[.activity] ?? activity).rounded()
        }
        showVoice = startsWithVoice
    }

    /// Siri, Shortcuts or the Control Center control asked for a voice check-in while this screen was open.
    private func openRequestedVoiceCheckIn() {
        let request = VoiceCheckInRequest.shared
        guard request.isPending else { return }
        request.isPending = false
        showVoice = true
    }

    /// Fills the form from a voice check-in. Anything not mentioned keeps its current value.
    private func apply(_ voice: VoiceCheckIn) {
        let usual = self.usual
        func value(_ metric: Metric, _ current: Double, step: Double, in range: ClosedRange<Double>) -> Double {
            voice.readings[metric]?.value(usual: usual[metric] ?? current, step: step, in: range) ?? current
        }
        dryFood = value(.dryFood, dryFood, step: 5, in: 0...150)
        wetFood = value(.wetFood, wetFood, step: 5, in: 0...200)
        water = value(.water, water, step: 10, in: 0...300)
        stoolCount = Int(value(.stool, Double(stoolCount), step: 1, in: 0...8))
        activity = value(.activity, activity, step: 1, in: 0...10)
        stoolNormal = voice.stoolNormal ?? stoolNormal
        urinationNormal = voice.urinationNormal ?? urinationNormal
        if !voice.transcript.isEmpty, !notes.contains(voice.transcript) {
            notes = notes.isEmpty ? voice.transcript : notes + "\n" + voice.transcript
        }
    }

    private func save() {
        let checkIn = existing ?? {
            let new = DailyCheckIn(day: today, dryFoodGrams: 0, wetFoodGrams: 0, waterMl: 0, stoolCount: 0,
                                   activity: 0, weightKg: checkIns.last?.weightKg ?? pet.weightKg)
            context.insert(new)
            return new
        }()
        checkIn.dryFoodGrams = dryFood
        checkIn.wetFoodGrams = wetFood
        checkIn.waterMl = water
        checkIn.stoolCount = stoolCount
        checkIn.stoolNormal = stoolNormal
        checkIn.urinationNormal = urinationNormal
        checkIn.activity = activity
        checkIn.mood = mood
        checkIn.coatNormal = coatNormal
        checkIn.eyesNormal = eyesNormal
        checkIn.notes = notes
        checkIn.photoData = photos

        let samples = checkIns.filter { $0.day != today }.map(\.sample) + [checkIn.sample]
        router.path = BaselineEngine.detect(samples).hasChange ? [.changes] : []
    }
}

/// Labelled slider with its current value on the right.
struct SliderField: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var unit: String

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value)) \(unit)").font(.pp(14, .semibold)).foregroundStyle(PP.teal)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}
