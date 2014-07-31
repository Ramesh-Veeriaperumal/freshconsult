class Quest < ActiveRecord::Base
  include Gamification::Quests::Constants
  include Gamification::Scoreboard::Constants
  include Gamification::Quests::Badges
  include Cache::Memcache::Quest
  
  attr_accessible :category, :badge_id, :points, :name, :description
  belongs_to_account

  has_many :achieved_quests, :dependent => :destroy
  has_many :users, :through => :achieved_quests
  has_many :support_scores, :as => :scorable, :dependent => :nullify

  validates_presence_of :name
  validates_presence_of :badge_id, :message => I18n.t('quests.badge_mand')
  validates_numericality_of :points

  serialize :filter_data
  serialize :quest_data

  validate :has_quest_data_value?

  before_create :set_active

  before_save :modify_quest_data, :denormalize_filter_data

  after_commit :clear_quests_cache, on: [:create, :update, :destroy]

  scope :available, lambda{|user| {
    :conditions => [%(quests.id not in (select quest_id from achieved_quests 
      where user_id = ? and account_id = ?)), user.id, user.account_id]
    }}

  scope :disabled, :conditions => { :active => false }
  scope :enabled, :conditions => { :active => true }

  scope :ticket_quests, :conditions => {
    :category => GAME_TYPE_KEYS_BY_TOKEN[:ticket],
  }

  scope :forum_quests, :conditions => {
    :category => GAME_TYPE_KEYS_BY_TOKEN[:forum],
  }

  scope :solution_quests, :conditions => {
    :category => GAME_TYPE_KEYS_BY_TOKEN[:solution],
  }

  scope :create_forum_quests, :conditions => {
    :category => GAME_TYPE_KEYS_BY_TOKEN[:forum],
    :sub_category => FORUM_QUEST_MODE_BY_TOKEN[:create]
  }

  scope :answer_forum_quests, :conditions => {
    :category => GAME_TYPE_KEYS_BY_TOKEN[:forum],
    :sub_category => FORUM_QUEST_MODE_BY_TOKEN[:answer]
  }
  
  def achieved_by?(user)
    !achieved_quests.find_by_user_id(user.id).nil?
  end

  def matches(evaluate_on) 
    return true unless filter_data
    return false unless evaluate_and_conditions(evaluate_on, and_filter_conditions)
    
    or_filter_conditions.each_pair do |k, v_arr|
      return false unless evaluate_or_conditions(evaluate_on, v_arr)
    end
    
    true
  end

  def filter_query
    final_query_strings = []
    
    query_params = construct_query_strings(and_filter_conditions, ' and ')
    final_query_strings << query_params.shift

    or_filter_conditions.each_pair do |k, v_arr|
      or_querystrings = construct_query_strings(v_arr, ' or ')
      final_query_strings << or_querystrings.shift
      query_params << or_querystrings
    end
    return [] if final_query_strings.compact.blank?
    [ final_query_strings.compact.join(' and ') ] + query_params.flatten
  end


  def time_condition(end_time=Time.zone.now)
    return " #{time_column} >= '#{created_at.to_s(:db)}' " if any_time_span?
    %( (#{time_column} >= '#{start_time(end_time).to_s(:db)}' and 
       #{time_column} <= '#{end_time.to_s(:db)}') and
       #{time_column} >= '#{created_at.to_s(:db)}' )
  end

  def has_custom_field_filters?(evaluate_on)
    filter_data[:actual_data].each do |f_h| 
      return true unless evaluate_on.respond_to?(f_h[:name]) 
    end
    
    false
  end

  def badge
    BADGES_BY_ID[badge_id]
  end

  def time_span
    QUEST_TIME_SPAN_BY_KEY[quest_data[0][:date].to_i]
  end

  def any_time_span?
    quest_data[0][:date].to_i == 1
  end

  def start_time(end_time=Time.zone.now)
    end_time - time_span
  end

  def award!(user)
    return unless user.achieved_quest(self).nil?
    achieved_quests.create(:user => user, :account => account)
    support_scores.create({:score => points.to_i,
          :user => user,
          :score_trigger => QUEST_SCORE_TRIGGERS_BY_ID[category],
          :account => account})
    clear_quests_cache_for_user(user)
  end

  def revoke!(user)
    user_ach_quest = user.achieved_quest(self)
    return if user_ach_quest.nil?
    user_ach_quest.delete
    support_scores.create({:score => -(points.to_i),
          :user => user,
          :score_trigger => QUEST_SCORE_TRIGGERS_BY_ID[category],
          :account => account})
    clear_quests_cache_for_user(user)
  end

  def time_column
    return 'topics.created_at' if create_forum_quest?
    return 'posts.created_at' if answer_forum_quest?
    QUEST_TIME_COLUMNS[GAME_TYPE_TOKENS_BY_KEY[category]]
  end

  def actual_filter_data
    return filter_data[:actual_data]  if filter_data.is_a? Hash
    filter_data
  end

  private


    def modify_quest_data
      [filter_data, quest_data].each {|d| symbolize_data(d)}
    end

    def set_active
      self.active = true
    end

    def symbolize_data(data)
      data.collect! {|d| d.symbolize_keys!} unless ( data.blank? or data.is_a? Hash)
    end

    def denormalize_filter_data
      return if filter_data.is_a? Hash
      if filter_data.blank?
        self.filter_data = {:actual_data => [], :and_filters => [], :or_filters => {}}
        return
      end
      
      f_data_hash = { :actual_data => filter_data }
      filters_hash = process_filter_data

      and_filters = []
      filters_hash.each_pair { |k,v| and_filters << filters_hash.delete(k) if v.is_a? Hash}
      f_data_hash[:and_filters] = and_filters
      f_data_hash[:or_filters] = filters_hash
      self.filter_data = f_data_hash
    end

    def process_filter_data
      filter_data.inject({}) do |result, element|
        key = element[:name]
        process_hash_data(result, element, key)
      end
    end

    def process_hash_data(result_hash, element, key)
      if(result_hash.key?(key))
        arr_val = [result_hash[key]]
        arr_val << element
        result_hash[key] = arr_val.flatten
      else
        result_hash[key] = element
      end

      result_hash
    end

    def evaluate_and_conditions(evaluate_on, condition_arr)
      return true if condition_arr.empty?

      condition_arr.each do |f_condition|
        return false unless f_condition.matches(evaluate_on)
      end
      Rails.logger.debug %(INSIDE evaluate_and_conditions return : true)
      true
    end

    def evaluate_or_conditions(evaluate_on, condition_arr)
      return true if condition_arr.empty?

      to_ret = false
      condition_arr.each do |f_condition|
        temp_ret = f_condition.matches(evaluate_on)
        to_ret = to_ret || temp_ret
      end
      Rails.logger.debug %(INSIDE evaluate_or_conditions return : #{to_ret})
      to_ret
    end

    def construct_query_strings(conditions_arr, join_operator)
      query_strings = []
      params = []
      conditions_arr.each do |c|
        c_query = c.filter_query
        query_strings << c_query.shift
        params = params + c_query
      end

      query_strings.empty? ? [] : 
        ([ '(' + query_strings.join( join_operator ) + ')'] + params)
    end

    def and_filter_conditions
      @and_filter_conditions ||= populate_and_filters
    end

    def or_filter_conditions
      @or_filter_conditions ||= populate_or_filters
    end

    def populate_and_filters
      return [] if filter_data[:and_filters].empty?

      filter_data[:and_filters].map do |f|
        Va::Condition.new(f, account)
      end
    end

    def populate_or_filters
      return {} if filter_data[:or_filters].empty?

      to_ret = {}
      filter_data[:or_filters].each_pair do |k, conditions_arr|
        conditions_arr.each do |f|
          f_condition = Va::Condition.new(f, account)
          process_hash_data(to_ret, f_condition, f_condition.key)
        end
      end

      to_ret
    end

    def has_quest_data_value?
      return false if quest_data.blank?
      quest_data.first.symbolize_keys!
      if quest_data.first[:value].blank? || (quest_data.first[:value].to_i == 0)
        errors.add(:base,I18n.t("quests.#{GAME_TYPE_TOKENS_BY_KEY[category].to_s}_mand")) 
      end
    end

    # forum quest related methods
    def forum_quest?
      category == GAME_TYPE_KEYS_BY_TOKEN[:forum]
    end

    def create_forum_quest?
      forum_quest? and sub_category == FORUM_QUEST_MODE_BY_TOKEN[:create]
    end

    def answer_forum_quest?
      forum_quest? and sub_category == FORUM_QUEST_MODE_BY_TOKEN[:answer]
    end

end
