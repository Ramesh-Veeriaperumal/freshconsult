class Helpdesk::LeaderboardController < ApplicationController
  before_filter :set_selected_tab
  before_filter { |c| c.requires_this_feature :gamification }
  around_filter :run_on_slave

  helper Helpdesk::LeaderboardHelper
  include Redis::RedisKeys
  include Redis::SortedSetRedis

  def mini_list
    @mini_list_leaderboard = {}
    support_score = SupportScore.new
    current_time = Time.now.in_time_zone current_account.time_zone

    category_list.each do |category|
      if current_user.privilege?(:view_reports)
        response = support_score.get_leader_ids current_account, "agents", category, current_time, 1
        @mini_list_leaderboard[category] = current_account.technicians.includes(:avatar).find(response.first.first) if response
      end
    end
    render :layout => false
  end

  def agents
    generate_leaderboard
  end

  def groups
    generate_leaderboard
  end

  def group_agents
    @group = current_account.groups.find(params[:id])
    generate_leaderboard
  end

  private

    def generate_leaderboard
      @leaderboard = {}
      support_score = SupportScore.new(:group_id => params[:id])
      group_action = params[:action] == "groups"

      if params[:date_range] == "select_range" && params[:date_range_selected].present?
        @date_range_val = "select_range"
        @date_range_selected = params[:date_range_selected]
        start_time = get_time(@date_range_selected.split(" - ")[0])
        end_time = get_time(@date_range_selected.split(" - ")[1]).end_of_day
        leader_module = group_action ? "group" : "user"

        category_list.each do |category|
          scoper = support_score.safe_send("#{params[:action]}_scoper", current_account, start_time, end_time)
          scoper = scoper.includes(:group) if group_action
          result = category == :mvp ? scoper.limit(50).all : scoper.safe_send(category).limit(50).all
          @leaderboard[category] = []

          result.each do |score|
            @leaderboard[category] << [score.safe_send(leader_module), score.tot_score]
          end
        end
      else
        current_time = Time.now.in_time_zone current_account.time_zone
        module_association = group_action ? "groups" : "all_users"

        category_list.each do |category|
          leader_module_ids = support_score.get_leader_ids current_account, params[:action], category, get_months_ago_value.month.ago(current_time.end_of_month), 50
          @leaderboard[category] = []

          if leader_module_ids
            id_list = leader_module_ids.map(&:first).join(',')
            result = current_account.safe_send(module_association).where("id in (#{id_list}) #{group_action ? "" : "and helpdesk_agent = 1 and deleted = 0"}").order("FIELD(id, #{id_list})")
            result = result.includes(:avatar) unless group_action

            result.each_with_index do |leader_module, counter|
              @leaderboard[category] << [leader_module, leader_module_ids[counter][1]]
            end
          end
        end      
      end      
    end

    def get_months_ago_value
      @date_range_val = params[:date_range] && params[:date_range] != "select_range" ? params[:date_range] : "current_month"

      range_vs_months = {
        "3_months_ago" => 3,
        "2_months_ago" => 2,
        "last_month" => 1,
        "current_month" => 0
      }

      range_vs_months[@date_range_val]
    end

    def category_list
      categories = [:mvp, :sharpshooter, :speed]
      categories.insert(1, :love) if current_account.any_survey_feature_enabled_and_active?

      categories
    end

    def get_time(time)
      Time.zone.parse(time.to_s)
    end

    def set_selected_tab
      @selected_tab = :dashboard
    end

    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end
end
