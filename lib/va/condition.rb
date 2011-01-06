class Va::Condition
  
  attr_accessor :handler, :key, :operator
  
  def initialize(rule)
    @key, @operator = rule[:critera], rule[:compare] #by Shan hack must spelling mistake in criteria
    handler_class = VAConfig.handler @key.to_sym
    @handler = handler_class.constantize.new(self, rule)
  end
  
  def matches(evaluate_on)
    handler.matches(evaluate_on)
  end
end
