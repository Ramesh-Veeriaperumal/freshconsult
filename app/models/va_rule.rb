class VARule < ActiveRecord::Base
  serialize :filter_data
  serialize :action_data
  
  attr_accessor :conditions, :actions
  
  def after_find
    deserialize_them
  end
  
  def deserialize_them
    @conditions = []
    filter_data.each do |f|
      f.symbolize_keys!
      @conditions << (Va::Condition.new(f))
    end
    
    @actions = action_data.map { |act| deserialize_action act }
  end
  
  def deserialize_action(act_hash)
    act_hash.symbolize_keys!
    Va::Action.new(act_hash)
  end
  
  def pass_through(evaluate_on)
    is_a_match = matches(evaluate_on)
    trigger_actions(evaluate_on) if is_a_match
    
    is_a_match
  end
  
  def matches(evaluate_on)
    return true if conditions.empty?
    
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
  end
  
end
