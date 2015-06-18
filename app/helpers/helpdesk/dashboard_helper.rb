module Helpdesk::DashboardHelper
	 TOOLBAR_LINK_OPTIONS = {   "data-remote" => true, 
	                            "data-method" => :get,
	                            "data-response-type" => "script",
	                            "data-loading-box" => "#agents-list" }
	def find_activity_url(activity)
		activity_data = activity.activity_data
	 	(activity_data.empty? || activity_data[:path].nil? ) ? activity.notable : activity_data[:path]
	end

	def sidebar_content
		sidebar_content = ""

		if current_account.subscription.trial?
			sidebar_content.concat(content_tag :div, "", :rel => "remote", :class => "sidepanel hide", :id => "sales-manager-container",
	               "data-remote-url" => '/helpdesk/sales_manager' )
		end
		sidebar_content.concat(content_tag(:div,
			content_tag(:h3,t("helpdesk.dashboard.index.todo_title").html_safe, :class => "title").concat(render('/helpdesk/reminders/reminders',
			:reminders => current_user.reminders, :form_controller => Helpdesk::Reminder.new(), :show_info => true )),
			:class => "reminders sidepanel", :id => "reminders"))

		sidebar_content.concat(render :partial => '/freshfone/freshfone_dashboard') if current_account.freshfone_active?

		sidebar_content.concat(content_tag(:div, content_tag(:div, :class => "sloading loading-small loading-block"),
			:class => "sidepanel", :id => "chat-dashboard", :style => "display:none;"))

		sidebar_content.concat(content_tag :div, "", :rel => "remote", :class => "sidepanel", :id=> "moderation-stats",
		  "data-remote-url" => '/discussions/unpublished/moderation_count') if current_account.features?(:forums) and privilege?(:delete_topic)

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

	def group_list_filter
	    filter_list = current_account.groups.round_robin_groups.map{ |grp|
	      [grp.name,"?group_id=#{grp.id}",false]
	    }
	     dropdown_menu filter_list, TOOLBAR_LINK_OPTIONS
	end

	def chat_activated?
    	!current_account.subscription.suspended? && feature?(:chat) && current_account.chat_setting.display_id
  	end


	def groups
		current_account.groups_from_cache
	end

	def ffone_user_list
	 	agents_list =  @freshfone_agents.map { |agent|
	 	{ 	:id => agent.user_id,
	 		:name => agent.name,
	 		:last_call_time => (agent.last_call_at) ,
	 		:presence => agent.presence,
	 		:on_phone => agent.available_on_phone,
	 		:avatar => user_avatar(agent.user, 'thumb', 'preview_pic thumb'),
	 		:preference => agent.incoming_preference}
	  }.to_json
	 end

	 def current_group
	 	@freshfone_group_current
	 end	

	 def round_robin?
	 	@round_robin_enabled ||=
	 	current_user.privilege?(:admin_tasks) and
	 	current_account.features?(:round_robin) and
    	current_account.groups.round_robin_groups.any?   	
	 end

	 def freshfone_active?
	 	@freshfone_enabled ||=
	 	current_user.privilege?(:admin_tasks) and
	 	current_account.freshfone_active? and 
	 	current_account.features?(:phone_agent_availability)
	 end
end
