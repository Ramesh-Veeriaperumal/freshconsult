module Ember
  class LeaderboardController < ApiApplicationController
    include ::Dashboard::LeaderboardMethods

    around_filter :run_on_slave
    around_filter :use_time_zone
    before_filter :validate_params
   
    def agents
      params[:mini_list].present? ? mini_list(params[:group_id]) : generate_leaderboard(params[:group_id])
    end

    def groups
      generate_leaderboard
    end
  end
end
