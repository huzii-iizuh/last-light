extends RefCounted
## The level layout as plain data. tools/bake.gd built scenes/level.tscn from it; the game only
## reads it for test screenshots. To change the level now, edit level.tscn in the editor.

const BOTTOM := -14.0

# Platforms as [left, right, top]. The Ember clears gaps of about 3.5 wide or 1 high.
const PLATFORMS := [
	[-6.0, 6.0, 0.0], [8.0, 13.0, 0.0], [15.5, 20.0, 0.8], [23.0, 30.0, 0.0],  # 1 The Awakening
	[37.5, 41.0, 0.5], [48.5, 56.0, 1.0],                                       # 2 The Hidden Path
	[58.5, 63.0, 1.0], [65.0, 75.0, 1.0], [77.0, 87.0, 1.0], [89.0, 96.0, 1.5], # 3 The Frozen Passage
	[98.5, 106.0, 2.0], [121.5, 144.0, 3.5],                                    # 4 The Lighthouse
]
const WALLS := [[-9.0, -6.0, 7.0], [144.0, 147.0, 14.0]]
const HIDDEN := [[32.5, 35.0, 0.5], [43.5, 46.0, 1.5], [117.5, 119.5, 3.0]]
const SHRINES := [52.0, 93.0]
const LAMPS := [3.0, 18.0, 29.0, 39.0, 54.5, 62.5, 72.0, 85.0, 94.5, 105.0, 124.0, 130.0]
const ROTORS := [[69.5, 3.3], [118.5, 5.3]]       # [x, pivot y]
const CRUSHERS := [82.0]
const SLIDERS := [[111.0, 2.0, 3.0, 2.0]]         # [centre x, y, swing, speed]
const THORNS := [[102.0, 103.5]]
const LIGHTHOUSE_X := 138.0
const ENDING_X := 134.0
const CAPTIONS := [[97.0, "One ember remained."]]
const SIGNS := [
	[0.5, "A / D   move"],
	[9.5, "SPACE   jump"],
	[26.5, "Your light reveals\nwhat the dark hides"],
	[60.5, "Q / RIGHT-CLICK   Time Pulse\nfreezes blue-marked hazards"],
	[100.0, "Violet thorns are shadow.\nDo not touch them."],
	[110.0, "Freeze the platform to board it.\nWhen the pulse returns, freeze the blade."],
]


static func top_at(x: float) -> float:
	for p in PLATFORMS + HIDDEN:
		if x >= p[0] and x <= p[1]:
			return p[2]
	return 0.0
