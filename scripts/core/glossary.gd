extends RefCounted

## Procurement terms (clickable inside dialogs, collected in the glossary book)
## and the three-question check quiz played at the end of each chapter.

const TERMS := {
	"spec": {"term": "구매 규격", "ep": 1, "def": "기관이 사려는 물품의 성능·치수·안전 기준 등을 적은 문서예요. 특정 상표가 아니라 성능으로 적어야 여러 업체가 공정하게 경쟁할 수 있어요."},
	"basis": {"term": "기초금액", "ep": 1, "def": "예정가격을 만들 때 기준이 되는 금액이에요. 기관이 시장 가격과 예산을 조사해 정해요."},
	"reserve": {"term": "복수예비가격", "ep": 1, "def": "기초금액의 ±2% 범위에서 만든 15개의 가격이에요. 업체들이 번호를 골라 예정가격 결정에 참여해요."},
	"estimate": {"term": "예정가격", "ep": 1, "def": "업체들이 가장 많이 고른 예비가격 4개의 평균이에요. 개찰 뒤에 공개되고 낙찰 하한선의 기준이 돼요."},
	"floor": {"term": "낙찰하한율", "ep": 1, "def": "예정가격 대비 이 비율보다 낮은 입찰은 제외돼요. 무리한 저가(덤핑)로 품질이 떨어지는 것을 막아요."},
	"qualify": {"term": "적격심사", "ep": 1, "def": "최저가 1순위 업체가 계약을 제대로 이행할 수 있는지 실적·경영상태·가격·신인도로 심사해요. 게임에서는 85점 이상 통과예요."},
	"sanction": {"term": "입찰참가자격 제한", "ep": 1, "def": "허위 서류, 담합, 금품 제공 같은 부정행위를 한 업체가 일정 기간 공공입찰에 참여하지 못하게 하는 제재예요."},
	"mall": {"term": "종합쇼핑몰", "ep": 2, "def": "공공기관이 계약된 상품을 인터넷 쇼핑하듯 비교하고 바로 주문(납품요구)할 수 있는 나라장터의 쇼핑몰이에요."},
	"mas": {"term": "다수공급자계약", "ep": 2, "def": "같은 종류의 물품을 여러 업체와 계약해 두고, 기관이 가격·품질·납기를 비교해 고르게 하는 방식이에요(MAS)."},
	"winwin": {"term": "상생세일", "ep": 2, "def": "쇼핑몰 할인 행사예요. 가격을 낮추는 대신 노출이 늘어요. 게임에서는 8% 할인·노출 15% 증가로 가정해요."},
	"collusion": {"term": "담합", "ep": 2, "def": "경쟁해야 할 업체들이 몰래 가격이나 낙찰자를 미리 정하는 행위예요. 공정한 경쟁을 해쳐 과징금과 입찰 제한 대상이 돼요."},
	"delivery": {"term": "계약 이행", "ep": 3, "def": "계약서에 적힌 물품을 약속한 품질·수량·기한대로 납품하는 일이에요. 문제가 생기면 미리 알리고 협의하는 것이 원칙이에요."},
	"delay": {"term": "지체상금", "ep": 3, "def": "정당한 사유 없이 납품이 늦어지면 늦어진 날수만큼 계약금액에서 깎는 금액이에요. 게임에서는 하루 0.075%로 가정해요."},
	"inspect": {"term": "검수", "ep": 3, "def": "납품된 물품이 규격서와 같은지 기관이 수량·품질을 확인하는 절차예요. 불합격하면 교체하거나 보완해야 해요."},
	"payment": {"term": "대금 지급", "ep": 3, "def": "검수에 합격하면 업체가 대금을 청구하고 기관이 정해진 기간 안에 지급해요. 실제 금액만 정확히 청구해야 해요."},
	"integrity": {"term": "청렴계약", "ep": 3, "def": "계약 과정에서 금품·향응을 주고받지 않겠다고 약속하는 것이에요. 어기면 계약 해제나 입찰 제한을 받을 수 있어요."},
	"warranty": {"term": "하자보수", "ep": 3, "def": "납품 뒤 정해진 기간 안에 생긴 결함을 업체가 고쳐 주는 책임이에요. 하자보수보증금으로 이행을 담보해요."},
}

const QUIZ := {
	1: [
		{"q": "공정한 구매 규격을 쓰는 방법으로 가장 알맞은 것은?", "options": ["익숙한 회사의 모델명을 그대로 적는다", "치수 범위·하중·안전 같은 성능 기준으로 적는다", "가격만 정하고 성능 기준은 뺀다"], "answer": 1, "explain": "성능 중심 규격이어야 여러 업체가 참여할 수 있고 품질도 지켜져요."},
		{"q": "낙찰하한율이 있는 이유는?", "options": ["무리한 저가 입찰(덤핑)로 품질이 떨어지는 것을 막으려고", "업체가 비싸게 팔 수 있게 하려고", "입찰 참가 업체 수를 줄이려고"], "answer": 0, "explain": "너무 낮은 금액은 납품 품질을 해칠 수 있어 일정 비율 아래 입찰은 제외해요."},
		{"q": "적격심사 점수가 조금 모자랄 때 올바른 행동은?", "options": ["실적을 조금 부풀린 서류를 낸다", "확인 가능한 실제 실적을 찾아 사실대로 낸다", "심사를 그냥 포기한다"], "answer": 1, "explain": "허위 서류는 실격과 입찰참가자격 제한 대상이에요. 사실인 서류만 제출해요."},
	],
	2: [
		{"q": "다수공급자계약(MAS)에서 기관이 상품을 고르는 기준은?", "options": ["가장 비싼 상품", "가격·납기·품질(디자인)을 함께 비교", "먼저 등록한 상품"], "answer": 1, "explain": "여러 공급자 상품을 가격만이 아니라 납기·품질까지 비교해 골라요."},
		{"q": "경쟁 업체가 \"우리끼리 가격을 맞추자\"고 제안하면?", "options": ["이익이 늘어나니 받아들인다", "거절하고 필요하면 신고한다", "못 들은 척 가격만 따라 올린다"], "answer": 1, "explain": "가격 담합은 과징금과 입찰 제한 대상이에요. 거절하고 신고할 수 있어요."},
		{"q": "원자재 가격이 내려갔을 때 공정한 대응은?", "options": ["판매가를 그대로 두고 이익을 챙긴다", "판매가 인하를 검토해 가격에 반영한다", "상품을 쇼핑몰에서 내린다"], "answer": 1, "explain": "원가가 내려가면 가격에 반영하는 것이 공정하고, 경쟁력도 올라가요."},
	],
	3: [
		{"q": "자재 공급이 늦어져 납기를 못 맞출 것 같을 때 먼저 할 일은?", "options": ["기관에 미리 알리고 사유를 증빙해 납기를 협의한다", "인증받지 않은 대체 자재로 몰래 만든다", "아무 말 없이 늦게 납품한다"], "answer": 0, "explain": "정당한 사유를 미리 알리고 협의하면 지체상금 없이 해결할 수 있는 경우가 많아요."},
		{"q": "지체상금이란?", "options": ["빨리 납품하면 받는 보너스", "납품이 늦어진 날수만큼 계약금액에서 깎는 금액", "검수 담당자에게 주는 수고비"], "answer": 1, "explain": "정당한 사유 없는 지연은 하루 단위로 계약금액에서 깎여요(게임 가정 0.075%/일)."},
		{"q": "검수에서 결함이 나왔을 때 올바른 대응은?", "options": ["검수관에게 상품권을 건네며 잘 봐달라고 한다", "결함 물품을 교체하고 다시 검수받는다", "결함을 숨기려고 서류를 고친다"], "answer": 1, "explain": "금품 제공은 청렴계약 위반이에요. 교체·보완 후 재검수를 받아요."},
	],
}


## Words that contain a term but mean something else (e.g. 검수관 = inspector).
const NOT_TERMS := ["검수관", "재검수", "검수대"]


## Wraps the first appearance of each known term in a clickable link.
static func link(text: String) -> String:
	var ids := TERMS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return str(TERMS[a].term).length() > str(TERMS[b].term).length())
	for id in ids:
		var word: String = TERMS[id].term
		var from := 0
		while true:
			var at := text.find(word, from)
			if at < 0:
				break
			var open := text.rfind("[url", at)
			var close := text.rfind("[/url]", at)
			var inside_other := false
			for other in NOT_TERMS:
				var o_at := text.find(other, maxi(at - other.length(), 0))
				if o_at >= 0 and o_at <= at and o_at + other.length() >= at + word.length():
					inside_other = true
			if open > close or inside_other:
				from = at + word.length()
				continue
			text = text.substr(0, at) + "[url=term:%s][color=#2f6f80][u]%s[/u][/color][/url]" % [id, word] + text.substr(at + word.length())
			break
	return text


static func count_for(ep: int) -> int:
	var n := 0
	for id in TERMS:
		if int(TERMS[id].ep) == ep:
			n += 1
	return n
