/**********************Mineral deposits**************************/
/turf/unsimulated/mineral
	name = "impassable rock"
	icon = 'icons/turf/smooth/rock_dense.dmi'
	icon_state = "preview_wall_unsimulated"
	blocks_air = TRUE
	density = TRUE
	gender = PLURAL
	opacity = TRUE
	smoothing_flags = SMOOTH_TRUE
	color = "#6e632f"

/turf/unsimulated/mineral/konyang
	color = "#514e5c"

/// This is a global list so we can share the same list with all mineral turfs; it's the same for all of them anyways.
GLOBAL_LIST_INIT(mineral_can_smooth_with, list(
	/turf/simulated/mineral,
	/turf/simulated/wall,
	/turf/unsimulated/wall
))

/turf/simulated/mineral
	name = "rock"
	icon = 'icons/turf/smooth/rock_dense.dmi'
	icon_state = "preview_wall"
	desc = "It's a greyish rock. Exciting."
	gender = PLURAL
	var/icon/actual_icon = 'icons/turf/smooth/rock_dense.dmi'
	color = "#6e632f"

	// canSmoothWith is set in Initialize().
	smoothing_flags = SMOOTH_MORE | SMOOTH_BORDER | SMOOTH_NO_CLEAR_ICON
	turf_flags = TURF_FLAG_BACKGROUND

	initial_gas = null
	opacity = TRUE
	density = TRUE
	blocks_air = TRUE
	temperature = T0C
	explosion_resistance = 2

	var/mined_turf = /turf/simulated/floor/exoplanet/asteroid/ash/rocky
	var/ore/mineral
	var/mined_ore = 0
	var/last_act = 0
	var/emitter_blasts_taken = 0 // EMITTER MINING! Muhehe.

	var/datum/geosample/geologic_data
	var/excavation_level = 0
	var/list/finds
	var/archaeo_overlay = ""
	var/obj/item/last_find
	var/datum/artifact_find/artifact_find

	var/obj/effect/mineral/my_mineral

	var/rock_health = 20 //10 to 20, in initialize

	has_resources = TRUE

/turf/simulated/mineral/proc/kinetic_hit(var/damage)
	rock_health -= damage
	if(rock_health <= 0)
		GetDrilled(TRUE)

// Copypaste parent call for performance.
/turf/simulated/mineral/Initialize(mapload)
	if(flags_1 & INITIALIZED_1)
		stack_trace("Warning: [src]([type]) initialized multiple times!")
	flags_1 |= INITIALIZED_1

	if(icon != actual_icon)
		icon = actual_icon

	if(is_station_level(z))
		GLOB.station_turfs += src

	if(dynamic_lighting)
		luminosity = 0
	else
		luminosity = 1

	has_opaque_atom = TRUE

	if(smoothing_flags)
		canSmoothWith = GLOB.mineral_can_smooth_with

	rock_health = rand(10,20)

	var/area/A = loc

	if(A.base_turf)
		baseturf = A.base_turf
	else if(!baseturf)
		// Hard-coding this for performance reasons.
		baseturf = SSatlas.current_map.base_turf_by_z["[z]"] || /turf/space

	return INITIALIZE_HINT_NORMAL

/turf/simulated/mineral/get_examine_text(mob/user, distance, is_adjacent, infix, suffix)
	. = ..()
	if(mineral)
		switch(mined_ore)
			if(0)
				. += SPAN_INFO("It is ripe with [mineral.display_name].")
			if(1)
				. += SPAN_INFO("Its [mineral.display_name] looks a little depleted.")
			if(2)
				. += SPAN_INFO("Its [mineral.display_name] looks very depleted!")
	else
		. += SPAN_INFO("It is devoid of any valuable minerals.")
	switch(emitter_blasts_taken)
		if(0)
			. += SPAN_INFO("It is in pristine condition.")
		if(1)
			. += SPAN_INFO("It appears a little damaged.")
		if(2)
			. += SPAN_INFO("It is crumbling!")
		if(3)
			. += SPAN_INFO("It looks ready to collapse at any moment!")

/turf/simulated/mineral/ex_act(severity)
	switch(severity)
		if(2.0)
			if (prob(70))
				mined_ore = 1 //some of the stuff gets blown up
				GetDrilled()
			else
				emitter_blasts_taken += 2
		if(1.0)
			mined_ore = 2 //some of the stuff gets blown up
			GetDrilled()
	QUEUE_SMOOTH_NEIGHBORS(src)

/turf/simulated/mineral/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit)
	SHOULD_CALL_PARENT(FALSE) //Fucking snowflake stack of procs

	var/sigreturn = SEND_SIGNAL(src, COMSIG_ATOM_PRE_BULLET_ACT, hitting_projectile, def_zone)
	if(sigreturn & COMPONENT_BULLET_PIERCED)
		return BULLET_ACT_FORCE_PIERCE
	if(sigreturn & COMPONENT_BULLET_BLOCKED)
		return BULLET_ACT_BLOCK
	if(sigreturn & COMPONENT_BULLET_ACTED)
		return BULLET_ACT_HIT

	SEND_SIGNAL(src, COMSIG_ATOM_BULLET_ACT, hitting_projectile, def_zone)
	if(QDELETED(hitting_projectile)) // Signal deleted it?
		return BULLET_ACT_BLOCK

	if(istype(hitting_projectile, /obj/projectile/beam/plasmacutter))
		var/obj/projectile/beam/plasmacutter/PC_beam = hitting_projectile
		var/list/cutter_results = PC_beam.pass_check(src)
		. = cutter_results[1]
		if(cutter_results[2]) // the cutter mined the turf, just pass on
			return BULLET_ACT_HIT

	// Emitter blasts
	if(istype(hitting_projectile, /obj/projectile/beam/emitter))
		emitter_blasts_taken++

	if(emitter_blasts_taken >= 3)
		GetDrilled()

	hitting_projectile.on_hit(src, 0, def_zone)

/turf/simulated/mineral/CollidedWith(atom/bumped_atom)
	. = ..()
	if(istype(bumped_atom, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = bumped_atom
		if((istype(H.l_hand,/obj/item/pickaxe)) && (!H.hand))
			var/obj/item/pickaxe/P = H.l_hand
			if(P.autodrill)
				INVOKE_ASYNC(src, TYPE_PROC_REF(/atom, attackby), H.l_hand, H)

		else if((istype(H.r_hand, /obj/item/pickaxe)) && H.hand)
			var/obj/item/pickaxe/P = H.r_hand
			if(P.autodrill)
				INVOKE_ASYNC(src, TYPE_PROC_REF(/atom, attackby), H.r_hand, H)

	else if(istype(bumped_atom, /mob/living/silicon/robot))
		var/mob/living/silicon/robot/R = bumped_atom
		if(istype(R.module_active,/obj/item/pickaxe))
			INVOKE_ASYNC(src, TYPE_PROC_REF(/atom, attackby), R.module_active, R)

//For use in non-station z-levels as decoration.
/turf/unsimulated/mineral/asteroid
	name = "rock"
	desc = "It's a greyish rock. Exciting."
	opacity = TRUE
	var/icon/actual_icon = 'icons/turf/smooth/rock_dense.dmi'
	layer = 2.01
	var/list/asteroid_can_smooth_with = list(
		/turf/unsimulated/mineral,
		/turf/unsimulated/mineral/asteroid
	)
	smoothing_flags = SMOOTH_MORE | SMOOTH_BORDER | SMOOTH_NO_CLEAR_ICON
	color = "#705d40"

/turf/unsimulated/mineral/asteroid/Initialize(mapload)
	SHOULD_CALL_PARENT(FALSE)

	if(flags_1 & INITIALIZED_1)
		stack_trace("Warning: [src]([type]) initialized multiple times!")
	flags_1 |= INITIALIZED_1

	if(icon != actual_icon)
		icon = actual_icon

	if(is_station_level(z))
		GLOB.station_turfs += src

	if(dynamic_lighting)
		luminosity = 0
	else
		luminosity = 1

	has_opaque_atom = TRUE

	if(smoothing_flags)
		canSmoothWith = asteroid_can_smooth_with

	return INITIALIZE_HINT_NORMAL

#define SPREAD(the_dir) \
	if (prob(mineral.spread_chance)) {                              \
		var/turf/simulated/mineral/target = get_step(src, the_dir); \
		if (istype(target) && !target.mineral) {                    \
			target.mineral = mineral;                               \
			target.UpdateMineral();                                 \
			target.MineralSpread();                                 \
		}                                                           \
	}

/turf/simulated/mineral/proc/MineralSpread()
	if(mineral && mineral.spread)
		SPREAD(NORTH)
		SPREAD(SOUTH)
		SPREAD(EAST)
		SPREAD(WEST)

#undef SPREAD

/turf/simulated/mineral/proc/UpdateMineral()
	clear_ore_effects()
	if(!mineral)
		name = "\improper Rock"
		return
	name = "\improper [mineral.display_name] deposit"
	new /obj/effect/mineral(src, mineral)

//Not even going to touch this pile of spaghetti //motherfucker - geeves
/turf/simulated/mineral/attackby(obj/item/attacking_item, mob/user)
	if(!user.IsAdvancedToolUser())
		to_chat(user, SPAN_WARNING("You don't have the dexterity to do this!"))
		return

	if(istype(attacking_item, /obj/item/device/core_sampler))
		var/obj/item/device/core_sampler/C = attacking_item
		C.sample_item(src, user)
		return

	if(istype(attacking_item, /obj/item/device/depth_scanner))
		var/obj/item/device/depth_scanner/C = attacking_item
		C.scan_atom(user, src)
		return

	if(istype(attacking_item, /obj/item/device/measuring_tape))
		var/obj/item/device/measuring_tape/P = attacking_item
		user.visible_message(SPAN_NOTICE("\The [user] extends \the [P] towards \the [src].") , SPAN_NOTICE("You extend \the [P] towards \the [src]."))
		if(do_after(user,25))
			if(!istype(src, /turf/simulated/mineral))
				return
			to_chat(user, SPAN_NOTICE("[icon2html(P, user)] \The [src] has been excavated to a depth of [2 * excavation_level]cm."))
		return

	if(istype(attacking_item, /obj/item/pickaxe) && attacking_item.simulated)	// Pickaxe offhand is not simulated.
		var/turf/T = user.loc
		if(!(istype(T, /turf)))
			return
		var/obj/item/pickaxe/P = attacking_item
		if(last_act + P.digspeed > world.time)//prevents message spam
			return
		if(P.drilling)
			return

		last_act = world.time

		playsound(user, P.drill_sound, 20, TRUE)
		P.drilling = TRUE

		//handle any archaeological finds we might uncover
		var/fail_message
		if(finds?.len)
			var/datum/find/F = finds[1]
			if(excavation_level + P.excavation_amount > F.excavation_required)
				//Chance to destroy / extract any finds here
				fail_message = ". <b>[pick("There is a crunching noise","[attacking_item] collides with some different rock","Part of the rock face crumbles away",\
								"Something breaks under [attacking_item]")]</b>"

		if(fail_message)
			to_chat(user, SPAN_WARNING("You start [P.drill_verb][fail_message ? fail_message : ""]."))

		if(fail_message && prob(90))
			if(prob(25))
				excavate_find(5, finds[1])
			else if(prob(50))
				finds.Remove(finds[1])
				if(prob(50))
					artifact_debris()

		if(do_after(user,P.digspeed))
			if(!istype(src, /turf/simulated/mineral))
				return

			P.drilling = FALSE

			if(prob(50))
				var/obj/item/ore/O
				if(prob(25) && (mineral) && (P.excavation_amount >= 30))
					O = new mineral.ore(src)
				else
					O = new /obj/item/ore(src)
				if(istype(O))
					O.geologic_data = get_geodata()
				addtimer(CALLBACK(O, TYPE_PROC_REF(/atom/movable, forceMove), user.loc), 1)

			if(finds?.len)
				var/datum/find/F = finds[1]
				if(round(excavation_level + P.excavation_amount) == F.excavation_required)
					//Chance to extract any items here perfectly, otherwise just pull them out along with the rock surrounding them
					if(excavation_level + P.excavation_amount > F.excavation_required)
						//if you can get slightly over, perfect extraction
						excavate_find(100, F)
					else
						excavate_find(80, F)

				else if(excavation_level + P.excavation_amount > F.excavation_required - F.clearance_range)
					//just pull the surrounding rock out
					excavate_find(0, F)

			if(excavation_level + P.excavation_amount >= 100)
				//if players have been excavating this turf, leave some rocky debris behind
				var/obj/structure/boulder/B
				if(artifact_find)
					if(excavation_level > 0 || prob(15))
						//boulder with an artifact inside
						B = new(src, "#9c9378") // if we ever get natural walls, edit this
						if(artifact_find)
							B.artifact_find = artifact_find
					else
						artifact_debris(1)
				else if(prob(15))
					//empty boulder
					B = new(src, "#9c9378") // if we ever get natural walls, edit this

				if(B)
					GetDrilled(0)
				else
					GetDrilled(1)
				return

			excavation_level += P.excavation_amount

		else
			to_chat(user, SPAN_NOTICE("You stop [P.drill_verb] \the [src]."))
			P.drilling = FALSE

	if(istype(attacking_item, /obj/item/autochisel))
		if(last_act + 80 > world.time)//prevents message spam
			return
		last_act = world.time

		to_chat(user, SPAN_NOTICE("You start chiselling \the [src] into a sculptable block."))

		if(!attacking_item.use_tool(src, user, 80, volume = 50))
			return

		if(!istype(src, /turf/simulated/mineral))
			return

		to_chat(user, SPAN_NOTICE("You finish chiselling [src] into a sculptable block."))
		new /obj/structure/sculpting_block(src)
		GetDrilled(1)

/turf/simulated/mineral/proc/get_geodata()
	if(!geologic_data)
		geologic_data = new /datum/geosample(src)
	geologic_data.UpdateNearbyArtifactInfo(src)
	return geologic_data

/turf/simulated/mineral/proc/clear_ore_effects()
	if(my_mineral)
		qdel(my_mineral)

/turf/simulated/mineral/proc/DropMineral()
	if(!mineral)
		return

	clear_ore_effects()
	var/obj/item/ore/O = new mineral.ore(src)
	if(istype(O))
		O.geologic_data = get_geodata()
	return O

/turf/simulated/mineral/proc/GetDrilled(var/artifact_fail = 0)
	if(mineral?.result_amount)
		//if the turf has already been excavated, some of it's ore has been removed
		for(var/i = 1 to mineral.result_amount - mined_ore)
			DropMineral()

	//Add some rubble, you did just clear out a big chunk of rock.

	if(prob(25))
		var/datum/reagents/R = new/datum/reagents(20)
		R.my_atom = src
		R.add_reagent(/singleton/reagent/stone_dust,20)
		var/datum/effect/effect/system/smoke_spread/chem/S = new /datum/effect/effect/system/smoke_spread/chem(/singleton/reagent/stone_dust) // have to explicitly say the type to avoid issues with warnings
		S.show_log = 0
		S.set_up(R, 10, 0, src, 40)
		S.start()
		qdel(R)

	ChangeTurf(mined_turf)

	if(rand(1,500) == 1)
		visible_message(SPAN_NOTICE("An old dusty crate was buried within!"))
		new /obj/structure/closet/crate/secure/loot(src)

/turf/simulated/mineral/ChangeTurf(path, tell_universe, force_lighting_update, ignore_override, mapload)
	var/old_has_resources = has_resources
	var/list/old_resources = resources
	var/image/old_resource_indicator = resource_indicator

	var/turf/new_turf = ..()

	new_turf.has_resources = old_has_resources
	new_turf.resources = old_resources
	new_turf.resource_indicator = old_resource_indicator
	if(new_turf.resource_indicator)
		new_turf.AddOverlays(new_turf.resource_indicator)

	return new_turf

/turf/simulated/mineral/proc/excavate_find(var/prob_clean = 0, var/datum/find/F)
	//with skill and luck, players can cleanly extract finds
	//otherwise, they come out inside a chunk of rock
	var/obj/item/X
	if(prob_clean)
		X = new /obj/item/archaeological_find(src, F.find_type)
	else
		var/obj/item/ore/strangerock/SR = new /obj/item/ore/strangerock(src, F.find_type)
		SR.geologic_data = get_geodata()
		X = SR

	//some find types delete the /obj/item/archaeological_find and replace it with something else, this handles when that happens
	//yuck //yuck indeed. //yuck ultra
	var/display_name = "something"
	if(!X)
		X = last_find
	if(X)
		display_name = X.name

	//many finds are ancient and thus very delicate - luckily there is a specialised energy suspension field which protects them when they're being extracted
	if(prob(F.prob_delicate))
		var/obj/effect/suspension_field/S = locate() in src
		if(!S || S.field_type != get_responsive_reagent(F.find_type))
			if(X)
				visible_message(SPAN_DANGER("[pick("[display_name] crumbles away into dust","[display_name] breaks apart")]."))
				qdel(X)

	finds.Remove(F)


/turf/simulated/mineral/proc/artifact_debris(var/severity = 0)

	//Give a random amount of loot from 1 to 3 or 5, varying on severity.
	for(var/j in 1 to rand(1, 3 + max(min(severity, 1), 0) * 2))
		switch(rand(1,7))
			if(1)
				var/obj/item/stack/rods/R = new(src)
				R.amount = rand(5, 25)
			if(2)
				var/obj/item/stack/material/plasteel/R = new(src)
				R.amount = rand(5, 25)
			if(3)
				var/obj/item/stack/material/steel/R = new(src)
				R.amount = rand(5, 25)
			if(4)
				var/obj/item/stack/material/plasteel/R = new(src)
				R.amount = rand(5, 25)
			if(5)
				var/quantity = rand(1, 3)
				for(var/i = 0, i < quantity, i++)
					new /obj/item/material/shard/shrapnel(src)
			if(6)
				var/quantity = rand(1, 3)
				for(var/i = 0, i < quantity, i++)
					new /obj/item/material/shard/phoron(src)
			if(7)
				var/obj/item/stack/material/uranium/R = new(src)
				R.amount = rand(5, 25)

/turf/simulated/mineral/proc/change_mineral(mineral_name, force = FALSE)
	if(mineral_name && (mineral_name in GLOB.ore_data))
		if(mineral && !force)
			return FALSE
		mineral = GLOB.ore_data[mineral_name]
		UpdateMineral()

/turf/simulated/mineral/random
	name = "mineral deposit"
	var/mineralSpawnChanceList = list(
		ORE_URANIUM = 2,
		ORE_PLATINUM = 2,
		ORE_IRON = 8,
		ORE_COAL = 8,
		ORE_DIAMOND = 1,
		ORE_GOLD = 2,
		ORE_SILVER = 2,
		ORE_BAUXITE = 6,
		ORE_GALENA = 4
	)
	var/mineralChance = 55

/turf/simulated/mineral/random/phoron
	mineralSpawnChanceList = list(
		ORE_URANIUM = 2,
		ORE_PLATINUM = 2,
		ORE_IRON = 8,
		ORE_COAL = 8,
		ORE_DIAMOND = 1,
		ORE_GOLD = 2,
		ORE_SILVER = 2,
		ORE_BAUXITE = 6,
		ORE_GALENA = 4,
		ORE_PHORON = 5
	)

/turf/simulated/mineral/random/Initialize()
	if(prob(mineralChance) && !mineral)
		var/mineral_name = pickweight(mineralSpawnChanceList) //temp mineral name
		if(mineral_name && (mineral_name in GLOB.ore_data))
			mineral = GLOB.ore_data[mineral_name]
			UpdateMineral()
		MineralSpread()
	. = ..()

/turf/simulated/mineral/random/exoplanet
	mined_turf = /turf/simulated/floor/exoplanet/mineral

/turf/simulated/mineral/random/adhomai
	color = "#97A7AA"
	mined_turf = /turf/simulated/floor/exoplanet/mineral/adhomai

/turf/simulated/mineral/random/high_chance
	mineralSpawnChanceList = list(
		ORE_URANIUM = 2,
		ORE_PLATINUM = 2,
		ORE_IRON = 2,
		ORE_COAL = 2,
		ORE_DIAMOND = 1,
		ORE_GOLD = 2,
		ORE_SILVER = 2,
		ORE_BAUXITE = 1,
		ORE_GALENA = 1
	)
	mineralChance = 55

/turf/simulated/mineral/random/high_chance/phoron
	mineralSpawnChanceList = list(
		ORE_URANIUM = 2,
		ORE_PLATINUM = 2,
		ORE_IRON = 2,
		ORE_COAL = 2,
		ORE_DIAMOND = 1,
		ORE_GOLD = 2,
		ORE_SILVER = 2,
		ORE_BAUXITE = 1,
		ORE_GALENA = 1
	)

/turf/simulated/mineral/random/high_chance/exoplanet
	mined_turf = /turf/simulated/floor/exoplanet/mineral

/turf/simulated/mineral/random/high_chance/adhomai
	mined_turf = /turf/simulated/floor/exoplanet/mineral/adhomai

/turf/simulated/mineral/random/higher_chance
	mineralSpawnChanceList = list(
		ORE_URANIUM = 3,
		ORE_PLATINUM = 3,
		ORE_IRON = 1,
		ORE_COAL = 1,
		ORE_DIAMOND = 1,
		ORE_GOLD = 3,
		ORE_SILVER = 3,
		ORE_BAUXITE = 1,
		ORE_GALENA = 2
	)
	mineralChance = 75

/turf/simulated/mineral/random/higher_chance/phoron
	mineralSpawnChanceList = list(
		ORE_URANIUM = 3,
		ORE_PLATINUM = 3,
		ORE_IRON = 1,
		ORE_COAL = 1,
		ORE_DIAMOND = 1,
		ORE_GOLD = 3,
		ORE_SILVER = 3,
		ORE_PHORON = 2,
		ORE_BAUXITE = 1,
		ORE_GALENA = 2
	)

/turf/simulated/mineral/attack_hand(var/mob/user)
	add_fingerprint(user)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

	if(ishuman(user) && user.a_intent == I_GRAB)
		var/mob/living/carbon/human/H = user
		var/turf/T = get_turf(H)
		var/turf/destination = GET_TURF_ABOVE(T)
		if(destination)
			var/turf/start = get_turf(H)
			if(start.CanZPass(H, UP))
				if(destination.CanZPass(H, UP))
					H.climb(UP, src, 20)

/** Preset mineral walls.
 * These are used to spawn specific types of mineral walls in the map.
 * Use one of the subtypes below or, in case a new ore is added but the preset isn't created, set preset_mineral_name to the ORE_X define.
*/
/turf/simulated/mineral/preset
	var/preset_mineral_name

/turf/simulated/mineral/preset/Initialize(mapload)
	..()
	return INITIALIZE_HINT_LATELOAD

/turf/simulated/mineral/preset/LateInitialize()
	. = ..()
	change_mineral(preset_mineral_name, TRUE)

/turf/simulated/mineral/preset/phoron
	name = "phoron mineral wall"
	preset_mineral_name = ORE_PHORON

/turf/simulated/mineral/preset/coal
	name = "coal mineral wall"
	preset_mineral_name = ORE_COAL

/turf/simulated/mineral/preset/gold
	name = "gold mineral wall"
	preset_mineral_name = ORE_GOLD

/turf/simulated/mineral/preset/diamond
	name = "diamond mineral wall"
	preset_mineral_name = ORE_DIAMOND

/turf/simulated/mineral/preset/iron
	name = "iron mineral wall"
	preset_mineral_name = ORE_IRON

/turf/simulated/mineral/preset/platinum
	name = "platinum mineral wall"
	preset_mineral_name = ORE_PLATINUM

/turf/simulated/mineral/preset/bauxite
	name = "bauxite mineral wall"
	preset_mineral_name = ORE_BAUXITE

/turf/simulated/mineral/preset/galena
	name = "galena mineral wall"
	preset_mineral_name = ORE_GALENA

/turf/simulated/mineral/preset/uranium
	name = "uranium mineral wall"
	preset_mineral_name = ORE_URANIUM

/turf/simulated/mineral/preset/metallic_hydrogen
	name = "metallic_hydrogen mineral wall"
	preset_mineral_name = ORE_HYDROGEN

// Some extra types for the surface to keep things pretty.
/turf/simulated/mineral/surface
	mined_turf = /turf/simulated/floor/exoplanet/asteroid/ash

/turf/simulated/mineral/planet
	mined_turf = /turf/simulated/floor/exoplanet/mineral

/turf/simulated/mineral/adhomai
	mined_turf = /turf/simulated/floor/exoplanet/mineral/adhomai

/turf/simulated/mineral/crystal
	color = "#6fb1b5"
	mined_turf = /turf/simulated/floor/exoplanet/basalt/crystal

/turf/simulated/mineral/lava
	color = "#444444"
	mined_turf = /turf/simulated/floor/exoplanet/basalt

/turf/simulated/mineral/lava/tret
	color = "#444455"
	mined_turf = /turf/simulated/floor/exoplanet/basalt/tret

/**********************Asteroid**************************/

// Setting icon/icon_state initially will use these values when the turf is built on/replaced.
// This means you can put grass on the asteroid etc.
/turf/simulated/floor/exoplanet/asteroid
	name = "coder's blight"
	icon = 'icons/turf/map_placeholders.dmi'
	icon_state = ""
	desc = "An exposed developer texture. Someone wasn't paying attention."
	smoothing_flags = SMOOTH_FALSE
	gender = PLURAL
	base_icon = 'icons/turf/map_placeholders.dmi'
	base_icon_state = "ash"

	initial_gas = null
	temperature = TCMB
	var/dug = 0 //Increments by 1 everytime it's dug. 11 is the last integer that should ever be here.
	var/digging
	has_resources = 1
	footstep_sound = /singleton/sound_category/asteroid_footstep
	does_footprint = TRUE

	roof_type = null
	turf_flags = TURF_FLAG_BACKGROUND

/// Same as the other, this is a global so we don't have a lot of pointless lists floating around.
/// Basalt is explicitly omitted so ash will spill onto basalt turfs.
GLOBAL_LIST_INIT(asteroid_floor_smooth, list(
	/turf/simulated/floor/exoplanet/asteroid/ash,
	/turf/simulated/mineral,
	/turf/simulated/wall
))

// Copypaste parent for performance.
/turf/simulated/floor/exoplanet/asteroid/Initialize(mapload)
	if(flags_1 & INITIALIZED_1)
		stack_trace("Warning: [src]([type]) initialized multiple times!")
	flags_1 |= INITIALIZED_1

	if(icon != base_icon)	// Setting icon is an appearance change, so avoid it if we can.
		icon = base_icon

	base_desc = desc
	base_name = name

	if(is_station_level(z))
		GLOB.station_turfs += src

	if(dynamic_lighting)
		luminosity = 0
	else
		luminosity = 1

	if(mapload && permit_ao)
		queue_ao()

	if(smoothing_flags)
		canSmoothWith = GLOB.asteroid_floor_smooth
		pixel_x = -4
		pixel_y = -4

	if(light_range && light_power)
		update_light()

	return INITIALIZE_HINT_NORMAL

/turf/simulated/floor/exoplanet/asteroid/ex_act(severity)
	switch(severity)
		if(3.0)
			return
		if(2.0)
			if(prob(70))
				dug += rand(4, 10)
				gets_dug() // who's dug
			else
				dug += rand(1, 3)
				gets_dug()
		if(1.0)
			if(prob(30))
				dug = 11
				gets_dug()
			else
				dug += rand(4,11)
				gets_dug()
	return

/turf/simulated/floor/exoplanet/asteroid/is_plating()
	return FALSE

/turf/simulated/floor/exoplanet/asteroid/attackby(obj/item/attacking_item, mob/user)
	if(!attacking_item || !user)
		return FALSE

	if(istype(attacking_item, /obj/item/stack/rods))
		var/obj/structure/lattice/L = locate(/obj/structure/lattice, src)
		if(L)
			return
		var/obj/item/stack/rods/R = attacking_item
		if(R.use(1))
			to_chat(user, SPAN_NOTICE("Constructing support lattice..."))
			playsound(src, 'sound/weapons/Genhit.ogg', 50, 1)
			ReplaceWithLattice()
		return

	if(istype(attacking_item, /obj/item/stack/tile/floor))
		var/obj/structure/lattice/L = locate(/obj/structure/lattice, src)
		if(L)
			var/obj/item/stack/tile/floor/S = attacking_item
			if(S.get_amount() < 1)
				return
			qdel(L)
			playsound(src, 'sound/weapons/Genhit.ogg', 50, TRUE)
			S.use(1)
			ChangeTurf(/turf/simulated/floor/airless)
			return
		else
			to_chat(user, SPAN_WARNING("The plating is going to need some support.")) //turf psychiatrist lmaooo
			return

	var/static/list/usable_tools = typecacheof(list(
		/obj/item/shovel,
		/obj/item/pickaxe/diamonddrill,
		/obj/item/pickaxe/drill,
		/obj/item/pickaxe/borgdrill
	))

	if(is_type_in_typecache(attacking_item, usable_tools))
		var/turf/T = get_turf(user)
		if(!istype(T))
			return
		if(digging)
			return
		if(dug)
			if(!GET_TURF_BELOW(src))
				return
			to_chat(user, SPAN_NOTICE("You start digging deeper."))
			playsound(get_turf(user), 'sound/effects/stonedoor_openclose.ogg', 50, TRUE)
			digging = TRUE
			if(!attacking_item.use_tool(src, user, 60, volume = 50))
				if(istype(src, /turf/simulated/floor/exoplanet/asteroid))
					digging = FALSE
				return

			// Turfs are special. They don't delete. So we need to check if it's
			// still the same turf as before the sleep.
			if(!istype(src, /turf/simulated/floor/exoplanet/asteroid))
				return

			playsound(get_turf(user), 'sound/effects/stonedoor_openclose.ogg', 50, TRUE)
			if(prob(33))
				switch(dug)
					if(1)
						to_chat(user, SPAN_NOTICE("You've made a little progress."))
					if(2)
						to_chat(user, SPAN_NOTICE("You notice the hole is a little deeper."))
					if(3)
						to_chat(user, SPAN_NOTICE("You think you're about halfway there."))
					if(4)
						to_chat(user, SPAN_NOTICE("You finish up lifting another pile of dirt."))
					if(5)
						to_chat(user, SPAN_NOTICE("You dig a bit deeper. You're definitely halfway there now."))
					if(6)
						to_chat(user, SPAN_NOTICE("You still have a ways to go."))
					if(7)
						to_chat(user, SPAN_NOTICE("The hole looks pretty deep now."))
					if(8)
						to_chat(user, SPAN_NOTICE("The ground is starting to feel a lot looser."))
					if(9)
						to_chat(user, SPAN_NOTICE("You can almost see the other side."))
					if(10)
						to_chat(user, SPAN_NOTICE("Just a little deeper..."))
					else
						to_chat(user, SPAN_NOTICE("You penetrate the virgin earth!"))
			else
				if(dug <= 10)
					to_chat(user, SPAN_NOTICE("You dig a little deeper."))
				else
					to_chat(user, SPAN_NOTICE("You dug a big hole.")) // how ceremonious

			gets_dug(user)
			digging = 0
			return

		to_chat(user, SPAN_WARNING("You start digging."))
		playsound(get_turf(user), 'sound/effects/stonedoor_openclose.ogg', 50, TRUE)

		digging = TRUE
		if(!do_after(user, 40))
			if(istype(src, /turf/simulated/floor/exoplanet/asteroid))
				digging = FALSE
			return

		// Turfs are special. They don't delete. So we need to check if it's
		// still the same turf as before the sleep.
		if(!istype(src, /turf/simulated/floor/exoplanet/asteroid))
			return

		to_chat(user, SPAN_NOTICE("You dug a hole."))
		digging = FALSE

		gets_dug(user)

	else if(istype(attacking_item,/obj/item/storage/bag/ore))
		var/obj/item/storage/bag/ore/S = attacking_item
		if(S.collection_mode)
			for(var/obj/item/ore/O in contents)
				O.attackby(attacking_item, user)
				CHECK_TICK
				return
	else if(istype(attacking_item,/obj/item/storage/bag/fossils))
		var/obj/item/storage/bag/fossils/S = attacking_item
		if(S.collection_mode)
			for(var/obj/item/fossil/F in contents)
				F.attackby(attacking_item, user)
				CHECK_TICK
				return
	else
		..()
	return

/turf/simulated/floor/exoplanet/asteroid/proc/gets_dug(mob/user)
	AddOverlays("asteroid_dug", TRUE)

	if(prob(75))
		new /obj/item/ore/glass(src)
	if(prob(25) && has_resources)
		var/list/ore = list()
		for(var/metal in resources)
			switch(metal)
				if(ORE_SAND)
					ore += /obj/item/ore/glass
				if(ORE_COAL)
					ore += /obj/item/ore/coal
				if(ORE_IRON)
					ore += /obj/item/ore/iron
				if(ORE_GOLD)
					ore += /obj/item/ore/gold
				if(ORE_SILVER)
					ore += /obj/item/ore/silver
				if(ORE_GALENA)
					ore += /obj/item/ore/lead
				if(ORE_DIAMOND)
					ore += /obj/item/ore/diamond
				if(ORE_URANIUM)
					ore += /obj/item/ore/uranium
				if(ORE_PHORON)
					ore += /obj/item/ore/phoron
				if(ORE_PLATINUM)
					ore += /obj/item/ore/osmium
				if(ORE_HYDROGEN)
					ore += /obj/item/ore/hydrogen
				if(ORE_BAUXITE)
					ore += /obj/item/ore/aluminium
				else
					if(prob(25))
						switch(rand(1,5))
							if(1)
								ore += /obj/random/junk
							if(2)
								ore += /obj/random/powercell
							if(3)
								ore += /obj/random/coin
							if(4)
								ore += /obj/random/loot
							if(5)
								ore += /obj/item/ore/glass
					else
						ore += /obj/item/ore/glass
		if(length(ore))
			var/ore_path = pick(ore)
			if(ore)
				new ore_path(src)

	if(dug <= 10)
		dug += 1
		AddOverlays("asteroid_dug", TRUE)
	else
		var/turf/below = GET_TURF_BELOW(src)
		if(below)
			var/area/below_area = get_area(below)	// Let's just assume that the turf is not in nullspace.
			if(below_area.station_area)
				if(user)
					to_chat(user, SPAN_ALERT("You strike metal!"))
				below.spawn_roof(ROOF_FORCE_SPAWN)
			else
				ChangeTurf(/turf/space)

/turf/simulated/floor/exoplanet/asteroid/Entered(atom/movable/M as mob|obj)
	..()
	if(istype(M,/mob/living/silicon/robot))
		var/mob/living/silicon/robot/R = M
		if(R.module) // bro wtf this is criminal
			if(istype(R.module_state_1, /obj/item/storage/bag/ore))
				attackby(R.module_state_1, R)
			else if(istype(R.module_state_2, /obj/item/storage/bag/ore))
				attackby(R.module_state_2, R)
			else if(istype(R.module_state_3, /obj/item/storage/bag/ore))
				attackby(R.module_state_3, R)
			else
				return

/turf/simulated/mineral/Destroy()
	clear_ore_effects()
	QUEUE_SMOOTH_NEIGHBORS(src)
	. = ..()
