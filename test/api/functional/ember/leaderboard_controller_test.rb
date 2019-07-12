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
    include LeaderboardTestHelper

    def setup
      super
      initial_setup
    end

    def initial_setup
      @account.features.gamification_enable.create
      @account.add_feature(:gamification_enable)
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
      get :agents, controller_params(mini_list: true, version: 'private')
      assert_response 403
    ensure
      @account.features.gamification.create
      @account.add_feature(:gamification)
    end

    def test_mini_list_without_gamification_enable_feature
      @account.features.gamification_enable.destroy
      @account.revoke_feature(:gamification_enable)
      @account.reload
      get :agents, controller_params(mini_list: true, version: 'private')
      assert_response 403
    ensure
      @account.features.gamification_enable.create
      @account.add_feature(:gamification_enable)
    end

    def test_mini_list_with_new_leaderboard_feature_for_mvp_without_current_user_values
      clear_redis_data
      redis_key = agents_leaderboard_key 'mvp'
      incr_score_of_sorted_set_redis(redis_key, @agent_1.id, 1000)
      incr_score_of_sorted_set_redis(redis_key, @agent_2.id, 5000)
      get :agents, controller_params(mini_list: true, version: 'private')
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
        get :agents, controller_params(mini_list: true, version: 'private')
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
        get :agents, controller_params(mini_list: true, version: 'private')
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
      get :agents, controller_params(mini_list: true, version: 'private')
      responses = ActiveSupport::JSON.decode(response.body)
      responses.each do |r|
        type = r['name'].to_sym
        r['rank_holders'].each do |holder|
          assert holder['score'].to_i == score[type].max if holder[:rank] == 1
        end
      end
      clear_redis_data
    end

    def test_group_based_mini_list_leaderboard
      categories = CATEGORY_LIST.dup
      categories.insert(1, :love)

      create_group_agents

      odd_score = {}
      even_score = {}
      score = {}

      clear_redis_data
      clear_group_agents_redis_data(@group_odd, @group_even)

      categories.each do |category|
        # building group odd leaderboard in redis
        redis_key = group_agents_leaderboard_key category.to_s, @group_odd
        odd_score [category] = [Random.rand(1000), Random.rand(1000), Random.rand(1000)]
        create_group_leaderboard(redis_key, category, [@agent_one.id, @agent_three.id, @agent_five.id], odd_score)
        # building group even leaderboard in redis
        redis_key = group_agents_leaderboard_key category.to_s, @group_even
        even_score[category] = [Random.rand(1000), Random.rand(1000), Random.rand(1000)]
        create_group_leaderboard(redis_key, category, [@agent_two.id, @agent_four.id, @agent_six.id], even_score)

        # building account level leaderboard in redis
        redis_key = agents_leaderboard_key category.to_s
        create_account_leaderboard(redis_key, category, [@agent_one.id, @agent_three.id, @agent_five.id], odd_score)
        create_account_leaderboard(redis_key, category, [@agent_two.id, @agent_four.id, @agent_six.id], even_score)
        score[category] = even_score[category] + odd_score[category]
      end
      assert_minilist_response score # account level leaderboard assertion
      assert_minilist_response odd_score, @group_odd.id # group level leaderboard assertion
      assert_minilist_response even_score, @group_even.id # group level leaderboard assertion

      clear_redis_data
      clear_group_agents_redis_data(@group_odd)
      clear_group_agents_redis_data(@group_even)
    end

    def test_leader_board_agents
      clear_redis_data
      score_stub = Random.rand(1000)
      key = "GAMIFICATION_AGENTS_LEADERBOARD:1:sharpshooter:#{@current_month}"
      $redis_others.perform_redis_op('zadd', key, [score_stub, @agent_1.id])
      get :agents, controller_params(version: 'private')
      responses = ActiveSupport::JSON.decode(response.body)
      assert_response 200
      pattern = leaderboard_agent_pattern score_stub.to_f, @agent_1.id
      assert_equal(responses, pattern)
      clear_redis_data
    end

    def test_leaderboard_groups
      @group_odd = create_group_with_agents(@account)
      @group_even = create_group_with_agents(@account)
      clear_groups_redis_data
      score_stub = [@group_odd.id, @group_even.id].collect.with_index do |group_id, i|
        [group_id, Random.rand((i * 100)..((i + 1) * 100))]
      end
      redis_add_group_score(score_stub)
      get :groups, controller_params(version: 'private', date_range: 'current_month')
      responses = ActiveSupport::JSON.decode(response.body)
      assert_response 200
      pattern = leaderboard_group_pattern score_stub
      assert_equal(responses, pattern)
      clear_redis_data
    end

    def test_leaderboard_groups_with_invalid_date_range
      get :groups, controller_params(version: 'private', date_range: 'last_year')
      responses = ActiveSupport::JSON.decode(response.body)
      assert_response 400
    end

    def test_leaderboard_agents_with_filter_applied
      create_group_agents
      clear_group_agents_redis_data(@group_odd, @group_even)
      score_stub_odd = @group_odd.agents.map(&:id).collect.with_index do |agent, i|
        [agent, Random.rand((i * 100)..((i + 1) * 100))]
      end
      score_stub_even = @group_even.agents.map(&:id).collect.with_index do |agent, i|
        [agent, Random.rand((i * 100)..((i + 1) * 100))]
      end
      redis_add_group_agents_score(score_stub_odd, @group_odd.id)
      redis_add_group_agents_score(score_stub_even, @group_even.id, previous_month)

      get :agents, controller_params(version: 'private', group_id: @group_odd.id, date_range: 'current_month')
      assert_response 200
      pattern = (leaderboard_group_agents_pattern score_stub_odd).to_json
      responses = JSON.parse(response.body)
      assert_equal(responses, JSON.parse(pattern))

      get :agents, controller_params(version: 'private', group_id: @group_even.id, date_range: 'last_month')
      responses = ActiveSupport::JSON.decode(response.body)
      assert_response 200
      pattern = leaderboard_group_agents_pattern score_stub_even
      assert_equal(responses, pattern)

      clear_group_agents_redis_data(@group_odd, @group_even)
    end

    def test_leaderboard_agents_with_invalid_date_range
      get :agents, controller_params(version: 'private', date_range: 'current_year')
      responses = ActiveSupport::JSON.decode(response.body)
      assert_response 400
    end
    
    def test_leaderboard_agents_with_invalid_group_selected
      invalid_group = Account.current.groups.maximum(:id) + 9999
      get :agents, controller_params(version: 'private', group_id: invalid_group)
      responses = ActiveSupport::JSON.decode(response.body)
      assert_response 200
      pattern = empty_leaderboard_agent_pattern
      assert_equal(responses, pattern)
    end
  end
end
