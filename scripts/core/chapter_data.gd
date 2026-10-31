extends RefCounted

## Chapter goals, routes, briefings and step-by-step guidance text.

const EP := {
	1: {
		"code": "EP01",
		"title": "구매 규격과 입찰",
		"goal": "공정한 구매 규격 작성부터 입찰 준비, 투찰·개찰, 적격심사까지 조달 한 건의 흐름을 경험합니다.",
		"route": ["규격 검토", "공고·원가 확인", "투찰·개찰", "심사 결과"],
		"role": "○○시청 구매 담당 → 한빛퍼니처 대표 (나라미)",
		"situation": "시청이 회의용 탁자 50개를 구매합니다. 먼저 공무원 입장에서 구매 규격을 정하고, 이어서 업체 대표가 되어 입찰에 참여합니다.",
		"learn": "특정 제품에 유리하지 않은 규격, 복수예비가격과 낙찰하한율, 적격심사가 왜 필요한지 이해합니다.",
	},
	2: {
		"code": "EP02",
		"title": "종합쇼핑몰",
		"goal": "상품의 가격·납기·디자인과 판매촉진 선택이 매출과 이익에 미치는 영향을 비교합니다.",
		"route": ["상품 등록", "구매 비교", "판매 방식 선택", "4분기 손익 확인"],
		"role": "한빛퍼니처 대표 (나라미)",
		"situation": "한빛퍼니처가 나라장터 종합쇼핑몰에 회의용 탁자를 등록합니다. 공공기관 구매 담당자는 여러 업체 상품을 비교해 고릅니다.",
		"learn": "다수공급자계약(MAS) 상품의 가격·납기·품질이 선택받는 데 어떻게 작용하는지, 판매촉진이 손익에 주는 영향을 비교합니다.",
	},
	3: {
		"code": "EP03",
		"title": "납품·검수·대금",
		"goal": "계약한 탁자를 약속대로 납품하고, 검수를 통과해 대금을 정확히 받기까지 계약 이행의 마지막 단계를 경험합니다.",
		"route": ["납품 준비", "돌발 상황 대응", "검수", "대금 청구"],
		"role": "한빛퍼니처 대표 (나라미)",
		"situation": "○○시청과 맺은 회의용 탁자 50개 계약의 납품일이 다가옵니다. 출고 준비 중 예상하지 못한 일이 생깁니다.",
		"learn": "계약 이행 중 문제가 생기면 미리 알리고 협의해야 하는 이유, 지체상금·검수·청렴계약·대금 지급의 의미를 이해합니다.",
	},
}

## Short in-engine scenario played before each chapter. Positions are world
## coordinates inside the given room; `mascots` = [Nareumi, Dali].
const SCENARIO := {
	1: [
		{"room": "city", "time": 5.0, "speaker": "○○시청 이 주무관",
			"text": "본관 회의실에 쓸 [b]회의용 탁자 50개[/b]가 필요해요. 무엇을 살지, 누구나 공정하게 참여할 수 있게 정해야 해요.",
			"cam": [Vector3(0.4, 6.4, 7.0), Vector3(0.9, 3.3, 4.3)], "look": [Vector3(0.3, 0.4, -0.6), Vector3(0.5, 0.7, -1.1)],
			"mascots": [Vector3(-0.9, 0, 0.15), Vector3(-0.2, 0, 0.3)]},
		{"room": "office", "time": 5.0, "speaker": "나라미 · 한빛퍼니처 대표",
			"text": "나라장터에 [b]입찰공고[/b]가 올라왔어요! 공고문과 원가부터 확인하고 투찰가를 정해야겠어요.",
			"cam": [Vector3(-2.6, 2.7, 4.0), Vector3(2.2, 2.6, 3.8)], "look": [Vector3(-1.6, 0.7, -1.4), Vector3(1.8, 0.7, -0.6)],
			"mascots": [Vector3(-0.2, 0, -0.25), Vector3(0.5, 0, -0.1)]},
		{"room": "review", "time": 4.6, "speaker": "조달청 윤서진 계약관",
			"text": "가장 낮은 가격을 써도 끝이 아니에요. 약속을 지킬 수 있는지 [b]적격심사[/b]를 받아야 합니다.",
			"cam": [Vector3(1.0, 3.6, 5.6), Vector3(1.3, 2.2, 3.1)], "look": [Vector3(1.2, 0.8, -1.4), Vector3(1.4, 0.9, -1.6)],
			"mascots": [Vector3(0.3, 0, 0.1), Vector3(1.0, 0, 0.25)]},
		{"room": "city", "time": 4.4, "speaker": "달이", "cheer": true, "fov": 30.0,
			"text": "나라미, 조달 한 건을 처음부터 끝까지 [b]같이 해내 봐요![/b]",
			"cam": [Vector3(-0.35, 1.3, 4.0), Vector3(-0.35, 1.05, 3.1)], "look": [Vector3(-0.35, 0.3, 0.9), Vector3(-0.35, 0.3, 0.9)],
			"mascots": [Vector3(-0.7, 0, 0.9), Vector3(0.0, 0, 1.05)]},
	],
	2: [
		{"room": "showroom", "time": 5.0, "speaker": "나라미 · 한빛퍼니처 대표",
			"text": "이번엔 [b]나라장터 종합쇼핑몰[/b]! 공공기관이 여러 회사의 탁자를 비교해서 사요.",
			"cam": [Vector3(-3.4, 3.0, 4.6), Vector3(2.2, 2.4, 3.8)], "look": [Vector3(-3.1, 0.7, -1.7), Vector3(1.8, 0.7, -1.7)],
			"mascots": [Vector3(-2.2, 0, 0.6), Vector3(-1.5, 0, 0.75)]},
		{"room": "showroom", "time": 4.6, "speaker": "○○시청 이 주무관",
			"text": "[b]가격·납기·디자인[/b]을 함께 보고 점수를 매겨요. 할인 행사에 참여한 상품도 눈여겨보죠.",
			"cam": [Vector3(2.6, 2.4, 3.4), Vector3(3.2, 1.9, 2.0)], "look": [Vector3(3.5, 1.2, -1.3), Vector3(3.7, 1.3, -1.35)],
			"mascots": [Vector3(2.3, 0, 0.4), Vector3(3.0, 0, 0.55)]},
		{"room": "showroom", "time": 4.4, "speaker": "달이", "cheer": true, "fov": 30.0,
			"text": "좋은 상품을 공정한 가격으로! [b]1년 손익[/b]이 어떻게 달라지는지 지켜봐요.",
			"cam": [Vector3(-1.6, 1.3, 4.3), Vector3(-1.6, 1.05, 3.3)], "look": [Vector3(-1.6, 0.3, 1.0), Vector3(-1.6, 0.3, 1.0)],
			"mascots": [Vector3(-1.95, 0, 1.0), Vector3(-1.25, 0, 1.15)]},
	],
	3: [
		{"room": "warehouse", "time": 5.0, "speaker": "박 실장 · 한빛퍼니처",
			"text": "대표님, 드디어 [b]납품 주간[/b]이에요! 탁자 50개, 포장까지 거의 끝났어요.",
			"cam": [Vector3(-3.6, 2.8, 4.2), Vector3(-1.2, 2.3, 3.6)], "look": [Vector3(-2.6, 0.6, 0.0), Vector3(-1.6, 0.6, -0.2)],
			"mascots": [Vector3(-1.2, 0, 1.2), Vector3(-0.5, 0, 1.35)]},
		{"room": "warehouse", "time": 4.8, "speaker": "○○시청 최 검수관",
			"text": "납품된 탁자가 [b]규격서대로[/b]인지 수량·치수·하중·마감을 하나하나 확인합니다.",
			"cam": [Vector3(1.6, 2.6, 2.6), Vector3(1.0, 1.9, 1.6)], "look": [Vector3(0.9, 0.8, -1.6), Vector3(1.1, 0.9, -1.8)],
			"mascots": [Vector3(0.0, 0, 0.0), Vector3(0.7, 0, 0.15)]},
		{"room": "warehouse", "time": 4.4, "speaker": "달이", "cheer": true, "fov": 30.0,
			"text": "계약은 [b]약속[/b]이에요. 끝까지 제대로 지켜 봐요!",
			"cam": [Vector3(-0.3, 1.3, 4.3), Vector3(-0.3, 1.05, 3.3)], "look": [Vector3(-0.3, 0.3, 1.0), Vector3(-0.3, 0.3, 1.0)],
			"mascots": [Vector3(-0.65, 0, 1.0), Vector3(0.05, 0, 1.15)]},
	],
}

const STAGE := {
	"city": 0, "office": 1, "result": 2, "review": 3, "ep1done": 4,
	"register": 0, "compare": 1, "sale": 2, "sales": 3, "ep2done": 4,
	"deliver": 0, "event": 1, "inspect": 2, "invoice": 3, "ep3done": 4,
}

const ROOM_OF := {
	"city": "city", "office": "office", "result": "office", "review": "review", "ep1done": "review",
	"register": "showroom", "compare": "showroom", "sale": "showroom", "sales": "showroom", "ep2done": "showroom",
	"deliver": "warehouse", "event": "warehouse", "inspect": "warehouse", "invoice": "warehouse", "ep3done": "warehouse",
}

## Which hotspot is the current objective.
static func next_target(state: Dictionary) -> String:
	var found: Array = state.get("found", [])
	match str(state.step):
		"city":
			if not found.has("request"): return "request"
			if not found.has("sample"): return "sample"
			return "spec"
		"office":
			if not found.has("notice"): return "notice"
			if not found.has("ledger"): return "ledger"
			return "terminal"
		"result": return "terminal"
		"review":
			if not found.has("criteria"): return "criteria"
			if not found.has("binder"): return "binder"
			return "submit"
		"register": return "catalog"
		"compare": return "buyer"
		"sale", "sales": return "terminal"
		"deliver":
			if not found.has("schedule"): return "schedule"
			return "park"
		"event": return "park"
		"inspect": return "inspect"
		"invoice": return "invoice"
	return ""


## Is a hotspot locked in the current state? Returns the reason or "".
static func lock_reason(state: Dictionary, id: String) -> String:
	var found: Array = state.get("found", [])
	match id:
		"spec":
			if not (found.has("request") and found.has("sample")):
				return "구매 요청서와 견본 탁자를 먼저 확인하세요."
		"terminal":
			if state.step == "office" and not (found.has("notice") and found.has("ledger")):
				return "공고문과 원가 장부를 먼저 확인하세요."
			if state.step in ["register", "compare"]:
				return "상품 등록과 구매 비교를 먼저 마치세요."
		"submit":
			if not (found.has("criteria") and found.has("binder")):
				return "심사 기준표와 제출 서류철을 먼저 확인하세요."
		"buyer":
			if state.step == "register":
				return "한빛 상품을 먼저 등록하세요."
		"park":
			if state.step == "deliver" and not found.has("schedule"):
				return "납품 일정표를 먼저 확인하세요."
		"inspect":
			if state.step in ["deliver", "event"]:
				return "출고 준비(박 실장)를 먼저 마치세요."
		"invoice":
			if state.step in ["deliver", "event", "inspect"]:
				return "검수에 합격해야 대금을 청구할 수 있어요."
	return ""


static func objective(state: Dictionary) -> String:
	var found: Array = state.get("found", [])
	match str(state.step):
		"city":
			if not found.has("request"): return "구매 요청서를 읽고 무엇이 필요한지 확인하세요."
			if not found.has("sample"): return "견본 탁자에서 확인할 성능 기준을 살펴보세요."
			return "규격서 책상에서 구매 규격을 작성하세요."
		"office":
			var n := int(found.has("notice")) + int(found.has("ledger"))
			if n < 2: return "공고문과 원가 장부를 확인하세요. (%d/2)" % n
			return "입찰 단말에서 예비가격 2개를 고르고 투찰하세요."
		"result": return "입찰 단말에서 개찰 결과를 확인하세요."
		"review":
			if not found.has("criteria"): return "심사 기준표에서 통과 점수를 확인하세요."
			if not found.has("binder"): return "한빛 제출 서류철을 확인하세요."
			return "서류 접수 창구에서 적격심사 서류를 제출하세요."
		"ep1done": return "EP01 완료 · 종합쇼핑몰 업무로 이동합니다."
		"register": return "한빛 상품 등록대에서 가격·납기·디자인을 정하세요."
		"compare": return "구매 담당자와 함께 경쟁 상품을 비교하세요."
		"sale": return "분기 판매 단말에서 상생세일 참여 여부를 정하세요."
		"sales": return "분기 판매 단말에서 분기 실적을 확인하세요. (%d/4)" % (state.get("quarters", []) as Array).size()
		"ep2done": return "EP02 완료 · EP03 납품·검수로 이어집니다."
		"deliver":
			if not found.has("schedule"): return "납품 일정표에서 납기와 계약 조건을 확인하세요."
			return "박 실장에게 가서 출고 준비 상황을 확인하세요."
		"event": return "박 실장과 돌발 상황 대응을 정하세요."
		"inspect": return "검수대에서 최 검수관의 검수를 받으세요."
		"invoice": return "대금 청구 단말에서 대금을 청구하세요."
		"ep3done": return "EP03 완료 · 엔딩을 확인하세요."
	return "타이틀에서 업무를 시작하세요."


static func dali_line(state: Dictionary) -> String:
	var found: Array = state.get("found", [])
	match str(state.step):
		"city":
			if not found.has("request"): return "왼쪽 벽 화이트보드의 구매 요청서부터 읽어 봐요."
			if not found.has("sample"): return "오른쪽 견본 탁자를 보면 어떤 성능을 적을지 감이 와요."
			if not found.has("rules"): return "중앙 책상으로 가서 구매 규격 검토를 시작해요. 규정집도 참고할 수 있어요."
			return "중앙 책상으로 가서 구매 규격 검토를 시작해요."
		"office":
			if not found.has("notice"): return "공고문과 원가 장부를 확인하면 입찰 단말이 열려요. 공고문은 왼쪽 벽이에요."
			if not found.has("ledger"): return "책상 위 원가 장부로 가요. 원가를 알아야 손해 없이 투찰할 수 있어요."
			return "준비 끝! 오른쪽 앞 입찰 단말로 가서 투찰해요."
		"result": return "입찰 단말에서 결과를 다시 볼 수 있어요."
		"review":
			if not found.has("criteria"): return "뒤쪽 벽 심사 기준표에서 몇 점이면 통과인지 먼저 봐요."
			if not found.has("binder"): return "왼쪽 탁자의 서류철로 가요. 실적이 충분한지 확인해야 해요."
			if not found.has("archive"): return "실적이 조금 부족해 보여요. 오른쪽 보관함에 빠진 실제 기록이 있을지도 몰라요."
			return "이제 접수 창구에서 서류를 제출해요. 사실대로가 원칙이에요."
		"ep1done": return "EP01을 마쳤어요. 다음은 종합쇼핑몰이에요!"
		"register": return "왼쪽 한빛 등록대에서 가격·납기·디자인을 정해요."
		"compare": return "가운데 이 주무관에게 가서 경쟁 상품과 비교해 봐요."
		"sale": return "오른쪽 판매 단말에서 상생세일에 참여할지 정해요."
		"sales": return "판매 단말에서 다음 분기 실적을 확인해요."
		"ep2done": return "수고했어요! 이제 계약한 탁자를 납품하러 가요."
		"deliver":
			if not found.has("schedule"): return "왼쪽 벽 납품 일정표부터 봐요. 납기가 언제인지 알아야 해요."
			return "출고장의 박 실장에게 가요. 뭔가 걱정스러운 얼굴이에요."
		"event": return "문제가 생기면 숨기지 말고 알리는 게 원칙이에요."
		"inspect": return "가운데 검수대로 가요. 최 검수관이 기다리고 있어요."
		"invoice": return "오른쪽 단말에서 대금을 청구해요. 실제 금액만 정확히요!"
		"ep3done": return "1년 동안 정말 수고했어요! 우리 이야기의 끝을 보러 가요."
	return "업무 시작을 누르면 함께 출발해요."
