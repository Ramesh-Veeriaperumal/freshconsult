class Helpdesk::LeaderboardController < ApplicationController
  before_filter :set_selected_tab
  before_filter { |c| c.requires_feature :gamification }

  helper Helpdesk::LeaderboardHelper

  def mini_list    
      generate_score_card
      render :layout => false
  end

  def agents
    generate_score_card 50
  end

  def groups
    generate_score_card 50, :group
  end

  def group_agents
    generate_score_card 50, :group_agents
  end

  private
    def generate_score_card( _limit = 1, type = :user )
        case type
          when :group_agents
            c_card = group_agent_scoper
          when :group
            c_card = group_scoper
          else
            c_card = user_scoper
        end

      [:mvp, :first_call, :customer_champion, :fast].each do |item|
        instance_variable_set "@#{item}_scorecard", ((item == :mvp) ? c_card : c_card.send(item)).limit(_limit)
      end
    end

    def user_scoper
      current_account.support_scores.by_performance.user_score(user_scope_params).created_at_inside(*get_date_range)
    end

    def group_scoper
      current_account.support_scores.by_performance.group_score.created_at_inside(*get_date_range)
    end

    def group_agent_scoper
      @group = current_account.groups.find(params[:id])
      current_account.support_scores.by_performance.user_score(group_agent_scope_params).created_at_inside(*get_date_range)
    end

    def this_month
      @this_month ||= [Time.zone.now.beginning_of_month, Time.zone.now]
    end

    def set_selected_tab
      @selected_tab = :dashboard
    end

    def get_date_range
      @date_range_val = params[:date_range] ? params[:date_range] : "current_month"
      case @date_range_val
        when "3_months_ago"
          @this_month = [get_time(3.month.ago.beginning_of_month), get_time(3.month.ago.end_of_month)]
        when "2_months_ago"
          @this_month = [get_time(2.month.ago.beginning_of_month), get_time(2.month.ago.end_of_month)]
        when "last_month"
          @this_month = [get_time(1.month.ago.beginning_of_month), get_time(1.month.ago.end_of_month)]
        else
          @this_month = [Time.zone.now.beginning_of_month, Time.zone.now]
      end
    end

    def get_time(time)
      Time.zone.parse(time.to_s)
    end

    def user_scope_params
      { :conditions => ["user_id is not null"] }
    end

    def group_agent_scope_params
      { :conditions => ["support_scores.group_id = ?", @group.id] }
    end

end
