class Quest < ActiveRecord::Base
  include Gamification::Quests::Constants
  include Gamification::Scoreboard::Constants
  include Gamification::Quests::Badges
  
  belongs_to_account

  has_many :achieved_quests, :dependent => :destroy
  has_many :users, :through => :achieved_quests

  serialize :filter_data
  serialize :quest_data

  before_save :modify_quest_data, :denormalize_filter_data

  named_scope :available, lambda{|user| {
    :conditions => [%(quests.id not in (select quest_id from achieved_quests 
      where user_id = ? and account_id = ?)), user.id, user.account_id]
    }}

  named_scope :disabled, :conditions => { :active => false }
  named_scope :enabled, :conditions => { :active => true }

  named_scope :ticket_quests, :conditions => {
    :quest_type => GAME_TYPE_KEYS_BY_TOKEN[:ticket],
  }

  named_scope :forum_quests, :conditions => {
    :quest_type => GAME_TYPE_KEYS_BY_TOKEN[:forum],
  }

  named_scope :solution_quests, :conditions => {
    :quest_type => GAME_TYPE_KEYS_BY_TOKEN[:solution],
  }

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

    [ final_query_strings.compact.join(' and ') ] + query_params.flatten
  end


  def time_condition(end_time=Time.zone.now)
    time_column = QUEST_TIME_COLUMNS[GAME_TYPE_TOKENS_BY_KEY[quest_type]]
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
    achieved_quests.create(:user => user)
    user.support_scores.create({:score => points.to_i, 
          :score_trigger => QUEST_SCORE_TRIGGERS_BY_ID[quest_type]})
  end

  def revoke!(user)
    achieved_quests.find_by_user_id(user.id).delete
    user.support_scores.create({:score => -(points.to_i), 
          :score_trigger => QUEST_SCORE_TRIGGERS_BY_ID[quest_type]})
  end

  private

    def modify_quest_data
      [filter_data, quest_data].each {|d| symbolize_data(d)}
    end

    def symbolize_data(data)
      data.collect! {|d| d.symbolize_keys!} unless ( data.blank? or data.is_a? Hash)
    end

    def denormalize_filter_data
      return if (filter_data.blank? or filter_data.is_a? Hash)
      
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
      RAILS_DEFAULT_LOGGER.debug %(INSIDE evaluate_and_conditions return : true)
      true
    end

    def evaluate_or_conditions(evaluate_on, condition_arr)
      return true if condition_arr.empty?

      to_ret = false
      condition_arr.each do |f_condition|
        temp_ret = f_condition.matches(evaluate_on)
        to_ret = to_ret || temp_ret
      end
      RAILS_DEFAULT_LOGGER.debug %(INSIDE evaluate_or_conditions return : #{to_ret})
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

end
