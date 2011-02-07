class Va::Condition
  
  attr_accessor :handler, :key, :operator
  
  def initialize(rule, account_id)
    
    @key, @operator = rule[:name], rule[:operator] #by Shan hack must spelling mistake in criteria
   
    handler_class = VAConfig.handler @key.to_sym,account_id
    
    RAILS_DEFAULT_LOGGER.debug "The handler_class is : #{handler_class}"
    
    @handler = handler_class.constantize.new(self, rule)
    
  end
  
  def matches(evaluate_on)
    RAILS_DEFAULT_LOGGER.debug "conditions:: matches evaluate_on : #{evaluate_on.inspect}"
    handler.matches(evaluate_on)
  end
  
end
