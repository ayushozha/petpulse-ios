import PhotosUI
import SwiftData
import SwiftUI

/// Creates the pet during onboarding (`pet == nil`) or edits it later.
struct ProfileView: View {
    var pet: Pet?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Mochi"
    @State private var species = "Cat"
    @State private var breed = "British Shorthair"
    @State private var ageYears = 2
    @State private var isFemale = true
    @State private var isNeutered = true
    @State private var weightText = "4.2"
    @State private var history = ""
    @State private var photo: Data?
    @State private var pickerItem: PhotosPickerItem?
    @State private var loaded = false

    private static let breeds: [String: [String]] = [
        "Cat": ["British Shorthair", "Domestic Shorthair", "Ragdoll", "Maine Coon", "Persian", "Siamese", "Bengal", "Scottish Fold", "Other"],
        "Dog": ["Mixed Breed", "Labrador Retriever", "Golden Retriever", "Poodle", "French Bulldog", "Shiba Inu", "Corgi", "Other"],
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                avatar
                field("Pet's Name", stacked: true) {
                    TextField("Name", text: $name).modifier(InputBox())
                }
                field("Species") {
                    HStack(spacing: 10) {
                        speciesChip("Cat", symbol: "cat.fill")
                        speciesChip("Dog", symbol: "dog.fill")
                    }
                }
                field("Breed") {
                    Menu {
                        ForEach(Self.breeds[species] ?? [], id: \.self) { option in
                            Button(option) { breed = option }
                        }
                    } label: { menuLabel(breed) }
                }
                field("Age") {
                    Menu {
                        ForEach(0...25, id: \.self) { years in
                            Button(Self.ageLabel(years)) { ageYears = years }
                        }
                    } label: { menuLabel(Self.ageLabel(ageYears)) }
                }
                field("Gender") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 0) {
                            radio("Female", selected: isFemale) { isFemale = true }
                            radio("Male", selected: !isFemale) { isFemale = false }
                        }
                        HStack(spacing: 0) {
                            radio("Neutered/Spayed", selected: isNeutered) { isNeutered = true }
                            radio("Not yet", selected: !isNeutered) { isNeutered = false }
                        }
                    }
                    .padding(.top, 4)
                }
                field("Weight (optional)") {
                    HStack {
                        TextField("0.0", text: $weightText).keyboardType(.decimalPad)
                        Text("kg").foregroundStyle(PP.subtext)
                    }
                    .modifier(InputBox())
                }
                field("Medical History (optional)", stacked: true) {
                    TextField("e.g. previous illnesses, allergies...", text: $history, axis: .vertical)
                        .lineLimit(3...5)
                        .modifier(InputBox())
                }
                PrimaryButton("Save Profile", action: save)
                    .padding(.top, 6)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(.pp(14))
            .foregroundStyle(PP.text)
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screen("Pet Profile") {
            if pet == nil {
                Button("Skip", action: save).font(.pp(14, .semibold)).foregroundStyle(PP.teal)
            }
        }
        .onAppear(perform: load)
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    photo = data.downscaledJPEG()
                }
            }
        }
        .onChange(of: species) { _, new in
            if !(Self.breeds[new] ?? []).contains(breed) { breed = Self.breeds[new]?.first ?? "Other" }
        }
    }

    private static func ageLabel(_ years: Int) -> String {
        years == 0 ? "Under 1 year" : years == 1 ? "1 year" : "\(years) years"
    }

    // MARK: Pieces

    private var avatar: some View {
        PhotoView(ref: photo.map(PhotoRef.data) ?? .asset("cat_avatar"))
            .frame(width: 124, height: 124)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 4))
            .shadow(color: PP.navy.opacity(0.12), radius: 8, y: 3)
            .overlay(alignment: .bottomTrailing) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(PP.teal, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(.white, lineWidth: 2))
                }
                .accessibilityLabel("Choose photo")
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .background {
                HStack {
                    Image(systemName: "pawprint.fill").rotationEffect(.degrees(-20))
                    Spacer()
                    Image(systemName: "pawprint.fill").rotationEffect(.degrees(20)).offset(y: -30)
                }
                .font(.system(size: 22))
                .foregroundStyle(PP.teal.opacity(0.15))
            }
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, stacked: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        if stacked {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.pp(13, .medium))
                content()
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).font(.pp(13)).foregroundStyle(PP.subtext).frame(width: 104, alignment: .leading)
                content().frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func speciesChip(_ value: String, symbol: String) -> some View {
        let selected = species == value
        return Button { species = value } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(selected ? PP.teal : PP.subtext)
                Text(value)
            }
            .font(.pp(14, selected ? .semibold : .regular))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(selected ? PP.mint : .white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? PP.teal : PP.stroke, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func menuLabel(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(PP.subtext)
        }
        .modifier(InputBox())
    }

    private func radio(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? PP.teal : PP.stroke)
                    .font(.system(size: 18))
                Text(label).font(.pp(13)).foregroundStyle(PP.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private func load() {
        guard !loaded, let pet else { return }
        loaded = true
        name = pet.name
        species = pet.species
        breed = pet.breed
        ageYears = pet.ageYears
        isFemale = pet.isFemale
        isNeutered = pet.isNeutered
        weightText = pet.weightKg.map { String(format: "%g", $0) } ?? ""
        history = pet.medicalHistory
        photo = pet.photo
    }

    private func save() {
        let weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        if let pet {
            pet.name = cleanName
            pet.species = species
            pet.breed = breed
            pet.ageYears = ageYears
            pet.isFemale = isFemale
            pet.isNeutered = isNeutered
            pet.weightKg = weight
            pet.medicalHistory = history
            pet.photo = photo
            dismiss()
        } else {
            context.insert(Pet(name: cleanName.isEmpty ? "Mochi" : cleanName, species: species, breed: breed,
                               ageYears: ageYears, isFemale: isFemale, isNeutered: isNeutered,
                               weightKg: weight, medicalHistory: history, photo: photo))
            if DemoSeeder.seedOnFirstProfile {
                DemoSeeder.seedHealthyHistory(in: context, weight: weight ?? 4.2)
            }
        }
    }
}

/// White rounded text-field box.
struct InputBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pp(14))
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PP.stroke, lineWidth: 1))
    }
}
