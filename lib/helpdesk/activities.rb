module Helpdesk::Activities

	def stacked_activities(activities)
		activity_stack = []
		notes_to_fetch = []
		activity = {}
		previous_activity_meta = {} #This hash is used to determine whether the activity can combine with the next one.

		activities.each do |current_activity| 
			can_combine = can_combine?(current_activity)
			eligible = (activity.blank?) ? true : eligible?(current_activity, previous_activity_meta)

			unless can_combine and eligible
				activity_stack << combine(activity, previous_activity_meta) unless activity.blank?
				activity = {}
				previous_activity_meta = {}
			end

			activity[:stack] ||= []
			previous_activity_meta[:types] ||= []

			previous_activity_meta[:time] = current_activity.created_at
			previous_activity_meta[:user] = current_activity.user
			previous_activity_meta[:notable_type] = current_activity.notable_type
			previous_activity_meta[:notable_id] = current_activity.notable_id
			previous_activity_meta[:types] << (current_activity.ticket? ? current_activity.ticket_activity_type : current_activity.type)

			activity[:stack] << current_activity
			activity[:time] = current_activity.created_at
			activity[:user] ||= current_activity.user
			activity[:is_note] = current_activity.note?

			if activity[:is_note]
				notes_to_fetch << current_activity.note_id
			end

			unless can_combine
				activity_stack << combine(activity, previous_activity_meta)
				activity = {}
				previous_activity_meta = {}
			end

		end

		activity_stack << combine(activity, previous_activity_meta) unless activity.blank?
		prefetch_notes(notes_to_fetch)
		activity_stack
	end

private


	ACTIVITIES_NOT_TO_COMBINE = [
									'new_ticket', 
									'ticket_merge', 'ticket_split', 
									'deleted', 'restored',
									'timesheet.new', 'timesheet.timer_started', 'timesheet.timer_stopped'
								]

	ACTIVITY_TYPES_IN_IMPORTANCE_ORDER = 	[
												'status_change', #V
												'assigned', #V
												'reassigned', #V
												'assigned_to_nobody', #T
												'priority_change', #V
												'group_change', #T
												'group_change_none', #T
												'product_change', #V
												'product_change_none', #T
												'source_change', #V
												'ticket_type_change', #V
												'execute_scenario' #V
											]
	#The above list is only activity types that would be stacked.


	ACTIVITY_TYPES_REQUIRING_DATA_FOR_IMPORTANT_TYPE = [ 'priority_change', 'status_change' ]


	def can_combine?(activity)
		activity.ticket? and !(ACTIVITIES_NOT_TO_COMBINE.include?(activity.ticket_activity_type) or activity.note?)
	end

	def eligible?(activity, previous_activity) 
		in_short_span?(activity, previous_activity) and same_user?(activity, previous_activity) and same_notable?(activity,previous_activity)
	end

	def in_short_span?(activity, previous_activity)
		activity.created_at - previous_activity[:time] <= 2.minutes or previous_activity[:time] - activity.created_at <= 2.minutes
	end

	def same_user?(activity, previous_activity)
		activity.user_id == previous_activity[:user].id
	end

	def same_notable?(current, previous_activity)
		current.notable_type == previous_activity[:notable_type] and current.notable_id == previous_activity[:notable_id]
	end

	def combine(activity, previous_activity_meta) #combine!
		activity[:important] = highlight(previous_activity_meta[:types], activity[:stack])
		activity
	end

	def highlight(types, stack)
		type = important_type(types)
		value = ""
		if [ 'priority_change', 'status_change' ].include?(type) 
			reversed = stack.reverse
			reversed.each do |act|

				if act.short_descr == "activities.tickets.#{type}.short"
					value = act.activity_data.values.first
					break
				end
			end
		end
		{:type => type, :value => value}
	end

	def important_type(types)
		return types.first if types.size == 1
		types_importance = types.map { |type| {:index => ACTIVITY_TYPES_IN_IMPORTANCE_ORDER.index(type), :type => type}}
		types_importance.sort! { |x,y| x[:index] <=> y[:index]}.first[:type]
	end

	def prefetch_notes(note_ids)
		notes = Helpdesk::Note.find(note_ids, :include => :user)
		@prefetched_notes = Hash[*notes.map { |note| [note.id, note] }.flatten]

	end

end