class Reports::ScoreboardReportsController < ApplicationController
	
	include Reports::ScoreboardReport

	before_filter { |c| c.requires_feature :scoreboard }
  	before_filter { |c| c.requires_permission :manage_reports }
	before_filter :set_selected_tab

	
	protected

 	def set_selected_tab
   		@selected_tab = :reports
   	end

end