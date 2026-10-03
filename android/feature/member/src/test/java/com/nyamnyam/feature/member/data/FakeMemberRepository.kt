package com.nyamnyam.feature.member.data

/**
 * ViewModel 단위 테스트에서 생성자로 넘기는 대역(Hilt 없이, ADR-06).
 */
class FakeMemberRepository(
    var items: List<String> = emptyList(),
) : MemberRepository {
    override suspend fun load(): List<String> = items
}
