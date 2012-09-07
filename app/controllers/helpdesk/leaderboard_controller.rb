class Helpdesk::LeaderboardController < ApplicationController
    
  def mini_list
    @mvp = mvp_scoper.first
    @fcr = fcr_scoper.first
    @customer_champ = customer_champ_scoper.first
    @speed_champ = speed_champ_scoper.first
    render :layout => false
  end

  private
    def mvp_scoper
      user_scoper
    end

    def fcr_scoper
      user_scoper.first_call
    end

    def customer_champ_scoper
      user_scoper.customer_champion
    end

    def speed_champ_scoper
      user_scoper.fast
    end

    def user_scoper
      current_account.support_scores.user_score.created_at_inside(*this_month)
    end

    def this_month
      @this_month ||= [Time.zone.now.beginning_of_month, Time.zone.now]
    end

end
