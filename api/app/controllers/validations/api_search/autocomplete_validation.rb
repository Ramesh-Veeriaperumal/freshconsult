# frozen_string_literal: true

module ApiSearch
  class AutocompleteValidation < ApiValidation
    include ApiSearch::AutocompleteConstants

    attr_accessor(*AUTOCOMPLETE_PERMITTED_PARAMS)

    validates :name, data_type: { rules: String, allow_nil: false, required: true }, on: :companies
    validates :term, data_type: { rules: String, allow_nil: false, required: true }, on: :agents
    validates :all, data_type: { rules: 'Boolean', allow_nil: false }, on: :agents
    validates :context, :query, :search_key, :q, :v, :only, :include, data_type: { rules: String, allow_nil: false }, on: :agents
    validates :limit, :max_matches, :per_page, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param },
      if: -> { instance_variable_defined?(:@limit) || instance_variable_defined?(:@max_matches) || instance_variable_defined?(:@per_page) }, on: :agents
    validates :page, data_type: { rules: Integer, allow_nil: false }, on: :agents
    validate :validate_include_params, if: -> { instance_variable_defined?(:@include) }

    def initialize(request_params, _item, string_params)
      AUTOCOMPLETE_PERMITTED_PARAMS.each do |param|
        safe_send("#{param}=", request_params[param]) if request_params.key?(param)
      end
      super(request_params, nil, string_params)
    end

    def validate_include_params
      included_params = @include.split(',').map!(&:strip)
      return if (included_params - AGENT_AUTOCOMPLETE_INCLUDE_PARAMS).empty?

      errors[:include] << :not_included
      error_message = {}
      error_message[:include] = { list: AGENT_AUTOCOMPLETE_INCLUDE_PARAMS.join(', ') }
      error_options.merge!(error_message)
    end
  end
end
