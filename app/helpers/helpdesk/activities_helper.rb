module Helpdesk::ActivitiesHelper

	ACTIVITIES_NOT_TO_COMBINE = [
									'timesheet', 'new_ticket', 
									'ticket_merge', 'ticket_split', 
									'deleted', 'restored' ,
									'assigned', 'reassigned'
								]

	ACTIVITY_TYPES_IN_IMPORTANCE_ORDER = 	[
												'status_change', #V
												'priority_change', #V
												'group_change', #T
												'group_change_none', #T
												'product_change',
												'product_change_none',
												'source_change',
												'ticket_type_change'
											]
	#The above list is only activity types that would be stacked.

	def stacked_view(activities)
		activity_stack = stack(activities)
		output = ""
		activity_stack.each do |activity|
			# output << content_tag(:div, 
			# 			( link_to(h(activity[:user]), activity[:user]) if activity[:without_user] +
			# 				activity[:stack].join(", ") +
			# 				content_tag(:div, activity[:time].strftime("%B %e %Y at %I:%M %p"), :class => 'activity_time') ),
			# 			:class => 'local_activities')
			output << "<div class='local_activities'>"
			output << link_to(h(activity[:user]), activity[:user]) if activity[:without_user]
			output << " " #Space after providing a link to the user.
			if activity[:stack].size > 1
				output << t('activities.action_verb')
				output << activity[:stack].map{|act| act.gsub(t('activities.action_verb'), '')}.to_sentence
			else
				output << activity[:stack].first
			end
			output << content_tag(:div, activity[:time].strftime("%B %e %Y at %I:%M %p"), :class => 'activity_time')
			output << content_tag(:span, "", :class => 'seperator')
			output << "</div>"
		end

		output
	end

	def stacked_for_dashboard(activities)
		activity_stack = stack(activities,true)

		output = ""
		activity_stack.each do |activity|

			# single_activity = activity[:stack].size == 1
			output << "<li class='clearfix activity' id='#{activity[:last_activity]}'> "
			output << user_avatar( activity[:user])
			output << " " #Space after providing a link to the user.
			if activity[:stack].size > 1
				output << show_contact_hovercard(activity[:user])
				output << t('activities.action_verb') + " "
				output << activity[:stack].map{|act| act.gsub(t('activities.action_verb'), '')}.to_sentence
				output << " on " if activity[:without_user]
				output << link_to(h(activity[:notable]), activity[:notable], :class => "notelink")
				
			else
				output << activity[:stack_single]
			end

			output << content_tag(:div, time_ago_in_words(activity[:time]), :class => 'activity_time', :title => activity[:time].strftime("%a, %d %b %Y %H:%M:%S %z") )
			output << "</li>"
		end

		output
	end

	private

		def stack(activities, for_dashboard = false)
			# activities_not_to_combine = [	'timesheet','new_ticket', 'ticket_merge', 'ticket_split', 'deleted', 'restored' ,'assigned']
			activity_stack = []
			previous_activity = {}

			activities.each do |activity| 
				can_combine = can_combine?(activity)
				eligible = (previous_activity.blank?) ? true : eligible?(activity, previous_activity)

				unless can_combine and eligible
					activity_stack << previous_activity unless previous_activity.blank?
					previous_activity = {}
				end

				previous_activity[:stack] ||= []
				previous_activity[:types] ||= []

				previous_activity[:time] = activity.created_at
				previous_activity[:user] = activity.user
				previous_activity[:last_activity] = activity.id if previous_activity[:last_activity].blank? or previous_activity[:last_activity] < activity.id
				previous_activity[:notable] = activity.notable

				template = can_combine ? activity.short_descr.chomp('.short') + '.without_user' : activity.short_descr
				
				user_path = for_dashboard ? show_contact_hovercard(activity.user) : link_to(h(activity.user), activity.user)

				previous_activity[:stack] << Liquid::Template.parse(t(template)).render(eval_activity_data(activity.activity_data).merge(
												'user_path' => user_path,
												'notable_path' => link_to(h(activity.notable), activity.notable) ))
				previous_activity[:stack_single] = Liquid::Template.parse( t(activity.description)).render(eval_activity_data(activity.activity_data).merge(
								'user_path' => user_path,
								'notable_path' => link_to(h(activity.notable), activity.notable) ))

				previous_activity[:types] << (activity.is_ticket? ? activity.ticket_activity_type : activity.type)
				
				if can_combine
					previous_activity[:without_user] = true
				else
					previous_activity[:without_user] = false
					activity_stack << previous_activity
					previous_activity = {}
				end

			end
			activity_stack << previous_activity unless previous_activity.blank?
			activity_stack
		end

		def important_type(types)
			return types.first if types.size == 1

			types_importance = types.map { |type| {:index => ACTIVITY_TYPES_IN_IMPORTANCE_ORDER.index(type), :type => type}}
			types_importance.sort! { |x,y| x[:index] <=> y[:index]}.first[:type]
		end

		def can_combine?(activity)
			# puts "activity.ticket_activity_type :: #{activity.ticket_activity_type}"
			activity.is_ticket? and !(ACTIVITIES_NOT_TO_COMBINE.include?(activity.ticket_activity_type) or activity.is_note?)
		end

		def eligible?(activity, previous_activity) 
			in_short_span?(activity, previous_activity) and same_user?(activity, previous_activity) and same_notable?(activity,previous_activity[:notable])
		end

		def in_short_span?(activity, previous_activity)
			activity.created_at - previous_activity[:time] <= 2.minutes
		end

		def same_user?(activity, previous_activity)
			activity.user_id == previous_activity[:user].id
		end

		def same_notable?(current,previous_notable) 
			current.notable.class.name == previous_notable.class.name and current.notable.id == previous_notable.id
		end

end
