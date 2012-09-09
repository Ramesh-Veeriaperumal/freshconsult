class Quest < ActiveRecord::Base
  include Gamification::Quests::Constants
  
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
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_ticket],
  }

  named_scope :forum_quests, :conditions => {
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_forum],
  }

  named_scope :solution_quests, :conditions => {
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_solution],
  }

  named_scope :survey_quests, :conditions => {
    :questtype => GAME_TYPE_KEYS_BY_TOKEN[:quest_survey],
  }

  def matches(evaluate_on) 
    return true unless filter_data
    return false unless evaluate_and_conditions(evaluate_on, filter_data[:and_filters])
    
    filter_data[:or_filters].each_pair do |k, v_arr|
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


  def time_condition(account)
    time_token = QUEST_TIME_BY_KEY[quest_data[0][:date].to_i]
    time_value = Chronic.parse(time_token + ' ago')
    return " helpdesk_ticket_states.resolved_at > '#{created_at.to_s(:db)}' " if time_value.blank?
    time_value = Time.parse(time_value.to_s).in_time_zone(account.time_zone)
    %( helpdesk_ticket_states.resolved_at > '#{time_value.to_s(:db)}' and 
      helpdesk_ticket_states.resolved_at > '#{created_at.to_s(:db)}' )
  end

  def has_custom_field_filters?(evaluate_on)
    filter_data[:actual_data].each do |f_h| 
      return true unless evaluate_on.respond_to?(f_h[:name]) 
    end
    
    false
  end

  def badge
    #badge_id
  end

  private

    def modify_quest_data
      [filter_data, quest_data].each {|d| symbolize_data(d)}
    end

    def symbolize_data(data)
      data.collect! {|d| d.symbolize_keys!} unless data.blank?
    end

    def denormalize_filter_data
      return unless filter_data
      
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
      RAILS_DEFAULT_LOGGER.debug %(INSIDE evaluate_and_conditions WITH 
                       conditions_arr :  #{condition_arr.inspect})

      condition_arr.each do |f|
        f_condition = Va::Condition.new(f, account)
        and_filter_conditions << f_condition
        return false unless f_condition.matches(evaluate_on)
      end
      RAILS_DEFAULT_LOGGER.debug %(INSIDE evaluate_and_conditions return : true)
      true
    end

    def evaluate_or_conditions(evaluate_on, condition_arr)
      return true if condition_arr.empty?
      RAILS_DEFAULT_LOGGER.debug %(INSIDE evaluate_or_conditions WITH 
                       conditions_arr :  #{condition_arr.inspect})

      to_ret = false
      condition_arr.each do |f|
        f_condition = Va::Condition.new(f, account)
        temp_ret = f_condition.matches(evaluate_on)
        process_hash_data(or_filter_conditions, f_condition, f_condition.key)
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

    #Singleton instance wrappers
    def and_filter_conditions
      @and_filter_conditions ||= []
    end

    def or_filter_conditions
      @or_filter_conditions ||= {}
    end

end
