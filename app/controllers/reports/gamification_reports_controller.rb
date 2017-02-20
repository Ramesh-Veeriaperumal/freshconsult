class Reports::GamificationReportsController < ApplicationController
	
      include Reports::GamificationReport

      before_filter { |c| c.requires_this_feature :gamification }
       before_filter { redirect_to reports_path unless current_account.old_reports_enabled? }
      before_filter :set_selected_tab

      def index
        @champions = champions
        @sharp_shooters = sharpshooters
        @fcr_agents = first_call_resolution
        @happycustomers = happy_customers
      end

      def set_selected_tab
        @selected_tab = :reports
      end
end