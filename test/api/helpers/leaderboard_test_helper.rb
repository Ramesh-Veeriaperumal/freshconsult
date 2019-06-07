module LeaderboardTestHelper
  CATEGORY_LIST = [:mvp, :sharpshooter, :speed].freeze

  protected

    def create_group_leaderboard(redis_key, category, agents_list, score)
      agents_list.each_with_index do |agent_id, index|
        incr_score_of_sorted_set_redis(redis_key, agent_id, score[category][index])
      end
    end

    def create_account_leaderboard(redis_key, category, agent_list, score)
      agent_list.each_with_index do |agent_id, index|
        incr_score_of_sorted_set_redis(redis_key, agent_id, score[category][index])
      end
    end

    def assert_minilist_response(score, group_id = nil)
      controller_parameters = { mini_list: true, version: 'private' }
      controller_parameters[:group_id] = group_id unless group_id.nil?
      get :agents, controller_params(controller_parameters)
      responses = ActiveSupport::JSON.decode(response.body)
      responses.each do |r|
        type = r['name'].to_sym
        r['rank_holders'].each do |holder|
          if holder['rank'] == 1
            assert holder['score'].to_i == score[type].max
          end
        end
      end
      assert_response 200
    end

    def build_controller_params(options)
      controller_parameters = { version: 'private', type: 'leaderboard' }
      controller_parameters[:group_id] = options[:group_id] if options[:test_endpoint] == :widget_data_preview && !options[:group_id].nil?
      controller_parameters[:id] = options[:dashboard_id] if options[:test_endpoint] == :widgets_data
      controller_parameters
    end

    def assert_widget_data_preview_leaderboard_response(score, options = {})
      controller_parameters = build_controller_params(options)
      get options[:test_endpoint], controller_params(controller_parameters)
      responses = ActiveSupport::JSON.decode(response.body)
      response_data = options[:test_endpoint] == :widget_data_preview ? responses['data'] : data = responses.first['widget_data']
      response_data.each do |r|
        type = r['name'].to_sym
        r['rank_holders'].each do |holder|
          if holder['rank'] == 1
            assert holder['score'].to_i == score[type].max
          end
        end
      end
      assert_response 200
    end

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
        avatar: user.avatar ? user_avatar(user) : nil
      }
    end

    def user_avatar(user)
      thumb_url = user.avatar.attachment_url_for_api(true, :thumb)
      AttachmentDecorator.new(user.avatar).to_hash.merge(thumb_url: thumb_url)
    end

    def agents_leaderboard_key(category)
      GAMIFICATION_AGENTS_LEADERBOARD % { account_id: @account.id, category: category, month: @current_month }
    end

    def groups_leaderboard_key(category)
      GAMIFICATION_GROUPS_LEADERBOARD % { account_id: @account.id, category: category, month: @current_month }
    end

    def group_agents_leaderboard_key(category, group)
      GAMIFICATION_GROUP_AGENTS_LEADERBOARD % { account_id: @account.id, category: category, month: @current_month, group_id: group.id }
    end

    def clear_redis_data
      categories = CATEGORY_LIST.dup
      categories.insert(1, :love)
      categories.each do |category|
        redis_key = agents_leaderboard_key category.to_s
        $redis_others.perform_redis_op('del', redis_key)
      end
    end

    def clear_groups_redis_data
      categories = CATEGORY_LIST.dup
      categories.insert(1, :love)
      categories.each do |category|
        redis_key = groups_leaderboard_key category.to_s
        $redis_others.perform_redis_op('del', redis_key)
      end
    end

    def clear_group_agents_redis_data(*groups)
      groups.each do |group|
        categories = CATEGORY_LIST.dup
        categories.insert(1, :love)
        categories.each do |category|
          redis_key = group_agents_leaderboard_key category.to_s, group
          $redis_others.perform_redis_op('del', redis_key)
        end
      end
    end

    def create_group_agents
      @agent_one = add_test_agent(@account)
      @agent_two = add_test_agent(@account)
      @agent_three = add_test_agent(@account)
      @agent_four = add_test_agent(@account)
      @agent_five = add_test_agent(@account)
      @agent_six = add_test_agent(@account)
      group_names = @account.groups.pluck(:name)
      @group_odd = create_group_with_agents(@account, { agent_list: [@agent_one.id, @agent_three.id, @agent_five.id], name: group_names[0]})
      @group_even = create_group_with_agents(@account, { agent_list: [@agent_two.id, @agent_four.id, @agent_six.id], name: group_names[1]})
    end

    def redis_add_group_agents_score(score_stub, group_id, month = @current_month)
      key = "GAMIFICATION_GROUP_AGENTS_LEADERBOARD:1:mvp:#{month}:#{group_id}"
      score_stub.each do |stub|
        $redis_others.perform_redis_op('zadd', key, [stub[1], stub[0]])
      end
    end

    def redis_add_group_score(score_stub)
      key = "GAMIFICATION_GROUPS_LEADERBOARD:1:mvp:#{@current_month}"
      score_stub.each do |stub|
        $redis_others.perform_redis_op('zadd', key, [stub[1], stub[0]])
      end
    end

    def leaderboard_agent_pattern(score, agent_id)
      [
        { 'name' => 'mvp', 'id' => 1, 'rank_holders' => [] },
        { 'name' => 'love', 'id' => 2, 'rank_holders' => [] },
        { 'name' => 'sharpshooter', 'id' => 3, 'rank_holders' => [{ 'score' => score.to_f, 'id' => 'sharpshooter_1', 'rank' => 1, 'user_id' => agent_id, 'avatar' => nil }] },
        { 'name' => 'speed', 'id' => 4, 'rank_holders' => [] }
      ]
    end

    def empty_leaderboard_agent_pattern
      [
        { 'name' => 'mvp', 'id' => 1, 'rank_holders' => [] },
        { 'name' => 'love', 'id' => 2, 'rank_holders' => [] },
        { 'name' => 'sharpshooter', 'id' => 3, 'rank_holders' => [] },
        { 'name' => 'speed', 'id' => 4, 'rank_holders' => [] }
      ]
    end

    def leaderboard_group_pattern(group_scores)
      [
        {
          'name' => 'mvp', 'id' => 1, 'rank_holders' => group_scores.reverse.collect.with_index do |s, i|
            { 'score' => s[1].to_f, 'id' => ('mvp_' + (i + 1).to_s), 'rank' => (i + 1), 'group_id' => s[0], 'avatar' => nil }
          end
        },
        { 'name' => 'love', 'id' => 2, 'rank_holders' => [] },
        { 'name' => 'sharpshooter', 'id' => 3, 'rank_holders' => [] },
        { 'name' => 'speed', 'id' => 4, 'rank_holders' => [] }
      ]
    end

    def leaderboard_group_agents_pattern(group_agents_score)
      [
        {
          'name' => 'mvp', 'id' => 1, 'rank_holders' => group_agents_score.reverse.first(50).collect.with_index do |s, i|
            { 'score' => s[1].to_f, 'id' => 'mvp_' + (i + 1).to_s, 'rank' => i + 1, 'user_id' => s[0], 'avatar' => nil }
          end
        },
        { 'name' => 'love', 'id' => 2, 'rank_holders' => [] },
        { 'name' => 'sharpshooter', 'id' => 3, 'rank_holders' => [] },
        { 'name' => 'speed', 'id' => 4, 'rank_holders' => [] }
      ]
    end

    def previous_month
      (@current_month - 1) > 0 ? @current_month - 1 : 12
    end
end
