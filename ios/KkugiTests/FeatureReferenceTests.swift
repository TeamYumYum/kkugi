import SwiftUI
import XCTest
@testable import Kkugi

final class FeatureReferenceTests: XCTestCase {
    @MainActor func testMealPresentationStates() async throws {
        let session = try XCTUnwrap(AppUIFixture.flow(onboarded: true).session)
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 3)).image { _ in }.pngData()
        let data = try XCTUnwrap(photo)
        for (caseName, recognizing) in [("meal-recognizing", true), ("meal-recognition-failed", false)] {
            try await captureReference(MealPhotoPicker.reference(session: session, photo: data, recognizing: recognizing), name: caseName)
        }
        let candidate = RecognitionCandidateResponse(rank: 1, foodId: 4, foodName: "닭가슴살", grams: 100,
            nutrition: NutritionResponse(kcal: 180, carbohydrateG: 12, proteinG: 24, fatG: 4),
            nutritionPer100g: FoodNutritionResponse(kcal: 180, carbohydrateG: 12, proteinG: 24, fatG: 4))
        let region = RecognitionRegionResponse(regionNo: 1, box: nil, candidates: [candidate])
        let result = MealPhotoRecognitionResponse(recognitionId: 7, status: "SUCCEEDED", regions: [region], photoUrl: nil)
        try await captureReference(ManualMealForm.reference(session: session, recognition: result), name: "meal-photo-confirm")
        try await captureReference(MealConfirmation(labels: ["닭가슴살 · 100g"], error: "", busy: false, save: {}), name: "meal-confirm")
    }

    @MainActor func testFinishedWorkout() async throws {
        let start = Date(timeIntervalSince1970: 1_767_225_600)
        let exercise = ExerciseResponse(id: 1, nameKo: "스쿼트", nameEn: "Squat", bodyPart: "LOWER_BODY",
            equipment: "BODYWEIGHT", recordType: "WEIGHT_REPS", weightType: "BODYWEIGHT", startImageUrl: nil, endImageUrl: nil)
        let values = WorkoutSessionValuesRequest(weightKg: 0, reps: 10, durationSeconds: nil)
        let set = WorkoutSessionSetRequest(setNo: 1, originStartSetNo: nil, target: values, actual: values, status: "COMPLETED", completedAt: nil)
        let active = ActiveWorkout(id: UUID(), startedAt: start, exercises: [PerformedExercise(id: UUID(), catalog: exercise, sets: [set])])
        let summary = WorkoutFinishSummary(active: active, endedAt: start.addingTimeInterval(180))
        XCTAssertEqual(summary.minutes, 3)
        XCTAssertEqual(summary.sets, 1)
        XCTAssertEqual(summary.kg, 0)
        try await captureReference(WorkoutFinishView(summary: summary, close: {}), name: "workout-finish")
    }
}
