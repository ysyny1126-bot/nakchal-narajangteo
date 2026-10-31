extends RefCounted

## Bid, qualification and sales math. The structure follows the real process
## (15 multiple reserve prices, 4 most-picked averaged, a bid floor, a
## qualification score) but every number here is a GAME ASSUMPTION and is
## labelled as such on screen.

const BASIS := 40000000
const UNIT_COST := 520000
const UNITS := 50
const LOGISTICS := 550000
const BID_FLOOR := 0.87745
const PASS_SCORE := 85.0
const COMPETITORS := ["대성오피스", "새길가구", "온누리산업", "정우퍼니처", "한결오피스"]

const PRODUCTS := {
	"value": {"name": "실속형", "price": 780000, "cost": 560000, "weeks": 5, "design": 1, "grade": "C"},
	"balanced": {"name": "균형형", "price": 860000, "cost": 600000, "weeks": 4, "design": 2, "grade": "B"},
	"design": {"name": "디자인형", "price": 980000, "cost": 730000, "weeks": 2, "design": 3, "grade": "A"},
}
const RIVALS := [
	{"name": "대성 베이직", "price": 830000, "weeks": 4, "design": 2, "grade": "B"},
	{"name": "새길 모던", "price": 940000, "weeks": 3, "design": 3, "grade": "A"},
]
const QUARTER_DEMAND := [60, 80, 90, 110]
const QUARTER_FIXED := 2500000
const SALE_DISCOUNT := 0.08
const SALE_EXPOSURE := 1.15
const PRICE_CUT := 0.97


static func total_cost() -> int:
	return UNIT_COST * UNITS + LOGISTICS


## 15 reserve prices within ±2% of the basis amount, rounded to 1,000 won.
static func reserve_prices(seed: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var prices: Array[int] = []
	for i in range(15):
		var band_low := -0.02 + float(i) * (0.04 / 15.0)
		var rate := band_low + rng.randf() * (0.04 / 15.0)
		prices.append(int(round(float(BASIS) * (1.0 + rate) / 1000.0)) * 1000)
	return prices


static func run_bid(seed: int, prices: Array[int], picks: Array[int], bid: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 31 + 7
	var counts: Array[int] = []
	counts.resize(15)
	counts.fill(0)
	for p in picks:
		counts[p] += 1
	for _i in range(COMPETITORS.size()):
		var a := rng.randi_range(0, 14)
		var b := rng.randi_range(0, 14)
		while b == a:
			b = rng.randi_range(0, 14)
		counts[a] += 1
		counts[b] += 1
	var order: Array[int] = []
	for i in range(15):
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool:
		if counts[x] == counts[y]:
			return x < y
		return counts[x] > counts[y]
	)
	var drawn: Array[int] = order.slice(0, 4)
	var estimate := 0
	for i in drawn:
		estimate += prices[i]
	estimate = int(round(float(estimate) / 4.0))
	var floor_price := int(ceil(float(estimate) * BID_FLOOR))
	var bids: Array[Dictionary] = []
	for i in range(COMPETITORS.size()):
		var rate := rng.randf_range(0.874, 0.915)
		bids.append({"name": COMPETITORS[i], "bid": int(round(float(BASIS) * rate / 1000.0)) * 1000, "me": false})
	bids.append({"name": "한빛퍼니처", "bid": bid, "me": true})
	for item in bids:
		item["valid"] = int(item.bid) >= floor_price
	bids.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x.valid != y.valid:
			return x.valid
		if x.bid == y.bid:
			return not x.me
		return x.bid < y.bid
	)
	var rank := 0
	var valid_rank := 0
	for item in bids:
		if item.valid:
			valid_rank += 1
			item["rank"] = valid_rank
			if item.me:
				rank = valid_rank
		else:
			item["rank"] = 0
	return {
		"counts": counts,
		"drawn": drawn,
		"estimate": estimate,
		"floor": floor_price,
		"bids": bids,
		"bid": bid,
		"rank": rank,
		"rate": float(bid) / float(estimate),
		"profit": bid - total_cost(),
	}


## Qualification score (game simplification of the PPS scoring sheet).
static func review_score(bid_rate: float, archive_found: bool, rep: int, risk: int) -> Dictionary:
	var record := 30.0 + (8.0 if archive_found else 0.0)
	var finance := 22.0
	var price := clampf(30.0 - 200.0 * absf(0.88 - bid_rate), 15.0, 30.0)
	var credit := (2.0 if rep >= 40 else 0.0) - (2.0 if risk >= 10 else 0.0)
	var total := record + finance + price + credit
	return {"record": record, "finance": finance, "price": price, "credit": credit, "total": total, "pass": total >= PASS_SCORE}


## Buyer attractiveness (price 60%, delivery 22%, design 18%).
static func market(product_id: String, sale: bool, price_cut: bool) -> Array[Dictionary]:
	var p: Dictionary = PRODUCTS[product_id]
	var price := float(p.price) * (PRICE_CUT if price_cut else 1.0) * (1.0 - SALE_DISCOUNT if sale else 1.0)
	var items: Array[Dictionary] = [{"name": "한빛 " + p.name, "price": price, "weeks": p.weeks, "design": p.design, "grade": p.grade, "me": true}]
	for r in RIVALS:
		items.append({"name": r.name, "price": float(r.price), "weeks": r.weeks, "design": r.design, "grade": r.grade, "me": false})
	var min_price := INF
	var min_weeks := INF
	for item in items:
		min_price = minf(min_price, item.price)
		min_weeks = minf(min_weeks, float(item.weeks))
	var total_weight := 0.0
	for item in items:
		var score := 0.6 * pow(min_price / item.price, 3.0) + 0.22 * (min_weeks / float(item.weeks)) + 0.18 * (float(item.design) / 3.0)
		item["score"] = score * 100.0
		item["weight"] = pow(score, 4.0)
		total_weight += item.weight
	for item in items:
		item["share"] = item.weight / total_weight
	return items


static func quarter(product_id: String, q: int, sale: bool, price_cut: bool, buyer_pick: bool, seed: int) -> Dictionary:
	var p: Dictionary = PRODUCTS[product_id]
	var items := market(product_id, sale, price_cut)
	var mine: Dictionary = items[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + q * 101
	var demand := float(QUARTER_DEMAND[q]) * rng.randf_range(0.95, 1.05)
	var exposure := (SALE_EXPOSURE if sale else 1.0) * (1.08 if buyer_pick else 1.0)
	var sold := int(round(demand * exposure * mine.share))
	var unit_price := int(round(mine.price))
	var revenue := sold * unit_price
	var cost := sold * int(p.cost) + QUARTER_FIXED
	return {"q": q + 1, "demand": int(round(demand * exposure)), "share": mine.share, "sold": sold, "unit_price": unit_price, "revenue": revenue, "cost": cost, "profit": revenue - cost}


static func fmt(value: int) -> String:
	var negative := value < 0
	var s := str(absi(value))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if negative else "") + out


static func man(value: int) -> String:
	return "%s만 원" % fmt(int(round(float(value) / 10000.0)))
