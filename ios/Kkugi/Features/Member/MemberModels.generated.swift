// Generated from contracts/openapi.json by ios/scripts/member_contract.py.
import Foundation

struct OnboardingRequest: Codable {
    let nickname: String
    let healthGoal: String
    let gender: String
    let birthDate: String
    let heightCm: Decimal
    let weightKg: Decimal
    let activityLevel: String
}

struct ProfileUpdateRequest: Codable {
    let nickname: String
    let healthGoal: String
    let gender: String
    let birthDate: String
    let heightCm: Decimal
    let activityLevel: String
}

struct MemberDeviceRequest: Codable {
    let fcmToken: String
}

struct MemberProfileResponse: Codable {
    let nickname: String
    let healthGoal: String
    let gender: String
    let birthDate: String
    let heightCm: Decimal
    let startWeightKg: Decimal
    let activityLevel: String
    let avatar: String
    let onboardedAt: String
}

struct ApiResponseMemberProfileResponse: Codable {
    let success: Bool?
    let data: MemberProfileResponse?
    let error: ErrorDetail?
}
