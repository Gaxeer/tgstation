/datum/storyteller_event
	/// Name of the event.
	var/name = "Abstract event"
	/// Description of the event.
	var/desc = "This is an abstract event, it should never be used."
	/// The tension change caused by the event. Positive values increase tension, negative values decrease it.
	var/tension_change = 0
	/// The minimum tension required for the event to be considered.
	var/min_tension = 0
	/// The maximum tension required for the event to be considered.
	var/max_tension = 100
	/// Amount of players required to run this event.
	var/min_players = 0
	/// The weight of the event, used to determine its likelihood of being chosen.
	/// 0 means the event will never be chosen.
	var/weight = 0
	/// The minimum time since the round started for this event to be considered.
	var/min_time_since_roundstart = 0
	/// The maximum time since the round started for this event to be considered.
	var/max_time_since_rounstart = INFINITY
	/// The number of times this event has occurred in the current round.
	var/occurences = 0
	/// The maximum number of times this event can occur in a round.
	/// 0 means the event will never be triggered.
	var/max_occurences = 1
	/// Whether this event should alert observers when it occurs.
	var/alert_observers = TRUE
	/// Set of tags, used to specify the type of event.
	/// Specific storytellers can have weight multipliers per each tag.
	var/list/tags = list()

/datum/storyteller_event/proc/announce(fake)
	return

/datum/round_event/proc/announce_deadchat(random, cause)
	deadchat_broadcast(" has just been[random ? " randomly" : ""] triggered[cause ? " by [cause]" : ""]!", "<b>[control.name]</b>", message_type=DEADCHAT_ANNOUNCEMENT) //STOP ASSUMING IT'S BADMINS!

/datum/storyteller_event/proc/setup()
	return

/datum/storyteller_event/proc/start()
	return

/datum/storyteller_event/proc/spawnable()
	SHOULD_CALL_PARENT(TRUE)

	if(occurrences >= max_occurrences)
		return FALSE
	var/time_since_rounstart = STATION_TIME_PASSED()
	if(min_time_since_roundstart >= time_since_rounstart || max_time_since_rounstart <= time_since_rounstart)
		return FALSE
	if(players_amt < min_players)
		return FALSE
	// if(holidayID && !check_holidays(holidayID))
	// 	return FALSE
	if(EMERGENCY_ESCAPED_OR_ENDGAMED)
		return FALSE
	// if(ispath(typepath, /datum/round_event/ghost_role) && !(GLOB.ghost_role_flags & GHOSTROLE_MIDROUND_EVENT))
	// 	return FALSE

	return TRUE


/datum/storyteller_event/proc/valid_for_map()
	if(!length(tags))
		return FALSE

	if(SSmapping.is_planetary())
		if(!tags[TAG_PLANETARY])
			return FALSE
	else if(!tags[TAG_SPACE])
		return FALSE

	return TRUE
