#define STATION_REPORT_TEMPLATE_PATH "modular_bandastation/storyteller/templates/station_report.md"
#define MIN_TENSION 0
#define MAX_TENSION 100
#define RANDOM_EVENT_ADMIN_INTERVENTION_TIME (30 SECONDS)

SUBSYSTEM_DEF(event_manager)
	name = "Event Manager"
	runlevels = RUNLEVEL_GAME
	flags = SS_BACKGROUND | SS_KEEP_TIMING
	priority = 20
	wait = 1 SECONDS
	/// Tension is a measure of how intense the current situation is, with higher values indicating more intense situations.
	/// Tension can be increased or decreased by various events and actions in the game.
	/// It is used to determine which events are available to trigger.
	/// Can't be negative. By default lies in range from 0 to 100
	var/tension = MIN_TENSION
	/// The storyteller picked for the round.
	var/datum/storyteller/active_storyteller = null
	/// The list of available events that can be triggered by the event manager.
	var/list/available_events = list()
	/// Events that are currently planned to run. Event ref => timer_id.
	var/list/planned_events = list()
	/// Events that are currently active. List of `/datum/storyteller_event_holder`.
	var/list/running_event = list()
	/// Events that occured during the round.
	var/list/occured_events = list()


/datum/controller/subsystem/event_manager/Initialize()
	var/list/storytellers_pool = list()
	for(var/datum/storyteller/storyteller_path as anything in subtypesof(/datum/storyteller))
		storytellers_pool[storyteller_path] = storyteller_path::weight

	if(!length(storytellers_pool))
		stack_trace("No storytellers exist. Fix it.")
		return SS_INIT_FAILURE

	var/picked_storyteller_path = pick_weight(storytellers_pool)
	active_storyteller = new picked_storyteller_path()

	for(var/datum/storyteller_event/event_path as anything in subtypesof(/datum/storyteller_event))
		var/datum/storyteller_event/event_instance = new event_path()
		if(!event_instance.valid_for_map())
			continue

		available_events += event_instance

	if(!length(available_events))
		stack_trace("No available events to run.")
		return SS_INIT_FAILURE

	return SS_INIT_SUCCESS

/datum/controller/subsystem/event_manager/fire(resumed)
	tension -= active_storyteller.get_tension_decay_rate()
	process_events()
	if(!try_pick_event())

/datum/controller/subsystem/event_manager/Topic(href, list/href_list)
	..()
	if(!check_rights(R_ADMIN))
		message_admins("[usr.key] has attempted to interact with event manager!")
		log_admin("[key_name(usr)] has attempted to interact with event manager.")
		return

	if(href_list["cancel_event"])
		cancel_event(locate(href_list["cancel_event"]))
	else if(href_list["different_event"])
		cancel_event(locate(href_list["different_event"]), reroll_event = TRUE)

/datum/controller/subsystem/event_manager/proc/process_running_events(resumed)
	for(var/datum/storyteller_event_holder/event_holder as anything in running_event)

/// Picks and plans event to be runned.
/// Returns whether or not event was successfully picked.
/datum/controller/subsystem/event_manager/proc/try_pick_event()
	var/list/pickable_events_pool = prepare_pickable_pickable_events_pool()
	return TRUE

/datum/controller/subsystem/event_manager/proc/plan_event(datum/storyteller_event/event, delay = 0)
	message_admins(
		"Random Event triggering in [DisplayTimeText(RANDOM_EVENT_ADMIN_INTERVENTION_TIME)]: [event.name]. \
		(<a href='byond://?src=[REF(src)];cancel_event=[REF(event)]'>CANCEL</a>) (<a href='byond://?src=[REF(src)];different_event=[REF(event)]'>SOMETHING ELSE</a>)"
	)

/datum/controller/subsystem/event_manager/proc/cancel_planned_event(datum/storyteller_event_holder/event_to_cancel, reroll_event = FALSE)
	var/timer_id = planned_events[event_to_cancel]
	if(!timer_id)
		return

	deltimer(timer_id)
	planned_events -= event_to_cancel

	if(reroll_event)
		try_pick_event()


/datum/controller/subsystem/event_manager/proc/prepare_pickable_pickable_events_pool()
	PRIVATE_PROC(TRUE)

	var/list/pickable_events_pool = list()
	for(var/datum/storyteller_event/event as anything in available_events)
		if(min_tension > tension || max_tension < tension)
			continue

		var/event_weight = active_storyteller.get_event_weight(event)
		if(event_weight <= 0)
			continue

		if(!event.spawnable())
			continue

		pickable_events_pool[event] = event_weight

	return pickable_events_pool

/*
 * Generate a list of station goals available to purchase to report to the crew.
 *
 * Returns a formatted string all station goals that are available to the station.
 */
/datum/controller/subsystem/event_manager/proc/generate_station_goal_report()
	if(GLOB.communications_controller.block_command_report) //If we don't want the report to be printed just yet, we put it off until it's ready
		addtimer(CALLBACK(src, PROC_REF(generate_station_goal_report)), 10 SECONDS)
		return

	if(!fexists(STATION_REPORT_TEMPLATE_PATH))
		stack_trace("station report template doesn't exist at path: [STATION_REPORT_TEMPLATE_PATH]")
		return

	var/station_report_template = file2text(STATION_REPORT_TEMPLATE_PATH)
	if(!station_report_template)
		stack_trace("station report template doesn't is empty at path: [STATION_REPORT_TEMPLATE_PATH]")
		return

	var/list/datum/station_goal/goals = SSstation.get_station_goals()
	var/station_goals_section = ""
	if(length(goals))
		var/list/station_goal_reports = list()
		for(var/datum/station_goal/station_goal as anything in goals)
			station_goal.on_report()
			station_goal_reports += station_goal.get_report()

		station_goals_section = list(
			"# === Цели на смену ===\n",
			station_goal_reports.Join("\n\n---\n\n"),
		).Join()

	station_report_template = replacetext(station_report_template, "%STATION_GOALS", station_goals_section);

	var/list/trait_reports = list()
	for(var/datum/station_trait/station_trait as anything in SSstation.station_traits)
		if(!station_trait.show_in_report)
			continue

		trait_reports += "- [station_trait.get_report()]"

	var/trait_reports_sections = ""
	if(length(trait_reports))
		trait_reports_sections = list(
			"\n\n---\n\n",
			"# === Обнаруженные отклонения ===\n",
			trait_reports.Join("\n")
		).Join()

	station_report_template = replacetext(station_report_template, "%TRAIT_REPORTS", trait_reports_sections);

	var/footnote_section = ""
	if(length(GLOB.communications_controller.command_report_footnotes))
		var/list/footnotes = list()
		for(var/datum/command_footnote/footnote in GLOB.communications_controller.command_report_footnotes)
			footnotes += "[footnote.message]<BR>"
			footnotes += "<i>[footnote.signature]</i><BR>"
			footnotes += "<BR>"

		footnote_section = list(
			"\n\n---\n\n",
			"# === Дополнительная информация ===\n",
			footnotes.Join()
		).Join()

	station_report_template = replacetext(station_report_template, "%FOOTNOTES", footnote_section);
	station_report_template = replacetext(station_report_template, "%SIGNING_OFFICER", "[pick(GLOB.first_names_male)] [pick(GLOB.last_names)]");

	station_report_template = replace_text_keys(station_report_template)

#ifndef MAP_TEST
	print_command_report(station_report_template, "[command_name()] Status Summary", announce=FALSE)
	priority_announce("Отчет был скопирован и распечатан на всех консолях связи.", "Отчет о безопасности", SSstation.announcer.get_rand_report_sound())
#endif

#undef STATION_REPORT_TEMPLATE_PATH
