module Helpdesk::DashboardHelper
	def find_activity_url(activity)
		activity_data = activity.activity_data
	 	(activity_data.empty? || activity_data[:path].nil? ) ? activity.notable : activity_data[:path]
	end

	def sidebar_content
		sidebar_content = ""
		if current_account.subscription.trial? && current_account.subscription.trial_days < AppConfig['show_trail_notifier_in_days']
			sidebar_content.concat(render('/subscriptions/state/trial_expiry_notifier'))
		end
		sidebar_content.concat(content_tag(:div,
			content_tag(:h3,t(".todo_title").html_safe, :class => "title").concat(render('/helpdesk/reminders/reminders',
			:reminders => current_user.reminders, :form_controller => Helpdesk::Reminder.new(), :show_info => true )),
			:class => "reminders sidepanel", :id => "reminders"))

		sidebar_content.concat(render :partial => '/freshfone/freshfone_dashboard') if current_account.freshfone_enabled?

		sidebar_content.concat(content_tag(:div, content_tag(:div, :class => "sloading loading-small loading-block").concat("<script>if(window.dashboardView){dashboardView.render(true);}</script>"),
			:class => "side-panel", :id => "chat-dashboard", :style => "display:none;"))

		sidebar_content.html_safe
	end

	def complimentary_demo_link
		demo_content = content_tag(:p, t('hard_pressed_for_time') )
	
		demo_content.concat(content_tag(:p,
			content_tag(:b, link_to( t('schedule_a_complimentary_session').html_safe, 
				"http://resources.freshdesk.com/demoRequest.html?utm_source=freshdeskapp&utm_medium=inapp&utm_campaign=complimentarydemo",
				:onclick => "window.open(this.href);return false;", :target => "_blank" ) )
			))
	end
end
