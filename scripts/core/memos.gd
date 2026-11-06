extends RefCounted

## Dropped memos: one turns up somewhere in the office each working day.
## Picking it up gives a small bonus and one procurement fact, and the memo
## goes into the collection (state.memos in the save, profile.memos overall).
## Facts are written for a general audience; game-only numbers say so.

const MEMOS := {
	"m1_1": {"ep": 1, "day": 1, "title": "선배의 포스트잇", "q": "조달청은 무슨 일을 할까?", "a": "공공기관이 쓰는 물건과 서비스를 대신 사고, 큰 공사 계약도 맡아요. 나라 살림을 아끼는 '나라의 구매 부서'예요.", "gain": {"perf": 1}},
	"m1_2": {"ep": 1, "day": 2, "title": "구겨진 공고문", "q": "입찰 공고는 왜 미리 낼까?", "a": "모든 업체가 같은 정보를 같은 때 보고 준비할 수 있게 하려고요. 공정한 경쟁의 출발점이에요.", "gain": {"perf": 1}},
	"m1_3": {"ep": 1, "day": 3, "title": "나라장터 안내문", "q": "나라장터가 뭐지?", "a": "공공기관 입찰과 계약을 온라인으로 처리하는 국가종합전자조달시스템이에요. 공고부터 계약까지 한 곳에서 해요.", "gain": {"points": 30}},
	"m2_1": {"ep": 2, "day": 1, "title": "쇼핑몰 교육 메모", "q": "기관은 왜 쇼핑몰에서 살까?", "a": "이미 계약된 상품이라 따로 입찰하지 않고 비교해서 바로 주문할 수 있어요. 시간과 비용이 크게 줄어요.", "gain": {"perf": 1}},
	"m2_2": {"ep": 2, "day": 2, "title": "가격 조사 노트", "q": "같은 상품 가격이 다르면?", "a": "쇼핑몰 가격이 시중보다 비싸면 안 돼요. 가격을 비교해 차이가 크면 바로잡아요.", "gain": {"perf": 1}},
	"m2_3": {"ep": 2, "day": 3, "title": "청렴 서약서 사본", "q": "업체가 주는 작은 선물은?", "a": "직무와 관련된 사람에게서 받는 선물은 금액이 작아도 조심해야 해요. 정중히 거절하는 게 가장 안전해요.", "gain": {"points": 30}},
	"m3_1": {"ep": 3, "day": 1, "title": "현장 체크리스트", "q": "납품 검사 때 무엇을 볼까?", "a": "규격서와 같은지 수량, 치수, 품질, 인증을 하나씩 확인해요. 사진과 기록도 남겨요.", "gain": {"perf": 1}},
	"m3_2": {"ep": 3, "day": 2, "title": "지급 일정표", "q": "대금은 언제 줄까?", "a": "검사에 합격하고 업체가 청구하면 정해진 기간 안에 빨리 지급해요. 늦게 주면 업체가 힘들어져요.", "gain": {"perf": 1}},
	"m3_3": {"ep": 3, "day": 3, "title": "하자보수 안내 쪽지", "q": "납품 뒤 고장 나면?", "a": "하자보수 기간 안이라면 업체가 고쳐 줘야 해요. 그래서 계약 때 하자보수보증금을 받아 둬요.", "gain": {"points": 30}},
}

## Where in the office a memo can lie: floor spots the employee can walk to.
const SPOTS := [Vector3(-1.4, 0, -0.35), Vector3(1.6, 0, -0.6), Vector3(-1.2, 0, 2.45), Vector3(1.35, 0, 2.4), Vector3(-0.5, 0, -1.0)]


static func for_day(ep: int, day: int) -> String:
	for id in MEMOS:
		if int(MEMOS[id].ep) == ep and int(MEMOS[id].day) == day:
			return id
	return ""


static func spot_for(id: String) -> Vector3:
	return SPOTS[absi(hash(id)) % SPOTS.size()]
