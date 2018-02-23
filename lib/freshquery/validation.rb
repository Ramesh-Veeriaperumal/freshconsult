module Freshquery
  class Validation
    include ActiveModel::Validations
    include ActiveModel::Validations::Callbacks
    attr_accessor :request_params, :error_options, :mapping

    validates :request_params, "freshquery/fq": true

    def initialize(mapping, request_params)
      @error_options = {}
      @mapping = mapping
      @request_params = request_params
      set_instance_variables(request_params)
     end

    def set_instance_variables(request_params)
      request_params.each_pair do |key, value|
        self.class.safe_send(:attr_accessor, key)
        instance_variable_set("@#{key}", value)
      end
    end
  end
end
