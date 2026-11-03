extends RefCounted

## "내 책상" items for 조달청 사원 키우기, grouped by how the employee gets them:
##   basic    — issued on the first day
##   rank     — issued on promotion (rank)
##   award    — commendation for an S grade
##   training — know-how from training / review notes (skills)
##   store    — bought with welfare points at the in-house store (snacks, small items)
## Icons are rendered in Unity (unity_cinematic/Assets/Editor/ItemIconRenderer.cs)
## into res://assets/items/<id>.png, so ids here must match the renderer.

## Ranks: 1 = 9급 서기보 … 5 = 5급 사무관.
const RANKS := ["", "9급 서기보", "8급 서기", "7급 주사보", "6급 주사", "5급 사무관"]

const CATEGORIES := [
	{"id": "all", "name": "전체", "icon": "all"},
	{"id": "supply", "name": "비품", "icon": "tool"},
	{"id": "skill", "name": "스킬", "icon": "skill"},
	{"id": "store", "name": "간식·소품", "icon": "snack"},
]

const ITEMS := {
	"calculator": {"name": "계산기", "cat": "supply", "src": "basic", "effect": "개찰·가격 카드 행동력 -1", "desc": "예정가격 평균도, 낙찰하한율도 척척."},
	"planner": {"name": "업무 수첩", "cat": "supply", "src": "basic", "effect": "모든 카드 마감 +1일", "desc": "마감일을 적어 두면 미루기가 덜 무서워져요."},
	"stamp": {"name": "결재 도장", "cat": "supply", "src": "basic", "effect": "하루 한 번 '빠르게' 카드 1장 실수 방지", "desc": "쾅! 한 번 더 확인했다는 증거."},
	"clock": {"name": "탁상시계", "cat": "supply", "src": "basic", "effect": "마감 하루 전 카드에 알림", "desc": "따르릉! 오늘 마감인 건 없나요?"},
	"dual_monitor": {"name": "듀얼 모니터", "cat": "supply", "src": "rank", "rank": 3, "effect": "하루 행동력 +1", "desc": "규격서와 공고문을 나란히 띄워 놓고 비교해요."},
	"nameplate": {"name": "금장 명패", "cat": "supply", "src": "rank", "rank": 4, "effect": "민원 카드 평판 +1", "desc": "6급 주사가 되면 책상에 올라가는 반짝이는 명패."},
	"trophy": {"name": "청장 표창 트로피", "cat": "supply", "src": "award", "how": "에피소드 S등급", "effect": "모든 실적 +10%", "desc": "원칙을 지키며 성과도 낸 사람에게 주는 표창."},
	"law_book": {"name": "법령집", "cat": "skill", "src": "training", "how": "법령 교육 이수", "effect": "'빠르게' 처리할 때 숨은 실수 확률 -10%", "desc": "국가계약법과 시행령을 한 번 정리해 두면 든든해요."},
	"highlighter": {"name": "형광펜", "cat": "skill", "src": "training", "how": "오답 노트 3장", "effect": "카드의 함정 문구에 형광 밑줄 표시", "desc": "\"반드시 ○○사 제품\" 같은 문구가 저절로 눈에 들어와요."},
	"magnifier": {"name": "돋보기", "cat": "skill", "src": "training", "how": "감사 주간 실수 0건", "effect": "하루 한 번 숨은 실수가 있는지 미리 확인", "desc": "첨부 서류의 작은 글씨까지 꼼꼼히."},
	"coffee": {"name": "아메리카노", "cat": "store", "src": "store", "price": 120, "use": true, "effect": "체력 +1", "desc": "출근길 필수품. 오후 세 시에도 유효해요."},
	"ramen": {"name": "컵라면", "cat": "store", "src": "store", "price": 150, "use": true, "effect": "야근: 오늘 카드 1장 더, 다음 날 체력 -1", "desc": "급할 땐 좋지만 매일 먹으면 곤란해요."},
	"vitamin": {"name": "비타민", "cat": "store", "src": "store", "price": 250, "use": true, "effect": "체력 +2", "desc": "감사 주간 전날 추천."},
	"tangerine": {"name": "귤 바구니", "cat": "store", "src": "store", "price": 200, "use": true, "effect": "팀 간식: 오늘 민원 카드 평판 +1", "desc": "팀원들과 나눠 먹으면 분위기가 말랑해져요."},
	"plant": {"name": "초록 화분", "cat": "store", "src": "store", "price": 400, "effect": "매일 아침 체력 +1 (10% 확률)", "desc": "초록이 하나만 있어도 책상이 살아나요."},
	"lamp": {"name": "스탠드 조명", "cat": "store", "src": "store", "price": 350, "effect": "야근해도 다음 날 체력 감소 없음 (주 1회)", "desc": "따뜻한 불빛 아래라면 서류도 덜 차가워요."},
}

## Order shown in the grid.
const ORDER := ["calculator", "planner", "stamp", "clock", "dual_monitor", "nameplate", "trophy", "law_book", "highlighter", "magnifier", "coffee", "ramen", "vitamin", "tangerine", "plant", "lamp"]

## Short "how you get it" label shown on each slot.
const SOURCE_LABEL := {"basic": "기본 지급", "award": "표창", "training": "교육·노하우", "store": "구내매점"}


static func icon_path(id: String) -> String:
	return "res://assets/items/%s.png" % id


static func how(id: String) -> String:
	var item: Dictionary = ITEMS[id]
	match str(item.src):
		"rank": return "%s 승진" % RANKS[int(item.rank)].split(" ")[0]
		"award", "training": return str(item.how)
	return SOURCE_LABEL[item.src]


## How many the employee has. Issued items count as 1 once their condition is met.
## desk = profile.desk: {"points", "rank", "owned": {id: n}, "earned": [ids]}.
static func count(id: String, desk: Dictionary) -> int:
	var item: Dictionary = ITEMS[id]
	match str(item.src):
		"basic": return 1
		"rank": return 1 if int(desk.rank) >= int(item.rank) else 0
		"award", "training": return 1 if (desk.earned as Array).has(id) else 0
	return int((desk.owned as Dictionary).get(id, 0))
