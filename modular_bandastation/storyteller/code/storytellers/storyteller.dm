/datum/storyteller
	/// The name of the storyteller.
	var/name = "Abstract storyteller"
	/// The description of the storyteller.
	var/desc = "This is an abstract storyteller, it should never be used."
	/// The base rate at which round tension is descreased per second.
	/// Final value may depend on other things, like amount of security, medical staff etc.
	var/base_tension_decay_rate = 0.01
	/// Tension level that is passively decreased to with `tension_decay_rate` each subsystem fire.
	var/target_tension = MIN_TENSION
	/// Tension level for roundstart. Can be described as points available for roundstart events.
	var/expected_roundstart_tension = 20
	/// Specifies relative possibility of storyteller being picked for round.
	var/weight = 0
	/// Set of event tags that can't be picked for this storyteller.
	var/list/event_tag_blacklist = list()
	/// Associative list of event tags to their weight multipliers.
	/// 0 effectively disables events with specified tag, but recommended way is to use `event_tag_blacklist`.
	var/list/event_tag_weight_multipliers = list()

/datum/storyteller/proc/get_event_weight(datum/storyteller_event/event_to_check)
	SHOULD_NOT_OVERRIDE(TRUE)

	var/final_event_weight = event_to_check.weight
	if(final_event_weight <= 0)
		return 0

	for(var/tag in event_to_check.tags)
		var/weight_multiplier = event_tag_weight_multipliers[tag]
		if(isnull(weight_multiplier) || weight_multiplier < 0)
			continue

		if(weight_multiplier == 0)
			return 0

		final_event_weight = final_event_weight * weight_multiplier

	return final_event_weight

/datum/storyteller/proc/get_tension_decay_rate()
	return base_tension_decay_rate
