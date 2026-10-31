extends RefCounted

## Random incidents. One EP02 event (after the 1st quarter) and one EP03 event
## (when talking to Park) are drawn per playthrough. Every option has a preset
## outcome: grade ("good" / "ok" / "bad"), stat deltas, an optional flag that
## the endings read, and `money` in won. All numbers are GAME ASSUMPTIONS.

const EP2 := {
	"collusion": {
		"kicker": "돌발 상황 · 경쟁사의 제안",
		"title": "\"우리끼리 가격을 맞추죠\"",
		"body": "대성오피스 영업팀장이 조용히 연락해 왔습니다.\n\n\"다음 분기부터 둘 다 90만 원 아래로는 내리지 맙시다. 서로 손해 볼 일 없잖아요?\"\n\n경쟁사끼리 가격을 미리 맞추는 것은 [b]담합[/b]입니다.",
		"options": [
			{"id": "report", "label": "단호히 거절하고 신고 창구에 알린다", "grade": "good", "deltas": {"rep": 4, "opinion": 3}, "title": "공정 경쟁을 지켰어요", "body": "신고가 접수되어 조사가 시작됐습니다. 한빛은 [b]공정한 업체[/b]로 신뢰를 얻었습니다.", "log": "담합 제안 거절·신고"},
			{"id": "refuse", "label": "거절만 하고 넘어간다", "grade": "ok", "deltas": {"rep": 1}, "title": "제안을 거절했어요", "body": "참여하지 않았으니 문제는 없습니다. 다만 신고하면 시장 전체의 공정성을 지킬 수 있었어요.", "log": "담합 제안 거절"},
			{"id": "accept", "label": "제안을 받아들인다", "grade": "bad", "deltas": {"risk": 25, "rep": -10}, "money": 3000000, "flag": "담합", "title": "당장은 이익, 하지만…", "body": "가격을 올려 단기 이익이 생겼지만, 담합은 [color=#c2493d][b]과징금과 입찰참가자격 제한[/b][/color] 대상입니다. 언젠가 드러납니다.", "log": "담합 가담 (리스크)"},
		],
	},
	"bulk": {
		"kicker": "돌발 상황 · 대량 주문 문의",
		"title": "교육청에서 탁자 120개 문의가 왔어요",
		"body": "△△교육청이 3주 안에 탁자 120개를 받을 수 있는지 묻습니다. 한빛 공장이 3주 동안 만들 수 있는 양은 [b]약 70개[/b]입니다.",
		"options": [
			{"id": "partial", "label": "가능한 70개만 정확한 납기로 수락한다", "grade": "good", "deltas": {"rep": 3}, "money": 1800000, "title": "약속할 수 있는 만큼만", "body": "70개를 제때 납품해 추가 이익과 신뢰를 함께 얻었습니다. 나머지는 다른 업체가 맡았습니다.", "log": "대량 주문 70개 수락"},
			{"id": "all", "label": "일단 120개 전부 수락한다", "grade": "bad", "deltas": {"rep": -5, "risk": 8}, "money": -1200000, "title": "납기를 지키지 못했어요", "body": "생산이 따라가지 못해 납품이 늦어졌습니다. [b]지체상금[/b]과 신뢰 하락으로 오히려 손해를 봤습니다.", "log": "대량 주문 무리한 수락 → 지연"},
			{"id": "decline", "label": "위험하니 거절한다", "grade": "ok", "deltas": {}, "title": "기회를 넘겼어요", "body": "손해는 없지만 가능한 만큼이라도 수락했다면 이익을 낼 수 있었습니다.", "log": "대량 주문 거절"},
		],
	},
	"review": {
		"kicker": "돌발 상황 · 구매 후기",
		"title": "\"탁자 다리가 흔들려요\" 후기가 올라왔어요",
		"body": "한 기관 담당자가 쇼핑몰에 [b]별점 2점[/b] 후기를 남겼습니다. 조립 볼트가 덜 조여진 채 배송된 것 같습니다.",
		"options": [
			{"id": "fix", "label": "직접 방문해 무상 점검·교체한다", "grade": "good", "deltas": {"rep": 4, "opinion": 4}, "money": -400000, "title": "후기가 별점 5점으로 바뀌었어요", "body": "빠른 대응에 담당자가 후기를 고쳐 남겼습니다. 출고 전 점검 절차도 보강했습니다.", "log": "불만 후기 → 무상 점검"},
			{"id": "ignore", "label": "답글만 달고 넘어간다", "grade": "ok", "deltas": {"opinion": -3}, "title": "불만이 남아 있어요", "body": "같은 문제가 반복될 수 있어 다른 기관도 구매를 망설입니다.", "log": "불만 후기 방치"},
			{"id": "fake", "label": "지인에게 좋은 후기를 써 달라고 부탁한다", "grade": "bad", "deltas": {"risk": 10, "rep": -6}, "flag": "허위후기", "title": "허위 후기가 적발됐어요", "body": "구매 이력 없는 후기가 확인되어 [b]상품 노출이 제한[/b]되었습니다. 신뢰가 크게 떨어졌습니다.", "log": "허위 후기 적발"},
		],
	},
}

const EP3 := {
	"material": {
		"kicker": "돌발 상황 · 자재 공급 지연",
		"title": "친환경 인증 목재가 2주 늦게 온대요",
		"body": "박 실장: \"대표님, 목재 공급처 공장이 멈췄대요. 인증 목재가 [b]2주[/b] 늦게 들어옵니다. 납기까지는 10일 남았어요.\"",
		"options": [
			{"id": "notify", "label": "시청에 바로 알리고 증빙을 내 납기 연장을 협의한다", "grade": "good", "deltas": {"rep": 4}, "title": "납기 연장이 승인됐어요", "body": "공급처 사고 증빙을 낸 덕분에 [b]정당한 사유[/b]로 인정되어 지체상금 없이 납기가 연장됐습니다.", "log": "자재 지연 → 사전 협의·연장"},
			{"id": "swap", "label": "인증 없는 값싼 목재로 몰래 바꿔 만든다", "grade": "bad", "deltas": {"risk": 10}, "money": 600000, "flag": "대체자재", "title": "납기는 맞췄지만…", "body": "규격서에 적힌 [b]친환경 인증 자재[/b]가 아닙니다. 검수에서 드러날 수 있습니다.", "log": "무단 대체 자재 사용"},
			{"id": "silent", "label": "아무 말 없이 늦게 납품한다", "grade": "ok", "deltas": {"rep": -3}, "late_days": 4, "title": "4일 늦게 납품했어요", "body": "알리지 않은 지연은 정당한 사유로 인정받기 어렵습니다. [b]지체상금[/b]이 부과됩니다.", "log": "무통보 지연 4일"},
		],
	},
	"truck": {
		"kicker": "돌발 상황 · 운송 차질",
		"title": "운송 트럭이 고장 났어요",
		"body": "박 실장: \"납품 당일 아침인데 트럭이 고장 났어요! 오늘 안에 못 갈 수도 있어요.\"",
		"options": [
			{"id": "rent", "label": "비용을 들여 다른 운송사를 급히 부른다", "grade": "good", "deltas": {"rep": 3}, "money": -450000, "title": "제시간에 도착했어요", "body": "운송비가 더 들었지만 [b]약속한 납기[/b]를 지켰습니다.", "log": "운송 차질 → 대체 운송"},
			{"id": "split", "label": "시청에 알리고 이틀에 나눠 납품하도록 협의한다", "grade": "good", "deltas": {"rep": 2}, "title": "분할 납품으로 협의했어요", "body": "미리 알리고 협의해 기관도 회의실 배치 일정을 조정했습니다.", "log": "운송 차질 → 분할 납품 협의"},
			{"id": "silent", "label": "그냥 3일 뒤에 납품한다", "grade": "ok", "deltas": {"rep": -3}, "late_days": 3, "title": "3일 늦게 납품했어요", "body": "통보 없는 지연으로 [b]지체상금[/b]이 부과됩니다.", "log": "무통보 지연 3일"},
		],
	},
	"defect": {
		"kicker": "돌발 상황 · 출고 전 결함",
		"title": "탁자 5개 상판에 흠집이 있어요",
		"body": "박 실장: \"출고 전 점검에서 5개 상판에 긁힌 자국이 나왔어요. 교체하려면 하루와 비용이 더 들어요.\"",
		"options": [
			{"id": "replace", "label": "5개 상판을 교체한 뒤 출고한다", "grade": "good", "deltas": {"rep": 3}, "money": -500000, "title": "완벽한 상태로 출고했어요", "body": "비용은 들었지만 [b]규격에 맞는 물품[/b]만 납품합니다.", "log": "출고 전 결함 교체"},
			{"id": "mix", "label": "다른 탁자 사이에 섞어 그대로 보낸다", "grade": "bad", "deltas": {"risk": 6}, "flag": "결함출고", "title": "검수에서 드러날 거예요", "body": "결함 물품을 알면서 보내면 검수 불합격과 신뢰 하락으로 이어집니다.", "log": "결함 물품 그대로 출고"},
			{"id": "tell", "label": "시청에 알리고 45개 먼저, 5개는 이틀 뒤 납품", "grade": "good", "deltas": {"rep": 2}, "title": "투명하게 알렸어요", "body": "기관이 일정을 이해해 주었습니다. 5개는 교체해 이틀 뒤 납품합니다.", "log": "결함 사실 통보 후 분할 납품"},
		],
	},
}


static func pick(pool: Dictionary, rng_seed: int) -> String:
	var keys := pool.keys()
	keys.sort()
	return keys[posmod(rng_seed, keys.size())]


static func option(pool: Dictionary, event_id: String, option_id: String) -> Dictionary:
	if not pool.has(event_id):
		return {}
	for o in pool[event_id].options:
		if o.id == option_id:
			return o
	return {}
