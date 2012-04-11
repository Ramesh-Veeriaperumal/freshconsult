class Reports::ScoreboardReportsController < ApplicationController
	
	include Reports::ScoreboardReport

	before_filter { |c| c.requires_feature :scoreboard }
  	before_filter { |c| c.requires_permission :manage_reports }
	before_filter :set_selected_tab

 	def generate
 		@champions = list_of_champions()
 		@sharp_shooters = list_of_sharpshooters()
    		render :partial => "/reports/scoreboard_reports/leaderboard"
  	end

 	def set_selected_tab
   		@selected_tab = :reports
   	end

end