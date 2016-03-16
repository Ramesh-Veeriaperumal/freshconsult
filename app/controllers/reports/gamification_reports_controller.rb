class Reports::GamificationReportsController < ApplicationController
	
      include Reports::GamificationReport

      before_filter { |c| c.requires_feature :gamification }
       before_filter { redirect_to reports_path if current_account.disabled_old_reports_ui? }
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