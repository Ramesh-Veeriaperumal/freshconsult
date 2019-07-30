module Dashboard::LeaderboardMethods
  include ApiLeaderboardConstants
  include Redis::RedisKeys
  include Redis::SortedSetRedis
  include MemcacheKeys

  def validate_params
    params.permit(*fields_to_validate, *ApiConstants::DEFAULT_PARAMS)
    leaderboard = LeaderboardValidation.new(params, nil, true)
    render_custom_errors(leaderboard, true) unless leaderboard.valid?(action_name.to_sym)
  end

  def set_root_key
    response.api_root_key = ROOT_KEY[action_name.to_sym]
  end

  def feature_name
    Account.current.gamification_enabled? ? :gamification_enable : :gamification
  end

  def fields_to_validate
    ApiLeaderboardConstants::LEADERBOARD_AGENTS_FIELDS
  end

  def mini_list(group_id, with_current_user_position = true)
    leaderboard = MemcacheKeys.fetch(leaderboard_widget_cache_key(group_id), 1.hour.to_i) do
      form_leaderboard(category_list, group_id, with_current_user_position)
    end
    @leaderboard = leaderboard || []
  end

  def mini_list_without_cache(group_id, with_current_user_position = true)
    form_leaderboard(category_list, group_id, with_current_user_position) || []
  end

  def leaderboard_widget_cache_key(group_id)
    group_id.present? ? group_agents_leaderboard_widget_cache_key(group_id) : account_leaderboard_widget_cache_key
  end

  def group_agents_leaderboard_widget_cache_key(group_id)
    GROUP_AGENTS_LEADERBOARD_MINILIST_REALTIME_FALCON % { account_id: Account.current.id, user_id: User.current.id, group_id: group_id }
  end

  def account_leaderboard_widget_cache_key
    LEADERBOARD_MINILIST_REALTIME_FALCON % { account_id: Account.current.id, user_id: User.current.id }
  end

  def form_leaderboard(category_list, group_id, with_current_user_position)
    support_score = SupportScore.new(group_id: group_id)
    mini_list = []
    mini_list_for_all_category = support_score.get_mini_list_for_all_category Account.current, User.current, category_list, 'v2', with_current_user_position
    users_hash = get_all_users(mini_list_for_all_category)
    mini_list_for_all_category.each do |category, leaderboard_minilist|
      form_category_hash(category, leaderboard_minilist, mini_list, users_hash)
    end
    mini_list
  end

  def get_all_users(mini_list_for_all_category)
    user_ids = []
    # collecting all user_ids so that a single query can be hit
    mini_list_for_all_category.each do |category, rank_types|
      # rank_types is either 'largest' or 'others'
      rank_types.each do |type, leader_list|
        user_ids += leader_list.map(&:first) if leader_list.present?
      end
    end
    users_objects = Account.current.technicians.includes(:avatar).where(id: user_ids.uniq)
    users_objects.each_with_object({}) { |user_object, users|
      users[user_object.id] = user_object
      users
    }
  end

  def form_category_hash(category, leaderboard_minilist, mini_list, users_hash)
    category_hash = {}
    user = users_hash[leaderboard_minilist[:largest].first.first.to_i]
    category_hash[:name] = category.to_s
    category_hash[:id]   = mini_list.length + 1
    leader_hash = leader_hash_object category, leaderboard_minilist[:largest].first.second, user
    category_hash[:rank_holders] = []
    category_hash[:rank_holders] << leader_hash
    leaderboard_agents = leaderboard_minilist[:others]
    other_rank_holders_objects leaderboard_agents, category_hash[:rank_holders], category, users_hash unless leaderboard_agents.nil?
    mini_list << category_hash
  end

  def other_rank_holders_objects(leaderboard_agents, category_rank_list, category, users_hash)
    leaderboard_agents.each do |leaderboard_agent|
      category_rank_list << {
        id: "#{category}_#{leaderboard_agent.last}",
        rank: leaderboard_agent.last,
        score: leaderboard_agent.second
      }.merge(user_id_avatar_hash(users_hash[leaderboard_agent.first.to_i]))
    end
  end

  def leader_hash_object(category, score, user)
    {
      id: "#{category}_1",
      rank: 1,
      score: score
    }.merge(user_id_avatar_hash(user))
  end

  def generate_leaderboard(group_id = nil)
    initialize_leaderboard(group_id)
    custom_range_selected = params[:date_range] == 'select_range' && params[:date_range_selected].present?
    custom_range_selected ? date_range_leaderboard : monthly_leaderboard
  end

  def initialize_leaderboard(group_id)
    @support_score = group_id && (group_id.to_i != 0) ? SupportScore.new(group_id: group_id) : SupportScore.new
    @leaderboard = []
    @group_action = params[:action] == 'groups'
    @module_association = @group_action ? 'groups' : 'all_users'
    @board_category = !@group_action && group_id && (group_id.to_i != 0) ? 'group_agents' : params[:action].to_s
  end

  def date_range_leaderboard
    date_range_selected = params[:date_range_selected]
    @start_time = get_time(date_range_selected.split(' - ')[0])
    @end_time = get_time(date_range_selected.split(' - ')[1]).end_of_day
    category_list.each_with_index do |category, ind|
      @leaderboard << category_score_for_custom_range(category, ind)
    end
     Rails.logger.debug("Result in date_range_leaderboard #{@leaderboard.inspect}")
  end

  def category_score_for_custom_range(category, ind)
    leader_module = @group_action ? 'group' : 'user'
    scoper = @support_score.safe_send("#{@board_category}_scoper", Account.current, @start_time, @end_time)
    scoper = scoper.includes(:group) if @group_action
    scoper_result = category == :mvp ? scoper.limit(50).all : scoper.safe_send(category).limit(50).all
    result = scoper_result.map { |ss| [ss.safe_send(leader_module).id, ss.tot_score] }
    Rails.logger.debug("Result in date_range_leaderboard #{category} #{ind} #{result.inspect}")
    category_hash(result, category, ind + 1)
  end

  def monthly_leaderboard
    current_time = Time.now.in_time_zone Account.current.time_zone
    category_list.each_with_index do |category, ind|
      leader_module_ids = months_ago_value ? @support_score.get_leader_ids(Account.current, @board_category, category, months_ago_value.month.ago(current_time.end_of_month), 50) : []
      Rails.logger.debug("In monthly_leaderboard :: #{leader_module_ids.inspect} :: #{category} :: #{months_ago_value}")
      @leaderboard << category_hash(leader_module_ids, category, ind + 1)
    end
    Rails.logger.debug("Result in monthly_leaderboard #{@leaderboard.inspect}")
  end

  def category_hash(res_array, category_name, category_id)
    category_hash = {
      id: category_id,
      name: category_name.to_s,
      rank_holders: []
    }
    Rails.logger.debug("Inside category_hash :: #{res_array} :: #{res_array.blank?} :: #{category_name} :: #{category_id}")
    category_hash[:rank_holders] = leader_module_rank_holders(res_array.to_a, category_name) unless res_array.blank?
    category_hash
  end

  def leader_module_rank_holders(leader_modules, category)
    module_scores = leader_module_scores(leader_modules)
    Rails.logger.debug("Inside leader_module_rank_holders :: #{leader_modules.inspect} :: #{module_scores.inspect} :: #{category}")
    rank_holders = []
    leader_modules.each_with_index do |leader_module, counter|
      leader_profile = leader_module_profile(module_scores[module_scores.map(&:id).index(leader_module[0].to_i)])
      Rails.logger.debug("Inside leader_module_rank_holders :: #{leader_profile}")
      rank_holders << rank_holder_hash(leader_module, category, counter + 1).merge(leader_profile)
    end
    Rails.logger.debug("Inside leader_module_rank_holders :: #{rank_holders.inspect}")
    rank_holders
  end

  def leader_module_scores(leader_modules)
    conditions = { id: leader_modules.map(&:first) }
    Rails.logger.debug("Inside leader_module_scores #{leader_modules.inspect} #{@module_association} :: #{conditions.inspect} ::  #{@group_action}")
    conditions.merge!({ helpdesk_agent: true, deleted: false }) unless @group_action
    result = Account.current.safe_send(@module_association).where(conditions).order("FIELD(id, #{conditions[:id]})")
    Rails.logger.debug("In leader_module_scores  #{result.inspect}")
    @group_action ? result : result.includes(:avatar)
  end

  def rank_holder_hash(leader_module, category, rank)
    {
      score: leader_module[1],
      id: "#{category}_#{rank}",
      rank: rank
    }
  end

  def category_list
    categories = CATEGORY_LIST.dup
    categories.insert(1, :love) if Account.current.any_survey_feature_enabled_and_active?
    categories
  end

  def leader_module_profile(leader_module)
    @module_association == 'groups' ? group_id_avatar_hash(leader_module) : user_id_avatar_hash(leader_module)
  end

  def group_id_avatar_hash(group)
    {
      group_id: group.id,
      avatar: nil
    }
  end

  def user_id_avatar_hash(user)
    {
      user_id: user.id,
      avatar: user.avatar ? user_avatar(user) : nil
    }
  end

  def user_avatar(user)
    AttachmentDecorator.new(user.avatar).to_hash
  end

  def get_time(time)
    Time.zone.parse(time.to_s)
  end

  def months_ago_value
    @date_range_val = params[:date_range] && params[:date_range] != 'select_range' ? params[:date_range] : 'current_month'

    range_vs_months = {
      '3_months_ago' => 3,
      '2_months_ago' => 2,
      'last_month' => 1,
      'current_month' => 0
    }
    range_vs_months[@date_range_val]
  end
end
