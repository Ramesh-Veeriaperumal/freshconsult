module Helpdesk::LeaderboardHelper
		
	include MemcacheKeys

	def get_memcache_key
		MemcacheKeys.memcache_local_key(LEADERBOARD_MINILIST)
	end

	def link_to_agent user
		return(link_to user.name, user) if current_user && current_user.can_view_all_tickets?
		user.name
	end	

	def leaderboard
		@leaderboard ||= load_leaderboard
	end

	def customer_satisfaction_enabled?
		current_account.features?(:surveys, :survey_links)
	end

	def date_filter
		content = ""
		content << " #{t('gamification.leaderboard.showing') } <a role='button' class='dropdown-toggle' id='sorting_dropdown' data-toggle='dropdown' href='#'> <b>#{ t("gamification.leaderboard.date_range.#{@date_range_val}")}</b><b class='caret'></b></a>"
		content << "<ul class='dropdown-menu' role='menu' aria-labelledby='sorting_dropdown_list' id='sorting_dropdown_list'>"
		support_date_range.each do |date_range|
			content << "<span class='icon ticksymbol'></span>" if date_range == @date_range_val
			content << "<li>#{ link_to t("gamification.leaderboard.date_range.#{date_range}"), {:date_range => date_range} }</li>"
		end
		content << "</ul>"
		content.html_safe
	end

	def agents_filter
		current_group = @group ? "#{t('gamification.leaderboard.agents_in')} "+@group.name : "#{t('gamification.leaderboard.all_agents')}"
		content = ""
		content << "#{t('gamification.leaderboard.showing')}<a role='button' class='dropdown-toggle' id='sorting_dropdown' data-toggle='dropdown' href='#''> <b> #{current_group}</b><b class='caret'></b></a>"
		content << "<ul class='dropdown-menu' role='menu' aria-labelledby='sorting_dropdown_list' id='sorting_dropdown_list'>"
		content << "<span class='icon ticksymbol'></span>" if params[:action] == "agents"
		content << "<li>#{ link_to "#{t('gamification.leaderboard.all_agents')}", agents_helpdesk_leaderboard_index_path(:date_range => params[:date_range]), 'data-option' => 'all' }</li>"
		content << "<li class='dropdown-header agents_list_info'><b>#{t('gamification.leaderboard.agents_from_group')}</b></li>"
		current_account.groups.each do |group|
			content << "<span class='icon ticksymbol'></span>" if (params[:action] == "group_agents" && @group.id == group.id)
			content << "<li>#{link_to group.name, helpdesk_leaderboard_group_users_path( :id => group.id, :date_range => params[:date_range])} </li>"
		end
		content << "</ul>"
		content.html_safe
	end

	def leaderboard_tabs
		content = ""
		agent_class = ""
		group_class = ""
		content << "<a href='/'>< #{ t('gamification.leaderboard.back_to_dashboard') }</a>"
		group_action? ? group_class = "active" : agent_class = "active"
		content << "<ul class='nav nav-tabs'>"
		content << "<li id='agent-tab' class='#{agent_class}'>#{ link_to 'Agent', agents_helpdesk_leaderboard_index_path(:date_range => @date_range_val) }</li>"
		content << "<li id='group-tab' class='#{group_class}'>#{ link_to 'Group', groups_helpdesk_leaderboard_index_path(:date_range => @date_range_val) }</li>"
		content << "<div class='pull-right'>"
		content << (render :partial => "filter")
		content << "</div>"
		content << "</ul>"
		content.html_safe
	end

	def group_action?
		params[:action] == "groups"
	end

	private

		def load_leaderboard
			scoreboard = [[ @mvp_scorecard, :mvp],
				[ @first_call_scorecard, :sharpshooter],
				[ @fast_scorecard, :speed]]
			scoreboard.insert(1, [ @customer_champion_scorecard, :love]) if customer_satisfaction_enabled?
			
			scoreboard
		end

		def support_date_range
			[ "current_month", "last_month", "2_months_ago", "3_months_ago" ]
		end

end
