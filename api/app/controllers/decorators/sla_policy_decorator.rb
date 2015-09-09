class SlaPolicyDecorator
  class << self
    def pluralize_conditions(input_hash)
      return_hash = {}
      input_hash.each { |key, value| return_hash[key.to_s.pluralize] = value } if input_hash
      return_hash
    end
  end
end
