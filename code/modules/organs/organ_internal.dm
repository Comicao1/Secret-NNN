#define PROCESS_ACCURACY 10

/****************************************************
				INTERNAL ORGANS
****************************************************/

/mob/living/carbon/var/list/internal_organs = list()

/datum/organ/internal
	var/damage = 0 // amount of damage to the organ
	var/min_bruised_damage = 10
	var/min_broken_damage = 30
	var/parent_organ = "chest"
	var/list/emplevel = list(0,0,0)  // [1] is the highest amount of emp damage, [3] is the least
	var/desc = ""
	var/robotic = 0 //For being a robot
	var/removed_type //When removed, forms this object.
	var/rejecting            // Is this organ already being rejected?
	var/obj/item/organ/organ_holder // If not in a body, held in this item.
	var/list/transplant_data
	var/damagelevel = 1


/datum/organ/internal/proc/rejuvenate()
	damage=0

/datum/organ/internal/proc/is_bruised()
	return damage >= min_bruised_damage

/datum/organ/internal/proc/is_broken()
	return damage >= min_broken_damage || status & ORGAN_CUT_AWAY

/datum/organ/internal/New(mob/living/carbon/human/H)
	..()
	if(H && istype(H))
		var/datum/organ/external/E = H.organs_by_name[src.parent_organ]
		if(E.internal_organs == null)
			E.internal_organs = list()
		var/datum/organ/internal/check = E.internal_organs[name]
		if(check)
			delete(H)
		add(H)
		owner = H

/datum/organ/internal/proc/vital_check()
	if(src.vital && is_broken())
		owner.oxyloss = 201
		owner.death()

/datum/organ/internal/process()

	//Process infections
	if (robotic >= 2 || (owner.species && owner.species.flags & IS_PLANT))	//TODO make robotic internal and external organs separate types of organ instead of a flag
		germ_level = 0
		return

	if(owner.bodytemperature >= 170)	//cryo stops germs from moving and doing their bad stuffs
		//** Handle antibiotics and curing infections
		handle_antibiotics()

		//** Handle the effects of infections
		var/antibiotics = owner.reagents.get_reagent_amount("spaceacillin")

		if (germ_level > 0 && germ_level < INFECTION_LEVEL_ONE/2 && prob(30))
			germ_level--

		if (germ_level >= INFECTION_LEVEL_ONE/2)
			//aiming for germ level to go from ambient to INFECTION_LEVEL_TWO in an average of 15 minutes
			if(antibiotics < 5 && prob(round(germ_level/6)))
				germ_level++

		if (germ_level >= INFECTION_LEVEL_TWO)
			var/datum/organ/external/parent = owner.get_organ(parent_organ)
			//spread germs
			if (antibiotics < 5 && parent.germ_level < germ_level && ( parent.germ_level < INFECTION_LEVEL_ONE*2 || prob(30) ))
				parent.germ_level++

			if (prob(3))	//about once every 30 seconds
				take_damage(1,silent=prob(30))

		// Process unsuitable transplants. TODO: consider some kind of
		// immunosuppressant that changes transplant data to make it match.
		if(transplant_data)
			if(!rejecting && prob(20) && owner.dna && blood_incompatible(transplant_data["blood_type"],owner.dna.b_type))//,owner.species,transplant_data["species"]))
				rejecting = 1
			else
				rejecting++ //Rejection severity increases over time.
				if(rejecting % 10 == 0) //Only fire every ten rejection ticks.
					switch(rejecting)
						if(1 to 50)
							take_damage(1)
						if(51 to 200)
							owner.reagents.add_reagent("toxin", 1)
							take_damage(1)
						if(201 to 500)
							take_damage(rand(2,3))
							owner.reagents.add_reagent("toxin", 2)
						if(501 to INFINITY)
							take_damage(4)
							owner.reagents.add_reagent("toxin", rand(3,5))

/datum/organ/internal/proc/take_damage(amount, var/silent=0)
	damage += amount * damagelevel

	var/datum/organ/external/parent = owner.get_organ(parent_organ)
	if (!silent)
		owner.custom_pain("Something inside your [parent.display_name] hurts a lot.", 1)

/datum/organ/internal/proc/emp_act(severity)
	if(emplevel[1])
		take_damage(emplevel[severity])

/datum/organ/internal/proc/mechanize() //Being used to make robutt hearts, etc

/datum/organ/internal/proc/mechassist() //Used to add things like pacemakers, etc


/datum/organ/internal/proc/delete(var/mob/living/carbon/human/H)
	if(H)
		var/datum/organ/internal/toremove = H.internal_organs_by_name[name]
		if(toremove)
			var/datum/organ/external/E = H.organs_by_name[toremove.parent_organ]
			for (var/datum/organ/internal/I in E.internal_organs)
				if (I == toremove)
					I = null

	return

/datum/organ/internal/proc/add(var/mob/living/carbon/human/H)
	var/datum/organ/external/P = H.organs_by_name[parent_organ]
	if(P)
		if(P.internal_organs == null)
			P.internal_organs = list()
		P.internal_organs += src
	H.internal_organs.Add(src)
	H.internal_organs_by_name[name] = src
	owner = H
	return



/****************************************************
				INTERNAL ORGANS DEFINES
****************************************************/

/datum/organ/internal/heart // This is not set to vital because death immediately occurs in blood.dm if it is removed.
	name = "heart"
	parent_organ = "chest"
	removed_type = /obj/item/organ/heart

/datum/organ/internal/heart/robotic
	robotic = 2
	damagelevel = 0.8
	emplevel = list(40,15,10)
	desc = "Mechanical"
	removed_type = /obj/item/organ/heart/prosthetic

/datum/organ/internal/heart/robotic/process()
	germ_level = 0
	return

/datum/organ/internal/heart/mechanize()
	new /datum/organ/internal/heart/robotic(owner)
	return

/datum/organ/internal/heart/assisted
	robotic = 1
	min_bruised_damage = 15
	min_broken_damage = 35
	emplevel = list(20,7,3)
	desc = "Assisted"

/datum/organ/internal/heart/mechassist()
	new /datum/organ/internal/heart/assisted(owner)
	return



/datum/organ/internal/lungs
	name = "lungs"
	parent_organ = "chest"
	removed_type = /obj/item/organ/lungs

/datum/organ/internal/lungs/process()
	..()
	if (germ_level > INFECTION_LEVEL_ONE)
		if(prob(5))
			owner.emote("cough")		//respitory tract infection

	if(is_bruised())
		if(prob(2))
			spawn owner.emote("me", 1, "coughs up blood!")
			owner.drip(10)
		if(prob(4))
			spawn owner.emote("me", 1, "gasps for air!")
			owner.losebreath += 15

/datum/organ/internal/lungs/robotic
	robotic = 2
	damagelevel = 0.8
	emplevel = list(40,15,10)
	desc = "Mechanical"
	removed_type = /obj/item/organ/lungs/prosthetic

/datum/organ/internal/lungs/robotic/process()
	germ_level = 0
	return

/datum/organ/internal/lungs/mechanize()
	new /datum/organ/internal/lungs/robotic(owner)
	return

/datum/organ/internal/lungs/assisted
	robotic = 1
	min_bruised_damage = 15
	min_broken_damage = 35
	emplevel = list(20,7,3)
	desc = "Assisted"

/datum/organ/internal/lungs/mechassist()
	new /datum/organ/internal/lungs/assisted(owner)
	return



/datum/organ/internal/liver
	name = "liver"
	parent_organ = "chest"
	removed_type = /obj/item/organ/liver

	process()

		..()

		if (germ_level > INFECTION_LEVEL_ONE)
			if(prob(1))
				owner << "\red Your skin itches."
		if (germ_level > INFECTION_LEVEL_TWO)
			if(prob(1))
				spawn owner.vomit()

		if(owner.life_tick % PROCESS_ACCURACY == 0)

			//High toxins levels are dangerous
			if(owner.getToxLoss() >= 60 && !owner.reagents.has_reagent("charcoal"))
				//Healthy liver suffers on its own
				if (src.damage < min_broken_damage)
					src.damage += 0.2 * PROCESS_ACCURACY
				//Damaged one shares the fun
				else
					var/datum/organ/internal/O = pick(owner.internal_organs)
					if(O)
						O.damage += 0.2  * PROCESS_ACCURACY

			//Detox can heal small amounts of damage
			if (src.damage && src.damage < src.min_bruised_damage && owner.reagents.has_reagent("charcoal"))
				src.damage -= 0.2 * PROCESS_ACCURACY

			if(src.damage < 0)
				src.damage = 0

			// Get the effectiveness of the liver.
			var/d_filter_effect = 3
			if(is_bruised())
				d_filter_effect -= 1
			if(is_broken())
				d_filter_effect -= 2

			// Do some reagent d_filtering/processing.
			for(var/datum/reagent/R in owner.reagents.reagent_list)
				// Damaged liver means some chemicals are very dangerous
				// The liver is also responsible for clearing out alcohol and toxins.
				// Ethanol and all drinks are bad.K
				if(istype(R, /datum/reagent/ethanol))
					if(d_filter_effect < 3)
						owner.adjustToxLoss(0.1 * PROCESS_ACCURACY)
					owner.reagents.remove_reagent(R.id, R.metabolization_rate*d_filter_effect)
				// Can't cope with toxins at all
				else if(istype(R, /datum/reagent/toxin))
					if(d_filter_effect < 3)
						owner.adjustToxLoss(0.3 * PROCESS_ACCURACY)
					owner.reagents.remove_reagent(R.id, REAGENTS_METABOLISM*d_filter_effect)

/datum/organ/internal/liver/robotic
	robotic = 2
	damagelevel = 0.8
	emplevel = list(40,15,10)
	removed_type = /obj/item/organ/liver/prosthetic

/datum/organ/internal/liver/robotic/process()
	germ_level = 0
	return

/datum/organ/internal/liver/mechanize()
	new /datum/organ/internal/liver/robotic(owner)
	return

/datum/organ/internal/liver/assisted
	robotic = 1
	min_bruised_damage = 15
	min_broken_damage = 35
	emplevel = list(20,7,3)
	desc = "Assisted"

/datum/organ/internal/liver/mechassist()
	new /datum/organ/internal/liver/assisted(owner)
	return



/datum/organ/internal/kidney
	name = "kidneys"
	parent_organ = "groin"
	removed_type = /obj/item/organ/kidneys

	process()

		..()

		// Coffee is really bad for you with busted kidneys.
		// This should probably be expanded in some way, but fucked if I know
		// what else kidneys can process in our reagent list.
		var/datum/reagent/coffee = locate(/datum/reagent/drink/coffee) in owner.reagents.reagent_list
		if(coffee)
			if(is_bruised())
				owner.adjustToxLoss(0.1 * PROCESS_ACCURACY)
			else if(is_broken())
				owner.adjustToxLoss(0.3 * PROCESS_ACCURACY)

/datum/organ/internal/kidney/robotic
	robotic = 2
	damagelevel = 0.8
	emplevel = list(40,15,10)
	desc = "Mechanical"
	removed_type = /obj/item/organ/kidneys/prosthetic

/datum/organ/internal/kidney/robotic/process()
	germ_level = 0
	return

/datum/organ/internal/kidney/mechanize()
	new /datum/organ/internal/kidney/robotic(owner)
	return

/datum/organ/internal/kidney/assisted
	robotic = 1
	min_bruised_damage = 15
	min_broken_damage = 35
	emplevel = list(20,7,3)
	desc = "Assisted"

/datum/organ/internal/kidney/mechassist()
	new /datum/organ/internal/kidney/assisted(owner)
	return



/datum/organ/internal/brain
	name = "brain"
	parent_organ = "head"
	removed_type = /obj/item/organ/brain
	min_bruised_damage = 15
	min_broken_damage = 40			//30 was too little
	vital = 1

/datum/organ/internal/brain/xeno
	removed_type = /obj/item/organ/brain/xeno

/datum/organ/internal/brain/robotic
	robotic = 2
	damagelevel = 0.8
	emplevel = list(40,15,10)
	desc = "Mechanical"
	removed_type = /obj/item/organ/brain/prosthetic

/datum/organ/internal/brain/robotic/process()
	germ_level = 0
	return

/datum/organ/internal/brain/mechanize()
	new /datum/organ/internal/brain/robotic(owner)
	return

/datum/organ/internal/brain/assisted
	robotic = 1
	min_bruised_damage = 15
	min_broken_damage = 35
	emplevel = list(20,7,3)
	desc = "Assisted"

/datum/organ/internal/brain/mechassist()
	new /datum/organ/internal/brain/assisted(owner)
	return




/datum/organ/internal/eyes
	name = "eyes"
	parent_organ = "head"
	removed_type = /obj/item/organ/eyes

	process() //Eye damage replaces the old eye_stat var.
		..()
		if(is_bruised())
			owner.eye_blurry = 20
		if(is_broken())
			owner.eye_blind = 20

/datum/organ/internal/eyes/robotic
	damagelevel = 0.8
	emplevel = list(40,15,10)
	desc = "Mechanical"
	removed_type = /obj/item/organ/eyes/prosthetic

/datum/organ/internal/eyes/robotic/process()
	germ_level = 0
	if(is_bruised())
		owner.eye_blurry = 20
	if(is_broken())
		owner.eye_blind = 20

/datum/organ/internal/eyes/mechanize()
	new /datum/organ/internal/eyes/robotic(owner)
	return

/datum/organ/internal/eyes/assisted
	min_bruised_damage = 15
	min_broken_damage = 35
	emplevel = list(20,7,3)
	desc = "Assisted"

/datum/organ/internal/eyes/mechassist()
	new /datum/organ/internal/eyes/assisted(owner)
	return


/datum/organ/internal/appendix
	name = "appendix"
	parent_organ = "groin"
	removed_type = /obj/item/organ/appendix

/datum/organ/internal/proc/remove(var/mob/user)

	if(!removed_type) return 0

	var/obj/item/organ/removed_organ = new removed_type(get_turf(user))

	if(istype(removed_organ))
		removed_organ.organ_data = src
		removed_organ.update()
		organ_holder = removed_organ

	return removed_organ