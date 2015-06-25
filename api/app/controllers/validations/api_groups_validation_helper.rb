class ApiGroupsValidationHelper
  class << self
    def agents_validator
      proc do |record, attr, value_array|
        bad_agents = []
        value_array.each do |value|
          bad_agents << value unless value.is_a?(Integer) && value >= 0
        end
        if bad_agents.any?
          record.errors.add attr, 'list is invalid'
          record.error_options = { meta: "#{bad_agents.join(', ')}" }
        end
      end
    end
  end
end
