class Helpdesk::LeaderboardController < ApplicationController
  before_filter :set_selected_tab
    
  def mini_list
    generate_score_card
    render :layout => false
  end

  def user_list
    generate_score_card 10
  end

  def group_list
    generate_score_card 10, :group
  end

  private
    def generate_score_card( _limit = 1, type = :user )
      c_card = (type == :user) ? user_scoper : group_scoper

      [:mvp, :first_call, :customer_champion, :fast].each do |item|
        instance_variable_set "@#{item}_scorecard", ((item == :mvp) ? c_card : c_card.send(item)).limit(_limit)
      end
    end

    def user_scoper
      current_account.support_scores.user_score.created_at_inside(*this_month)
    end

    def group_scoper
      current_account.support_scores.group_score.created_at_inside(*this_month)
    end

    def this_month
      @this_month ||= [Time.zone.now.beginning_of_month, Time.zone.now]
    end

    def set_selected_tab
      @selected_tab = :dashboard
    end

end
