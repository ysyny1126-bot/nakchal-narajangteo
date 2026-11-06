extends RefCounted

## Looks for the 3D office people, after the character sheet the user drew:
## big-head chibi proportions, one hairstyle, outfit colours and a hand prop each.

const SKIN := Color("#f2c3a0")

const LOOKS := {
	"lead_park": {
		"hair": "side", "hair_color": Color("#3b2f2a"), "top": "suit", "jacket": Color("#2c3a5e"), "shirt": Color("#f4f1ea"), "tie": Color("#f0b429"),
		"pants": Color("#2c3a5e"), "shoes": Color("#4a2c22"), "prop": "folder", "brows": 0.016, "width": 1.08,
		"idle": ["nod", "read", "look"],
	},
	"lead_han": {
		"hair": "bun", "hair_color": Color("#4a2f25"),
		"top": "jacket", "jacket": Color("#2a6f6c"), "shirt": Color("#f4f1ea"), "tie": Color(0, 0, 0, 0),
		"pants": Color("#4a4240"), "shoes": Color("#2a2424"), "prop": "tablet", "lanyard": true, "earrings": true,
		"idle": ["read", "point", "look"],
	},
	"lead_oh": {
		"hair": "short", "hair_color": Color("#2a221e"), "hat": true,
		"top": "vest", "jacket": Color("#3e4f6e"), "vest": Color("#c6dc3e"), "shirt": Color("#e9e6dc"), "tie": Color(0, 0, 0, 0),
		"pants": Color("#4b4f57"), "shoes": Color("#3a2e26"), "prop": "clipboard", "width": 1.12,
		"idle": ["point", "nod", "stretch"],
	},
	"peer_choi": {
		"hair": "bob", "hair_color": Color("#5a3626"),
		"top": "cardigan", "jacket": Color("#5f7a3c"), "shirt": Color("#f4f1ea"), "tie": Color(0, 0, 0, 0),
		"pants": Color("#3d3836"), "shoes": Color("#efe6d2"), "prop": "coffee", "lanyard": true, "earrings": true,
		"idle": ["sip", "type", "stretch"],
	},
	"visitor_civil": {
		"hair": "curly", "hair_color": Color("#2e231e"), "glasses": true,
		"top": "sweater", "jacket": Color("#dcc8a4"), "shirt": Color("#c8ccd6"), "tie": Color(0, 0, 0, 0),
		"pants": Color("#8a6646"), "shoes": Color("#f1efe9"), "prop": "envelope", "bag": true,
		"idle": ["scratch", "look"],
	},
	"visitor_vendor": {
		"hair": "slick", "hair_color": Color("#2f2420"),
		"top": "suit", "jacket": Color("#5c585a"), "shirt": Color("#f4f1ea"), "tie": Color("#e07a35"),
		"pants": Color("#5c585a"), "shoes": Color("#3a2620"), "prop": "briefcase", "smirk": true,
		"idle": ["wave", "look"],
	},
}


static func has(id: String) -> bool:
	return LOOKS.has(id)


static func get_look(id: String) -> Dictionary:
	return LOOKS.get(id, {})
