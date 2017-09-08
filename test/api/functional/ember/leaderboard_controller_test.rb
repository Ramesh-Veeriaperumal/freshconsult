require_relative '../../test_helper'
['quest_helper.rb', 'user_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
# require "#{Rails.root}/spec/support/quest_helper.rb" }
module Ember
  class LeaderboardControllerTest < ::ActionController::TestCase
    include Gamification::Scoreboard::Constants
    include QuestHelper
    include UsersHelper
    include GroupHelper
    include PrivilegesHelper
    include Redis::RedisKeys
    include Redis::SortedSetRedis
    include ApiLeaderboardConstants

    def setup
      super
      initial_setup
    end

    def initial_setup
      @account.reload
      SupportScore.delete_all
      @limit = 1
      # Create Agent
      @agent_1 = add_test_agent(@account)
      @agent_2 = add_test_agent(@account)
      @agent_3 = add_test_agent(@account)

      quest_data = { value: '10', date: '6' }
      @soln_quest = create_article_quest(@account, quest_data)
      @tkt_quest_1 = create_ticket_quest(@account, quest_data)
      @tkt_quest_2 = create_ticket_quest(@account, quest_data = { value: '5', date: '4' })
      @current_month = Time.zone.now.month
      @current_user = User.current
      clear_redis_data
    end

    def test_mini_list_without_gamification_feature
      @account.features.gamification.destroy
      @account.revoke_feature(:gamification)
      @account.reload
      get :agents, construct_params(mini_list: true, version: 'private')
      assert_response 403
    ensure
      @account.features.gamification.create
      @account.add_feature(:gamification)
    end

    def test_mini_list_with_new_leaderboard_feature_for_mvp_without_current_user_values
      clear_redis_data
      redis_key = agents_leaderboard_key 'mvp'
      incr_score_of_sorted_set_redis(redis_key, @agent_1.id, 1000)
      incr_score_of_sorted_set_redis(redis_key, @agent_2.id, 5000)
      get :agents, construct_params(mini_list: true, version: 'private')
      responses = ActiveSupport::JSON.decode(response.body)
      assert_response 200
      clear_redis_data
    end

    def test_mini_list_with_new_leaderboard_feature_for_first_call_resolution_and_mvp
      clear_redis_data
      login_as(@agent_2)
      %w(sharpshooter mvp).each do |category|
        redis_key = agents_leaderboard_key category
        incr_score_of_sorted_set_redis(redis_key, @agent_1.id, 1000)
        incr_score_of_sorted_set_redis(redis_key, @agent_2.id, 5000)
        incr_score_of_sorted_set_redis(redis_key, @agent_3.id, 15_000)
        incr_score_of_sorted_set_redis(redis_key, @current_user.id, 10_000)
        get :agents, construct_params(mini_list: true, version: 'private')
        responses = ActiveSupport::JSON.decode(response.body)
        result = responses.find { |x| x['name'] == category }
        assert_response 200
        assert_not_empty result
        assert result['rank_holders'].count == 4
      end
      login_as(@current_user)
      clear_redis_data
    end

    def test_mini_list_with_new_leaderboard_feature_for_first_call_resolution_and_mvp_when_current_user_does_not_have_points
      clear_redis_data
      %w(sharpshooter mvp).each do |category|
        redis_key = agents_leaderboard_key category
        incr_score_of_sorted_set_redis(redis_key, @agent_1.id, 1000)
        incr_score_of_sorted_set_redis(redis_key, @agent_2.id, 15_000)
        incr_score_of_sorted_set_redis(redis_key, @agent_3.id, 5000)
        get :agents, construct_params(mini_list: true, version: 'private')
        responses = ActiveSupport::JSON.decode(response.body)
        result = responses.find { |x| x['name'] == category }
        assert_response 200
        assert_not_empty result

        assert result['rank_holders'].length == 1
        assert result['rank_holders'].first['user_id'] == @agent_2.id if result['rank_holders'].length == 1
      end
      clear_redis_data
    end

    def test_mini_list_with_new_leaderboard_feature_for_all_with_current_user_values
      clear_redis_data
      categories = CATEGORY_LIST.dup
      categories.insert(1, :love)
      clear_redis_data
      score = {}
      categories.each do |category|
        redis_key = agents_leaderboard_key category.to_s
        score[category] = [Random.rand(1000), Random.rand(1000), Random.rand(1000)]
        incr_score_of_sorted_set_redis(redis_key, @agent_1.id, score[category][0])
        incr_score_of_sorted_set_redis(redis_key, @agent_2.id, score[category][1])
        incr_score_of_sorted_set_redis(redis_key, User.current.id, score[category][2])
      end
      get :agents, construct_params(mini_list: true, version: 'private')
      responses = ActiveSupport::JSON.decode(response.body)
      responses.each do |r|
        type = r['name'].to_sym
        r['rank_holders'].each do |holder|
          assert holder['score'].to_i == score[type].max if holder[:rank] == 1
        end
      end
      clear_redis_data
    end

    private

      def create_support_score(params = {})
        new_ss = FactoryGirl.build(:support_score, user_id: params[:user_id],
                                                   score_trigger: params[:score_trigger],
                                                   group_id: params[:group_id] || nil,
                                                   score: params[:score],
                                                   scorable_id: params[:scorable_id],
                                                   scorable_type: params[:scorable_type])
        new_ss.save(validate: false)
      end

      def leaderboard_list_pattern(type, user)
        {
          name: type,
          user_id: user.id,
          avatar: user.avatar ? user.avatar.attachment_url_for_api : nil
        }
      end

      def agents_leaderboard_key(category)
        GAMIFICATION_AGENTS_LEADERBOARD % { account_id: @account.id, category: category, month: @current_month }
      end

      def clear_redis_data
        categories = CATEGORY_LIST.dup
        categories.insert(1, :love)
        categories.each do |category|
          redis_key = agents_leaderboard_key category.to_s
          $redis_others.perform_redis_op('del', redis_key)
        end
      end
  end
end
