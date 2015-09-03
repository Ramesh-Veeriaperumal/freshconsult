class ApiSlaPoliciesDecorator < SimpleDelegator

  def pluralize_conditions
    return_hash = {}
    self.conditions.each { |key, value| return_hash[key.to_s.pluralize] = value } if self.conditions
    return_hash
  end
end