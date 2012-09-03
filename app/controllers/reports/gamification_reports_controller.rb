class Reports::GamificationReportsController < ApplicationController
	
	include Reports::GamificationReport

	before_filter { |c| c.requires_feature :scoreboard }
  before_filter { |c| c.requires_permission :manage_reports }
	before_filter :set_selected_tab

 	def generate
 		@champions = list_of_champions()
 		@sharp_shooters = list_of_sharpshooters()
    @fcr_agents = list_of_fcr()
    @happycustomers = list_of_happycustomers()
    render :partial => "/reports/gamification_reports/leaderboard"
  end

 	def set_selected_tab
   	@selected_tab = :reports
  end

end