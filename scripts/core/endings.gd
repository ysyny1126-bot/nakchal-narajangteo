extends RefCounted

## Chapter grades, achievements and the preset endings (with credits) that a
## playthrough's choices lead to.

const Rules = preload("res://scripts/core/procurement_rules.gd")
const Events = preload("res://scripts/core/events.gd")

const SEVERE := ["허위서류", "담합", "금품제공", "과다청구"]
const MINOR := ["관행메모", "대체자재", "허위후기", "결함출고"]
const START_MONEY := 30000000

const ENDINGS := {
	"trust": {
		"no": 1, "title": "신뢰의 조달 명가", "subtitle": "공정·정직·약속, 세 가지를 모두 지킨 한빛퍼니처",
		"color": Color("#e0a63a"), "good": true, "room": "city",
		"lines": [
			["○○시청 이 주무관", "한빛 탁자, 회의실에서 다들 칭찬이 자자해요. 다음 공고도 꼭 참여해 주세요!"],
			["조달청 윤서진 계약관", "서류도, 가격도, 납품도 정확했어요. 이런 업체가 많아져야 공공조달이 튼튼해집니다."],
			["나라미", "원칙대로 한 게 결국 제일 빠른 길이었어요."],
			["달이", "1년 만에 [b]신뢰의 조달 명가[/b]! 우리 정말 잘 해냈어요!"],
		],
	},
	"steady": {
		"no": 2, "title": "성실한 성장", "subtitle": "실수도 있었지만 정직하게 한 걸음씩",
		"color": Color("#4f8f5c"), "good": true, "room": "office",
		"lines": [
			["박 실장", "대표님, 올해 장부 정리 끝났어요. 큰 대박은 아니어도 탄탄하게 남았어요."],
			["나라미", "아쉬운 선택도 있었지만, 한 번도 속이지는 않았어요."],
			["달이", "다음엔 '다른 길이었다면?' 표를 보고 점수를 더 올려 봐요!"],
		],
	},
	"risky": {
		"no": 3, "title": "아슬아슬 줄타기", "subtitle": "이익은 남았지만 위험 신호가 쌓였어요",
		"color": Color("#c77a2e"), "good": false, "room": "office",
		"lines": [
			["박 실장", "대표님… 감사팀에서 작년 서류를 다시 보자고 연락이 왔어요."],
			["나라미", "그때 원칙대로 했으면 이런 걱정은 없었을 텐데."],
			["달이", "작은 편법이 쌓이면 리스크가 돼요. 이번엔 무사했지만 다음은 몰라요."],
		],
	},
	"comeback": {
		"no": 4, "title": "다시 일어서는 한빛", "subtitle": "결과는 아쉬워도 신뢰는 남았어요",
		"color": Color("#3f78a8"), "good": true, "room": "review",
		"lines": [
			["조달청 윤서진 계약관", "이번엔 아쉬웠지만 서류는 모두 사실이었어요. 그게 가장 중요한 자산이에요."],
			["나라미", "원가 계산부터 다시 해서 다음 공고에 도전할게요."],
			["달이", "정직하게 쌓은 기록은 다음 심사 때 꼭 힘이 될 거예요!"],
		],
	},
	"sanction": {
		"no": 5, "title": "멈춰 선 나라장터", "subtitle": "입찰참가자격 제한 처분",
		"color": Color("#c2493d"), "good": false, "room": "review",
		"lines": [
			["조달청 윤서진 계약관", "{reason} 확인되어 [b]입찰참가자격 제한[/b] 처분이 내려졌습니다."],
			["나라미", "한 번의 선택 때문에… 나라장터에서 한빛 이름이 사라졌어요."],
			["달이", "처음부터 다시 해 봐요. 이번엔 정직한 길로 함께 가요."],
		],
	},
}

const CREDITS := [
	["기획 · 제작", "양상윤"],
	["개발 · 시나리오", "Claude (Anthropic)"],
	["게임 엔진", "Godot Engine 4"],
	["3D 가구 모델", "Kenney Furniture Kit (CC0)"],
	["바닥·벽 텍스처", "Poly Haven (CC0)"],
	["글꼴", "Pretendard (SIL OFL)"],
	["음악 · 효과음", "코드로 합성한 오리지널 사운드"],
	["캐릭터", "나라미 · 달이 (팬 메이드 3D 표현)"],
	["도움말", "게임 속 제도와 수치는 학습용으로 단순화했습니다.\n실제 기준은 조달청·나라장터 안내를 확인하세요."],
]

const ACHIEVEMENTS := {
	"fair_spec": {"name": "공정한 규격", "desc": "성능 중심 일반 규격으로 공고"},
	"own_calc": {"name": "원칙대로 계산", "desc": "출처 불명 메모 대신 직접 계산"},
	"first_try": {"name": "한 번에 낙찰", "desc": "첫 투찰로 낙찰 확정"},
	"archive": {"name": "숨은 실적 발견", "desc": "보관함에서 실제 납품확인서 발견"},
	"honest_pass": {"name": "사실대로 통과", "desc": "사실대로 낸 서류로 적격심사 통과"},
	"mall_top": {"name": "구매 1순위 후보", "desc": "구매 비교에서 1순위 후보"},
	"fair_price": {"name": "공정한 가격", "desc": "원자재 하락분을 판매가에 반영"},
	"whistle": {"name": "공정 경쟁 지킴이", "desc": "담합 제안을 거절하고 신고"},
	"promise": {"name": "약속은 지킨다", "desc": "돌발 상황을 투명하게 해결"},
	"clean_inspect": {"name": "한 번에 검수 합격", "desc": "결함 없이 검수 통과"},
	"quiz_perfect": {"name": "조달 박사", "desc": "확인 퀴즈 3문항 모두 정답"},
	"glossary": {"name": "용어 도감 완성", "desc": "용어 %d개를 모두 열람"},
	"trust_ending": {"name": "신뢰의 조달 명가", "desc": "최고 엔딩 달성"},
}


static func has_any(state: Dictionary, flags: Array) -> bool:
	for f in state.get("flags", []):
		if flags.has(f):
			return true
	return false


static func won_ep1(state: Dictionary) -> bool:
	return str(state.get("review_choice", "")) == "review_truth" and bool((state.get("review", {}) as Dictionary).get("pass", false))


static func ep2_profit(state: Dictionary) -> int:
	var total := 0
	for q in state.get("quarters", []):
		total += int(q.profit)
	return total


## Best achievable 4-quarter profit across product × sale choices.
static func ep2_best(state: Dictionary) -> int:
	var best := -INF
	for key in Rules.PRODUCTS:
		for sale in [false, true]:
			var total := 0
			for q in range(4):
				total += int(Rules.quarter(key, q, sale, q >= 2, bool(state.get("buyer_pick", false)), 8731).profit)
			best = maxf(best, total)
	return int(best)


static func _quiz_points(state: Dictionary, ep: int) -> float:
	var quiz: Dictionary = state.get("quiz", {})
	return float(quiz.get(str(ep), 0)) / 3.0 * 20.0


static func _event_points(grade: String, good: float, ok: float) -> float:
	return good if grade == "good" else (ok if grade == "ok" else 0.0)


static func chapter_score(state: Dictionary, ep: int) -> float:
	var s := 0.0
	match ep:
		1:
			s += {"spec_general": 25.0, "spec_cheap": 8.0, "spec_brand": 4.0}.get(str(state.get("spec_choice", "")), 0.0)
			var bid: Dictionary = state.get("bid", {})
			if won_ep1(state):
				s += maxf(25.0 - 5.0 * int(state.get("bid_attempt", 0)), 12.0)
			elif not bid.is_empty() and int(bid.get("rank", 0)) == 1:
				s += 12.0
			else:
				s += 4.0
			match str(state.get("review_choice", "")):
				"review_truth": s += 25.0 if won_ep1(state) else 15.0
				"review_giveup": s += 4.0
			s += 3.0 if bool(state.get("archive_found", false)) else 0.0
			s += 2.0 if not has_any(state, ["관행메모"]) else 0.0
			if has_any(state, ["허위서류"]):
				s = minf(s, 20.0)
		2:
			var best := float(ep2_best(state))
			s += 35.0 * clampf(float(ep2_profit(state)) / maxf(best, 1.0), 0.0, 1.0)
			s += 10.0 if bool(state.get("buyer_pick", false)) else 0.0
			s += 10.0 if bool(state.get("price_cut", false)) else 0.0
			var opt := Events.option(Events.EP2, str(state.get("ep2_event", "")), str(state.get("ep2_event_choice", "")))
			s += _event_points(str(opt.get("grade", "")), 15.0, 7.0)
			var product := str(state.get("product", ""))
			if Rules.PRODUCTS.has(product):
				var totals := {}
				for sale in [false, true]:
					var t := 0
					for q in range(4):
						t += int(Rules.quarter(product, q, sale, bool(state.get("price_cut", false)) and q >= 2, bool(state.get("buyer_pick", false)), 8731).profit)
					totals[sale] = t
				var better: bool = totals[true] >= totals[false]
				s += 10.0 if bool(state.get("sale", false)) == better else 4.0
			if has_any(state, ["담합"]):
				s = minf(s, 20.0)
		3:
			var opt := Events.option(Events.EP3, str(state.get("ep3_event", "")), str(state.get("ep3_event_choice", "")))
			s += _event_points(str(opt.get("grade", "")), 25.0, 10.0)
			s += {"pass": 25.0, "fixed": 15.0, "argue": 5.0}.get(str(state.get("inspect_result", "")), 0.0)
			s += 20.0 if str(state.get("invoice_choice", "")) == "exact" else 0.0
			s += 10.0 * float((state.get("ep3_checked", []) as Array).size()) / 2.0
			if has_any(state, ["금품제공", "과다청구"]):
				s = minf(s, 20.0)
	return clampf(s + _quiz_points(state, ep), 0.0, 100.0)


static func grade(score: float) -> String:
	if score >= 90.0: return "S"
	if score >= 75.0: return "A"
	if score >= 60.0: return "B"
	if score >= 40.0: return "C"
	return "D"


static func grade_color(g: String) -> Color:
	return {"S": Color("#e0a63a"), "A": Color("#4f8f5c"), "B": Color("#3f78a8"), "C": Color("#c77a2e")}.get(g, Color("#c2493d"))


static func overall(state: Dictionary) -> float:
	var total := 0.0
	for ep in [1, 2, 3]:
		total += chapter_score(state, ep)
	return total / 3.0


static func pick_ending(state: Dictionary) -> String:
	if has_any(state, SEVERE):
		return "sanction"
	if not won_ep1(state) or int(state.get("money", 0)) < START_MONEY:
		return "comeback"
	if has_any(state, MINOR) or int(state.get("risk", 0)) >= 20 or str(state.get("spec_choice", "")) == "spec_brand":
		return "risky"
	if overall(state) >= 80.0 and int(state.get("risk", 0)) <= 10:
		return "trust"
	return "steady"


static func sanction_reason(state: Dictionary) -> String:
	var reasons := {"허위서류": "적격심사에 허위 실적 서류를 낸 사실이", "담합": "경쟁사와 가격을 담합한 사실이", "금품제공": "검수 담당자에게 금품을 건넨 사실이", "과다청구": "대금을 부풀려 청구한 사실이"}
	for f in state.get("flags", []):
		if reasons.has(f):
			return reasons[f]
	return "부정행위가"


static func lines(state: Dictionary, ending_id: String) -> Array:
	var out := []
	for pair in ENDINGS[ending_id].lines:
		out.append([pair[0], str(pair[1]).replace("{reason}", sanction_reason(state))])
	return out


## Achievements satisfied by the current state (cumulative across a run).
static func achieved(state: Dictionary) -> Array:
	var got := []
	if str(state.get("spec_choice", "")) == "spec_general": got.append("fair_spec")
	if (state.get("flags", []) as Array).has("원칙계산"): got.append("own_calc")
	if won_ep1(state) and int(state.get("bid_attempt", 0)) == 0: got.append("first_try")
	if bool(state.get("archive_found", false)): got.append("archive")
	if won_ep1(state): got.append("honest_pass")
	if bool(state.get("buyer_pick", false)): got.append("mall_top")
	if bool(state.get("price_cut", false)): got.append("fair_price")
	if str(state.get("ep2_event_choice", "")) == "report": got.append("whistle")
	var opt := Events.option(Events.EP3, str(state.get("ep3_event", "")), str(state.get("ep3_event_choice", "")))
	if str(opt.get("grade", "")) == "good": got.append("promise")
	if str(state.get("inspect_result", "")) == "pass": got.append("clean_inspect")
	for v in (state.get("quiz", {}) as Dictionary).values():
		if int(v) == 3:
			got.append("quiz_perfect")
			break
	return got
