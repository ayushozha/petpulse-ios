import Foundation
import SwiftData

@Model
final class Pet {
    var name: String
    var species: String
    var breed: String
    var ageYears: Int
    var isFemale: Bool
    var isNeutered: Bool
    var weightKg: Double?
    var medicalHistory: String
    @Attribute(.externalStorage) var photo: Data?

    init(name: String, species: String, breed: String, ageYears: Int, isFemale: Bool, isNeutered: Bool,
         weightKg: Double?, medicalHistory: String, photo: Data?) {
        self.name = name
        self.species = species
        self.breed = breed
        self.ageYears = ageYears
        self.isFemale = isFemale
        self.isNeutered = isNeutered
        self.weightKg = weightKg
        self.medicalHistory = medicalHistory
        self.photo = photo
    }

    var possessive: String { isFemale ? "her" : "his" }
    var sexLabel: String { isFemale ? "Female" : "Male" }
    var neuterLabel: String { isNeutered ? (isFemale ? "Spayed" : "Neutered") : "Not neutered" }
    var ageLabel: String { ageYears == 1 ? "1 year" : "\(ageYears) years" }
    var avatar: PhotoRef { photo.map(PhotoRef.data) ?? .asset("cat_avatar") }
}

@Model
final class DailyCheckIn {
    /// Start of the day this check-in belongs to. One check-in per day.
    var day: Date
    var dryFoodGrams: Double
    var wetFoodGrams: Double
    var waterMl: Double
    var stoolCount: Int
    var stoolNormal: Bool
    var urinationNormal: Bool
    /// Owner-rated energy, 0 (lethargic) to 10 (very active).
    var activity: Double
    var mood: String
    var coatNormal: Bool
    var eyesNormal: Bool
    var weightKg: Double?
    var notes: String
    var photoData: [Data]
    /// Bundled asset names, used only by the demo history.
    var demoPhotoNames: [String]

    init(day: Date, dryFoodGrams: Double, wetFoodGrams: Double, waterMl: Double, stoolCount: Int,
         stoolNormal: Bool = true, urinationNormal: Bool = true, activity: Double, mood: String = "Happy",
         coatNormal: Bool = true, eyesNormal: Bool = true, weightKg: Double? = nil, notes: String = "",
         photoData: [Data] = [], demoPhotoNames: [String] = []) {
        self.day = Calendar.current.startOfDay(for: day)
        self.dryFoodGrams = dryFoodGrams
        self.wetFoodGrams = wetFoodGrams
        self.waterMl = waterMl
        self.stoolCount = stoolCount
        self.stoolNormal = stoolNormal
        self.urinationNormal = urinationNormal
        self.activity = activity
        self.mood = mood
        self.coatNormal = coatNormal
        self.eyesNormal = eyesNormal
        self.weightKg = weightKg
        self.notes = notes
        self.photoData = photoData
        self.demoPhotoNames = demoPhotoNames
    }

    var sample: DaySample {
        DaySample(day: day, dryFood: dryFoodGrams, wetFood: wetFoodGrams, water: waterMl,
                  stool: Double(stoolCount), activity: activity, weight: weightKg)
    }

    var photos: [PhotoRef] { demoPhotoNames.map(PhotoRef.asset) + photoData.map(PhotoRef.data) }
}

/// Things on the timeline that are not check-ins, such as an exported vet summary.
@Model
final class TimelineEvent {
    var day: Date
    var title: String
    var subtitle: String

    init(day: Date, title: String, subtitle: String) {
        self.day = Calendar.current.startOfDay(for: day)
        self.title = title
        self.subtitle = subtitle
    }
}

enum PhotoRef: Hashable {
    case asset(String)
    case data(Data)
}
