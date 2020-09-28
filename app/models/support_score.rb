class SupportScore < ActiveRecord::Base

  self.primary_key = :id
  include Gamification::Scoreboard::Constants
  include Redis::RedisKeys
  include Redis::SortedSetRedis
  include Redis::OthersRedis

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.update_agents_score; obj.update_redis_leaderboard }, on: :create
  after_commit ->(obj) { obj.update_agents_score; obj.update_redis_leaderboard }, on: :destroy
  belongs_to :user
  has_one :agent, :through => :user

  belongs_to :group

  belongs_to_account

  attr_protected  :account_id

  scope :created_at_inside, ->(start, stop) { 
    where(" support_scores.created_at >= ? and support_scores.created_at <= ?", start, stop)
  }

  scope :fast, -> { where(:score_trigger => FAST_RESOLUTION)}

  scope :first_call, -> { where(:score_trigger => FIRST_CALL_RESOLUTION) }

  scope :happy_customer, -> { where(:score_trigger => HAPPY_CUSTOMER ) }

  scope :unhappy_customer, -> { where( :score_trigger => UNHAPPY_CUSTOMER ) }

  scope :customer_champion, -> { where( :score_trigger => [HAPPY_CUSTOMER, UNHAPPY_CUSTOMER] ) }

  scope :by_performance, -> { where("score_trigger != ?", AGENT_LEVEL_UP) }

  scope :group_score, -> { select("support_scores.*, SUM(support_scores.score) as tot_score, MAX(support_scores.created_at) as recent_created_at").
      joins("INNER JOIN groups ON groups.id = support_scores.group_id and groups.account_id = support_scores.account_id").where("group_id is not null and groups.id is not null").
      group("group_id").order("tot_score desc, recent_created_at")
  }

  scope :user_score, ->(query){
    select(["support_scores.*, SUM(support_scores.score) as tot_score, MAX(support_scores.created_at) as recent_created_at"])
    .where(query[:conditions])
    .includes({ :user => [ :avatar ] })
    .group(:user_id)
    .order('tot_score desc, recent_created_at')
  }

  class << self
    alias_method :speed, :fast
    alias_method :sharpshooter, :first_call
    alias_method :love, :customer_champion

    # force index
    def force_index(index)
      from("#{self.table_name} FORCE INDEX(#{index})")
    end
  end

  def self.add_happy_customer(scorable)
    add_support_score(scorable, HAPPY_CUSTOMER)
  end

  def self.add_unhappy_customer(scorable)
    add_support_score(scorable, UNHAPPY_CUSTOMER)
  end

  def self.add_fcr_bonus_score(scorable)
    if (scorable.resolved_at  && scorable.ticket_states.inbound_count == 1)
      add_support_score(scorable, FIRST_CALL_RESOLUTION)
    end
  end

  def self.add_support_score(scorable, resolution_speed)
    sb_rating = scorable.account.scoreboard_ratings.find_by_resolution_speed(resolution_speed)
    scorable.support_scores.create({
      :user_id => scorable.responder_id,
      :group_id => scorable.group_id,
      :score => sb_rating.score,
      :score_trigger => sb_rating.resolution_speed
    }) if scorable.responder
  end

  def self.add_agent_levelup_score(scorable, score)
    scorable.support_scores.create({
      :user_id => scorable.id,
      :score => score,
      :score_trigger => AGENT_LEVEL_UP
    }) if scorable
  end

  def get_leader_ids account, board_category, category, end_of_search_time, result_count
    search_time = end_of_search_time.in_time_zone account.time_zone
    key = safe_send("#{board_category}_leaderboard_key", category, search_time.month)

    response = get_largest_members_of_sorted_set_redis key, result_count
    Rails.logger.debug("Inside memcache result #{account.inspect} #{key} #{category} result_count: #{result_count} response: #{response.inspect}")
    if response.blank?
      return MemcacheKeys.fetch(key, 3600) { store_leaderboard_in_redis key, account, board_category, category, search_time, result_count }
    else
      return response.first(result_count)
    end
  end

  def get_mini_list account, user, category, version = "v1"
    search_time = Time.use_zone(account.time_zone){ Time.now }
    key = safe_send("agents_leaderboard_key", category, search_time.month)
    # Find length of the list
    size = size_of_sorted_set_redis key

    if size == 0
      MemcacheKeys.fetch(key, 3600) { store_leaderboard_in_redis key, account, "agents", category, search_time }
    	size = size_of_sorted_set_redis key
    	return nil if size == 0
    end

    rank = get_rank_from_sorted_set_redis key, user.id
    return nil if (rank.nil? && version == "v1")

    leaderboard = get_mini_leaderboard rank, size, key, version

  end

  def get_mini_list_for_all_category account, user, category_list, version = "v1", with_current_user_position = true
    leaderboard_type = group_id.nil? ? 'agents' : 'group_agents'
    search_time = Time.now.in_time_zone account.time_zone
    redis_keys = get_leaderboard_redis_keys(category_list, leaderboard_type, search_time)
    # Find length of the list
    size = pipelined_size_of_sorted_set_redis redis_keys, category_list
    # Checking empty categories in db to cross check redis
    empty_category_in_redis = size.select { |category, count| count.zero? }
    # compute leaderboard from db if redis is empty
    populate_mini_list_from_db(empty_category_in_redis, redis_keys, size, leaderboard_type, search_time) if empty_category_in_redis.present?
    # Using size to determine if leaderboard exists or not for that category
    categories_with_leaderboard = category_list.reject { |category| size[category].zero? }
    return [] if categories_with_leaderboard.blank?
    rank = pipelined_get_rank_from_sorted_set_redis redis_keys, user.id, categories_with_leaderboard
    # return nil if (rank.nil? && version == "v1")
    get_mini_leaderboard_for_all_category rank, size, redis_keys, version, categories_with_leaderboard, with_current_user_position
  end


  def get_leaderboard_redis_keys(category_list, leaderboard_type, search_time)
    redis_keys = {}
    category_list.each do |category|
      redis_keys[category] = send("#{leaderboard_type}_leaderboard_key", category, search_time.month)
    end
    redis_keys
  end

  def populate_mini_list_from_db(empty_category_in_redis, redis_keys, size, leaderboard_type, search_time)
    empty_category_in_redis.keys.each do |category|
      key = redis_keys[category]
      MemcacheKeys.fetch(key, 3600) { store_leaderboard_in_redis key, account, leaderboard_type, category, search_time }
      category_size = size_of_sorted_set_redis key
      size[category] = category_size unless category_size.zero?
    end
  end

  def get_mini_leaderboard rank, size, key, version
    largest = get_largest_members_of_sorted_set_redis key
    return largest if (rank.nil? && version == "v2")
    list_size, indent = mini_list_size(version.to_sym)
    others = []
		start = rank - indent > 0 ? rank - indent : 1
		stop = start + list_size > size ? size : start + list_size
		start = stop == size ? (size - list_size > 0 ? size - list_size : 1) : start
		others = get_largest_members_of_sorted_set_redis key, stop, start
		others.each_with_index do |person, index|
			person << start+1+index
		end
		largest << others
		return largest
  end

  def get_mini_leaderboard_for_all_category(rank, size, redis_keys, version, category_list, with_current_user_position)
    # Getting the rank holder for each category
    largest = pipelined_get_largest_member_of_sorted_set_redis redis_keys, category_list
    # getting other ranked users only if current user has a rank
    user_ranked_category_list = category_list.reject { |category| rank[category].nil? }
    return largest if user_ranked_category_list.blank? || !with_current_user_position
    start, stop = get_mini_leaderboard_range(rank, size, version, user_ranked_category_list)

    others = pipelined_get_members_of_sorted_set_redis redis_keys, user_ranked_category_list, stop, start
    user_ranked_category_list.each do |category|
      others[category].each_with_index do |person, index|
        person << start[category] + 1 + index
      end
      largest[category] ||= {}
      largest[category][:others] = others[category]
    end
    largest
  end

  def get_mini_leaderboard_range(rank, size, version, category_list)
    list_size, indent = mini_list_size(version.to_sym)
    start = {}
    stop = {}
    category_list.each do |category|
      category_rank = rank[category]
      category_size = size[category]
      category_start = category_rank - indent > 0 ? category_rank - indent : 1
      category_stop = category_start + list_size > category_size ? category_size : category_start + list_size
      category_start = category_stop == category_size ? (category_size - list_size > 0 ? category_size - list_size : 1) : category_start
      start[category] = category_start
      stop[category] = category_stop
    end
    return start, stop
  end

  def agents_scoper account, start_time, end_time
    account.support_scores.by_performance.user_score({ :conditions => ["user_id is not null"] }).created_at_inside(start_time, end_time)
  end

  def groups_scoper account, start_time, end_time
    account.support_scores.by_performance.group_score.created_at_inside(start_time, end_time)
  end

  def group_agents_scoper account, start_time, end_time
    account.support_scores.by_performance.user_score({ :conditions => ["support_scores.group_id = ?", self.group_id] }).created_at_inside(start_time, end_time)
  end

protected

  def update_agents_score
    return if Thread.current[:gamification_reset]

    if Account.current.gamification_perf_enabled?
      # If the record is destroyed the score is to be subtracted from the agent's total
      # Else add the score to the total
      update_score = self.destroyed? ? -self.score : self.score
      agent.change_points(update_score)
    else
      # Continue with the old method for changing agent score
      acc = user.account
      args = { :id => user.id, :account_id => acc.id }
      Gamification::UpdateUserScore.perform_async(args)
    end
  end

  def update_redis_leaderboard
    return if self.score_trigger == AGENT_LEVEL_UP

    created_time = self.created_at.in_time_zone account.time_zone
    return if created_time.to_i < 3.months.ago(Time.now.in_time_zone(account.time_zone).beginning_of_month).to_i

    category_list = [ :mvp, SCORE_TRIGGER_VS_CATEGORY[self.score_trigger] ].compact
    value = self.destroyed? ? -self.score : self.score

    keys_to_be_updated = {}

    keys_to_be_updated["agents_leaderboard_key"] = { :member => self.user_id, :board => "agents" } if self.user_id
    keys_to_be_updated["groups_leaderboard_key"] = { :member => self.group_id, :board => "groups" } if self.group_id
    keys_to_be_updated["group_agents_leaderboard_key"] = { :member => self.user_id, :board => "group_agents" } if self.user_id && self.group_id

    keys_to_be_updated.each do |key, details|
      category_list.each do |category|
        redis_key = safe_send(key, category, created_time.month)
        if key_exists_sorted_set_redis redis_key
          incr_score_of_sorted_set_redis(redis_key, details[:member], value)
        else
          store_leaderboard_in_redis redis_key, account, details[:board], category, created_time
        end
      end
    end
  end

  def agents_leaderboard_key category, month
    GAMIFICATION_AGENTS_LEADERBOARD % { :account_id => self.account_id, :category => category, :month => month }
  end

  def groups_leaderboard_key category, month
    GAMIFICATION_GROUPS_LEADERBOARD % { :account_id => self.account_id, :category => category, :month => month }
  end

  def group_agents_leaderboard_key category, month
    GAMIFICATION_GROUP_AGENTS_LEADERBOARD % { :account_id => self.account_id, :category => category, :month => month, :group_id => self.group_id }
  end

  def store_leaderboard_in_redis key, account, board_category, category, end_time, result_count = nil
    result = category == :mvp ? safe_send("#{board_category}_scoper", account, end_time.beginning_of_month, end_time).all : safe_send("#{board_category}_scoper", account, end_time.beginning_of_month, end_time).safe_send(category).all
    Rails.logger.debug("Inside store_leaderboard_in_redis #{result.inspect}")
    if result.present?
      attribute = board_category == "groups" ? "group_id" : "user_id"
      leader_list = result.inject([]) {|list, item| list << [item.tot_score, item.safe_send(attribute)] }
       Rails.logger.debug("Inside store_leaderboard_in_redis #{leader_list.inspect}")
      multi_add_in_sorted_set_redis(key, leader_list, 3.months.from_now(end_time).end_of_month.to_i - end_time.to_i)

      return leader_list.first(result_count).collect{ |details| details.reverse } if result_count
    end
  end

  def mini_list_size version
    [MINI_LIST_SIZE[version][:size], MINI_LIST_SIZE[version][:indent]]
  end

end
