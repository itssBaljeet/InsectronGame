extends GutTest

func test_meteormyte_stat_round_trip() -> void:
	var original := MeteormyteStat.new()
	original.statType = MeteormyteStat.StatType.ATTACK
	original.baseStat = 75
	original.individualValue = 10
	original.effortValue = 120
	original.level = 12
	original.gemCutModifier = 0.1
	original.recalculateStats()

	var serialized := original.toDict()
	var from_dict := MeteormyteStat.fromDict(serialized)

	var manual := MeteormyteStat.new()
	manual.statType = MeteormyteStat.StatType.ATTACK
	manual.baseStat = 75
	manual.individualValue = 10
	manual.effortValue = 120
	manual.level = 12
	manual.gemCutModifier = 0.1
	manual.recalculateStats()

	assert_eq(from_dict.statType, manual.statType, "Stat type should match")
	assert_eq(from_dict.baseStat, manual.baseStat, "Base stat should match")
	assert_eq(from_dict.individualValue, manual.individualValue, "IV should match")
	assert_eq(from_dict.effortValue, manual.effortValue, "EV should match")
	assert_eq(from_dict.level, manual.level, "Level should match")
	assert_almost_eq(from_dict.gemCutModifier, manual.gemCutModifier, 0.0001, "Gem modifier should match")
	assert_eq(from_dict.toDict(), serialized, "Serializing after deserializing should reproduce the same data")

func test_board_pattern_round_trip() -> void:
	var original := BoardPattern.new()
	original.offsets = [Vector3i(1, 0, 0), Vector3i(0, 1, 0)]

	var serialized := original.toDict()
	var from_dict := BoardPattern.fromDict(serialized)

	var manual := BoardPattern.new()
	manual.offsets = [Vector3i(1, 0, 0), Vector3i(0, 1, 0)]

	assert_eq(from_dict.offsets, manual.offsets, "Offsets should round trip")
	assert_eq(from_dict.toDict(), serialized, "BoardPattern serialization should be stable")

func test_gem_data_round_trip() -> void:
	var original := GemData.new()
	original.quality = GemData.GemQuality.EPIC
	original.cut = GemData.GemCut.BALANCED
	original.customCutName = "Prismatic"

	var serialized := original.toDict()
	var from_dict := GemData.fromDict(serialized)

	var manual := GemData.new()
	manual.quality = GemData.GemQuality.EPIC
	manual.cut = GemData.GemCut.BALANCED
	manual.customCutName = "Prismatic"

	assert_eq(int(from_dict.quality), int(manual.quality), "Gem quality should match")
	assert_eq(int(from_dict.cut), int(manual.cut), "Gem cut should match")
	assert_eq(from_dict.customCutName, manual.customCutName, "Custom cut name should match")
	assert_eq(from_dict.toDict(), serialized, "GemData serialization should be stable")

func test_status_effect_round_trip() -> void:
	var original := StatusEffectResource.new()
	original.effectName = "Soothing Aura"
	original.effectType = StatusEffectResource.EffectType.BUFF
	original.baseDuration = 4
	original.maxStacks = 2
	original.stackable = true
	original.refreshDurationOnStack = false
	original.isPersistent = true
	original.statStages = {"Attack": -2}
	original.damagePerTurn = 3
	original.damageScalesWithStacks = false
	original.stackDamageFormula = "3,3,3"
	original.appliesOnTurnStart = true
	original.appliesOnTurnEnd = false
	original.preventsAction = false
	original.preventsMovement = true
	original.immunities = ["Burn"]

	var serialized := original.toDict()
	var from_dict := StatusEffectResource.fromDict(serialized)

	var manual := StatusEffectResource.new()
	manual.effectName = "Soothing Aura"
	manual.effectType = StatusEffectResource.EffectType.BUFF
	manual.baseDuration = 4
	manual.maxStacks = 2
	manual.stackable = true
	manual.refreshDurationOnStack = false
	manual.isPersistent = true
	manual.statStages = {"Attack": -2}
	manual.damagePerTurn = 3
	manual.damageScalesWithStacks = false
	manual.stackDamageFormula = "3,3,3"
	manual.appliesOnTurnStart = true
	manual.appliesOnTurnEnd = false
	manual.preventsAction = false
	manual.preventsMovement = true
	manual.immunities = ["Burn"]

	assert_eq(from_dict.effectName, manual.effectName, "Effect name should match")
	assert_eq(int(from_dict.effectType), int(manual.effectType), "Effect type should match")
	assert_eq(from_dict.baseDuration, manual.baseDuration, "Duration should match")
	assert_eq(from_dict.maxStacks, manual.maxStacks, "Max stacks should match")
	assert_eq(from_dict.stackable, manual.stackable, "Stackable flag should match")
	assert_eq(from_dict.refreshDurationOnStack, manual.refreshDurationOnStack, "Refresh behavior should match")
	assert_eq(from_dict.isPersistent, manual.isPersistent, "Persistence should match")
	assert_eq(from_dict.statStages, manual.statStages, "Stat stages should match")
	assert_eq(from_dict.damagePerTurn, manual.damagePerTurn, "Damage per turn should match")
	assert_eq(from_dict.damageScalesWithStacks, manual.damageScalesWithStacks, "Stack scaling should match")
	assert_eq(from_dict.stackDamageFormula, manual.stackDamageFormula, "Damage formula should match")
	assert_eq(from_dict.appliesOnTurnStart, manual.appliesOnTurnStart, "Turn start application should match")
	assert_eq(from_dict.appliesOnTurnEnd, manual.appliesOnTurnEnd, "Turn end application should match")
	assert_eq(from_dict.preventsAction, manual.preventsAction, "Action prevention should match")
	assert_eq(from_dict.preventsMovement, manual.preventsMovement, "Movement prevention should match")
	assert_eq(from_dict.immunities, manual.immunities, "Immunities should match")
	assert_eq(from_dict.toDict(), serialized, "StatusEffectResource serialization should be stable")

func test_hazard_resource_round_trip() -> void:
	var original := HazardResource.new()
	original.hazardName = "Flame Patch"
	original.baseDuration = 5
	original.maxStacks = 3
	original.stackable = true
	original.damageOnEnter = 10
	original.damagePerTurn = 6
	original.clearableByTypes = ["water"]
	original.clearsOnExit = true
	original.affectsFactions = 3
	original.blockMovement = true
	original.blockVision = true

	var serialized := original.toDict()
	var from_dict := HazardResource.fromDict(serialized)

	var manual := HazardResource.new()
	manual.hazardName = "Flame Patch"
	manual.baseDuration = 5
	manual.maxStacks = 3
	manual.stackable = true
	manual.damageOnEnter = 10
	manual.damagePerTurn = 6
	manual.clearableByTypes = ["water"]
	manual.clearsOnExit = true
	manual.affectsFactions = 3
	manual.blockMovement = true
	manual.blockVision = true

	assert_eq(from_dict.hazardName, manual.hazardName, "Hazard name should match")
	assert_eq(from_dict.baseDuration, manual.baseDuration, "Hazard duration should match")
	assert_eq(from_dict.maxStacks, manual.maxStacks, "Hazard stacks should match")
	assert_eq(from_dict.stackable, manual.stackable, "Stackable flag should match")
	assert_eq(from_dict.damageOnEnter, manual.damageOnEnter, "Damage on enter should match")
	assert_eq(from_dict.damagePerTurn, manual.damagePerTurn, "Damage per turn should match")
	assert_eq(from_dict.clearableByTypes, manual.clearableByTypes, "Clearable types should match")
	assert_eq(from_dict.clearsOnExit, manual.clearsOnExit, "Clears on exit should match")
	assert_eq(from_dict.affectsFactions, manual.affectsFactions, "Affects factions should match")
	assert_eq(from_dict.blockMovement, manual.blockMovement, "Block movement flag should match")
	assert_eq(from_dict.blockVision, manual.blockVision, "Block vision flag should match")
	assert_eq(from_dict.toDict(), serialized, "HazardResource serialization should be stable")

func test_meteormyte_level_upgrade_round_trip() -> void:
	var original := MeteormyteLevelUpgrade.new()
	original.upgradeType = MeteormyteLevelUpgrade.UpgradeType.STAT_BOOST
	original.upgradeName = "Sharpened Claws"
	original.description = "Boost attack power"
	original.effectData = {MeteormyteStat.StatType.ATTACK: 5}

	var serialized := original.toDict()
	var from_dict := MeteormyteLevelUpgrade.fromDict(serialized)

	var manual := MeteormyteLevelUpgrade.new()
	manual.upgradeType = MeteormyteLevelUpgrade.UpgradeType.STAT_BOOST
	manual.upgradeName = "Sharpened Claws"
	manual.description = "Boost attack power"
	manual.effectData = {MeteormyteStat.StatType.ATTACK: 5}

	assert_eq(int(from_dict.upgradeType), int(manual.upgradeType), "Upgrade type should match")
	assert_eq(from_dict.upgradeName, manual.upgradeName, "Upgrade name should match")
	assert_eq(from_dict.description, manual.description, "Upgrade description should match")
	assert_eq(from_dict.effectData, manual.effectData, "Effect data should match")
	assert_eq(from_dict.toDict(), serialized, "MeteormyteLevelUpgrade serialization should be stable")

func test_meteormyte_species_data_round_trip() -> void:
	var original := MeteormyteSpeciesData.new()
	original.speciesName = "Pyron"
	original.speciesID = 101
	original.description = "Fiery insectoid"
	original.baseHP = 70
	original.baseAttack = 80
	original.baseDefense = 60
	original.baseSpAttack = 85
	original.baseSpDefense = 55
	original.baseSpeed = 90
	original.innateAbility = "Blaze Shield"
	original.hiddenAbility = "Molten Core"
	original.learneableAbilities = ["Heat Up", "Wing Gust"]

	var serialized := original.toDict()
	var from_dict := MeteormyteSpeciesData.fromDict(serialized)

	var manual := MeteormyteSpeciesData.new()
	manual.speciesName = "Pyron"
	manual.speciesID = 101
	manual.description = "Fiery insectoid"
	manual.baseHP = 70
	manual.baseAttack = 80
	manual.baseDefense = 60
	manual.baseSpAttack = 85
	manual.baseSpDefense = 55
	manual.baseSpeed = 90
	manual.innateAbility = "Blaze Shield"
	manual.hiddenAbility = "Molten Core"
	manual.learneableAbilities = ["Heat Up", "Wing Gust"]

	assert_eq(from_dict.speciesName, manual.speciesName, "Species name should match")
	assert_eq(from_dict.speciesID, manual.speciesID, "Species ID should match")
	assert_eq(from_dict.description, manual.description, "Description should match")
	assert_eq(from_dict.baseHP, manual.baseHP, "Base HP should match")
	assert_eq(from_dict.baseAttack, manual.baseAttack, "Base attack should match")
	assert_eq(from_dict.baseDefense, manual.baseDefense, "Base defense should match")
	assert_eq(from_dict.baseSpAttack, manual.baseSpAttack, "Base special attack should match")
	assert_eq(from_dict.baseSpDefense, manual.baseSpDefense, "Base special defense should match")
	assert_eq(from_dict.baseSpeed, manual.baseSpeed, "Base speed should match")
	assert_eq(from_dict.innateAbility, manual.innateAbility, "Innate ability should match")
	assert_eq(from_dict.hiddenAbility, manual.hiddenAbility, "Hidden ability should match")
	assert_eq(from_dict.learneableAbilities, manual.learneableAbilities, "Learneable abilities should match")
	assert_eq(from_dict.toDict(), serialized, "MeteormyteSpeciesData serialization should be stable")

func test_attack_resource_round_trip() -> void:
	var original := AttackResource.new()
	original.attackName = "Solar Lance"
	original.description = "Piercing solar beam"
	original.baseDamage = 120
	original.accuracy = 0.85
	original.damageType = AttackResource.Typing.GRASS
	original.attackType = AttackResource.AttackType.SPECIAL
	original.interactionType = AttackResource.InteractionType.RANGED
	original.requiresTarget = true
	original.canTargetEmpty = true
	original.hitsAllies = true
	original.aoeType = AttackResource.AOEType.AREA
	original.chainCount = 2
	original.chainRange = 3
	original.statusChance = 0.5
	original.hazardChance = 0.4
	original.knockback = true
	original.superKnockback = true
	original.knockbackDistance = 2
	original.vfxType = AttackResource.VFXType.BEAM
	original.vfxScale = 1.5
	original.vfxHeight = 0.25
	original.vfxOrientation = AttackResource.VFXOrientation.ALONG_X
	original.vfxRotationOffset = Vector3(10.0, 20.0, 30.0)
	original.animationName = "beam"
	original.animationTime = 2.0
	original.selfDamagePercent = 0.2
	original.drainsHealth = true
	original.ignoresDefense = true

	var serialized := original.toDict()
	var from_dict := AttackResource.fromDict(serialized)

	var manual := AttackResource.new()
	manual.attackName = "Solar Lance"
	manual.description = "Piercing solar beam"
	manual.baseDamage = 120
	manual.accuracy = 0.85
	manual.damageType = AttackResource.Typing.GRASS
	manual.attackType = AttackResource.AttackType.SPECIAL
	manual.interactionType = AttackResource.InteractionType.RANGED
	manual.requiresTarget = true
	manual.canTargetEmpty = true
	manual.hitsAllies = true
	manual.aoeType = AttackResource.AOEType.AREA
	manual.chainCount = 2
	manual.chainRange = 3
	manual.statusChance = 0.5
	manual.hazardChance = 0.4
	manual.knockback = true
	manual.superKnockback = true
	manual.knockbackDistance = 2
	manual.vfxType = AttackResource.VFXType.BEAM
	manual.vfxScale = 1.5
	manual.vfxHeight = 0.25
	manual.vfxOrientation = AttackResource.VFXOrientation.ALONG_X
	manual.vfxRotationOffset = Vector3(10.0, 20.0, 30.0)
	manual.animationName = "beam"
	manual.animationTime = 2.0
	manual.selfDamagePercent = 0.2
	manual.drainsHealth = true
	manual.ignoresDefense = true

	assert_eq(from_dict.attackName, manual.attackName, "Attack name should match")
	assert_eq(from_dict.description, manual.description, "Description should match")
	assert_eq(from_dict.baseDamage, manual.baseDamage, "Base damage should match")
	assert_almost_eq(from_dict.accuracy, manual.accuracy, 0.0001, "Accuracy should match")
	assert_eq(int(from_dict.damageType), int(manual.damageType), "Damage type should match")
	assert_eq(int(from_dict.attackType), int(manual.attackType), "Attack type should match")
	assert_eq(int(from_dict.interactionType), int(manual.interactionType), "Interaction type should match")
	assert_eq(from_dict.requiresTarget, manual.requiresTarget, "Requires target flag should match")
	assert_eq(from_dict.canTargetEmpty, manual.canTargetEmpty, "Can target empty flag should match")
	assert_eq(from_dict.hitsAllies, manual.hitsAllies, "Hits allies flag should match")
	assert_eq(int(from_dict.aoeType), int(manual.aoeType), "AOE type should match")
	assert_eq(from_dict.chainCount, manual.chainCount, "Chain count should match")
	assert_eq(from_dict.chainRange, manual.chainRange, "Chain range should match")
	assert_almost_eq(from_dict.statusChance, manual.statusChance, 0.0001, "Status chance should match")
	assert_almost_eq(from_dict.hazardChance, manual.hazardChance, 0.0001, "Hazard chance should match")
	assert_eq(from_dict.knockback, manual.knockback, "Knockback flag should match")
	assert_eq(from_dict.superKnockback, manual.superKnockback, "Super knockback flag should match")
	assert_eq(from_dict.knockbackDistance, manual.knockbackDistance, "Knockback distance should match")
	assert_eq(int(from_dict.vfxType), int(manual.vfxType), "VFX type should match")
	assert_almost_eq(from_dict.vfxScale, manual.vfxScale, 0.0001, "VFX scale should match")
	assert_almost_eq(from_dict.vfxHeight, manual.vfxHeight, 0.0001, "VFX height should match")
	assert_eq(int(from_dict.vfxOrientation), int(manual.vfxOrientation), "VFX orientation should match")
	assert_true(from_dict.vfxRotationOffset.is_equal_approx(manual.vfxRotationOffset), "VFX rotation offset should match")
	assert_eq(from_dict.animationName, manual.animationName, "Animation name should match")
	assert_almost_eq(from_dict.animationTime, manual.animationTime, 0.0001, "Animation time should match")
	assert_almost_eq(from_dict.selfDamagePercent, manual.selfDamagePercent, 0.0001, "Self damage percent should match")
	assert_eq(from_dict.drainsHealth, manual.drainsHealth, "Drains health flag should match")
	assert_eq(from_dict.ignoresDefense, manual.ignoresDefense, "Ignores defense flag should match")
	assert_eq(from_dict.toDict(), serialized, "AttackResource serialization should be stable")

func test_meteormyte_round_trip() -> void:
	var original := Meteormyte.new()
	original.nickname = "Blazebug"
	original.level = 7
	original.xp = 250
	original.unique_id = 424242
	original.current_hp = 35

	var hp_stat := MeteormyteStat.new()
	hp_stat.statType = MeteormyteStat.StatType.HP
	hp_stat.baseStat = 70
	hp_stat.individualValue = 12
	hp_stat.level = 7
	hp_stat.recalculateStats()
	original.stats[MeteormyteStat.StatType.HP] = hp_stat

	var atk_stat := MeteormyteStat.new()
	atk_stat.statType = MeteormyteStat.StatType.ATTACK
	atk_stat.baseStat = 80
	atk_stat.individualValue = 8
	atk_stat.level = 7
	atk_stat.recalculateStats()
	original.stats[MeteormyteStat.StatType.ATTACK] = atk_stat

	var serialized := original.toDict()
	var from_dict := Meteormyte.fromDict(serialized)

	var manual := Meteormyte.new()
	manual.nickname = "Blazebug"
	manual.level = 7
	manual.xp = 250
	manual.unique_id = 424242
	manual.current_hp = 35

	var manual_hp := MeteormyteStat.new()
	manual_hp.statType = MeteormyteStat.StatType.HP
	manual_hp.baseStat = 70
	manual_hp.individualValue = 12
	manual_hp.level = 7
	manual_hp.recalculateStats()
	manual.stats[MeteormyteStat.StatType.HP] = manual_hp

	var manual_atk := MeteormyteStat.new()
	manual_atk.statType = MeteormyteStat.StatType.ATTACK
	manual_atk.baseStat = 80
	manual_atk.individualValue = 8
	manual_atk.level = 7
	manual_atk.recalculateStats()
	manual.stats[MeteormyteStat.StatType.ATTACK] = manual_atk

	assert_eq(from_dict.nickname, manual.nickname, "Nickname should match")
	assert_eq(from_dict.level, manual.level, "Level should match")
	assert_eq(from_dict.xp, manual.xp, "XP should match")
	assert_eq(from_dict.unique_id, manual.unique_id, "Unique ID should match")
	assert_eq(from_dict.current_hp, manual.current_hp, "Current HP should match")
	assert_eq(from_dict.stats.size(), manual.stats.size(), "Stat count should match")

	for stat_type in manual.stats.keys():
		assert_true(from_dict.stats.has(stat_type), "Deserialized Meteormyte should have stat %s" % [stat_type])
		assert_eq(from_dict.stats[stat_type].toDict(), manual.stats[stat_type].toDict(), "Stat %s should match after round trip" % [stat_type])

	assert_eq(from_dict.available_attacks.size(), manual.available_attacks.size(), "Available attacks should match")
	assert_eq(from_dict.toDict(), serialized, "Meteormyte serialization should be stable")
