class VARule < ActiveRecord::Base
  serialize :filter_data
  serialize :action_data
  
  validates_presence_of :name, :rule_type
  validates_uniqueness_of :name, :scope => [:account_id, :rule_type]
  validate :has_actions?
  
  attr_accessor :conditions, :actions
  
  belongs_to :account
  
  acts_as_list
  
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id} AND #{connection.quote_column_name("rule_type")} = #{rule_type}"
  end
  
  def after_find
    deserialize_them
  end
  
  def deserialize_them
    puts "******* filter_data #{filter_data.inspect} and #{filter_data.class}"
    @conditions = []
    filter_data.each do |f|
      f.symbolize_keys!
      @conditions << (Va::Condition.new(f, account_id))
    end unless !filter_data
    
    @actions = action_data.map { |act| deserialize_action act } unless !action_data
  end
  
  def deserialize_action(act_hash)
    act_hash.symbolize_keys!
    Va::Action.new(act_hash)
  end
  
  def pass_through(evaluate_on)
    RAILS_DEFAULT_LOGGER.debug "INSIDE pass_through WITH evaluate_on : #{evaluate_on.inspect} "
    is_a_match = matches(evaluate_on)
    trigger_actions(evaluate_on) if is_a_match    
    return evaluate_on if is_a_match
    return nil
  end
  
  def matches(evaluate_on)
    return true if conditions.empty?
    RAILS_DEFAULT_LOGGER.debug "INSIDE matches WITH conditions : #{conditions.inspect} "
    s_match = match_type.to_sym   
    to_ret = false
    conditions.each do |c|
      to_ret = c.matches(evaluate_on)
            
      return true if to_ret && (s_match == :any)
      return false if !to_ret && (s_match == :all) #by Shan temp
    end
    
    return to_ret
  end
  
  def trigger_actions(evaluate_on)
    puts "Trigger action called for #{name}"
    actions.each { |a| a.trigger(evaluate_on) }
  end
  
  private
    def has_actions?
      deserialize_them
      errors.add_to_base("Actions can't be empty") if(actions.nil? || actions.empty?)
    end
  
end
