class Admin::Groups::AgentsValidation < ApiValidation
  include UtilityHelper

  PERMITTED_PARAMS = [:agents].freeze
  PATCH_REQUEST_PARAMS = %w[id write_access deleted].freeze
  attr_accessor :request_params, :group, :agents

  validates :agents, data_type: { rules: Array }, array: { data_type: { rules: Hash },
                                                           hash: { id: { data_type: { rules: Integer, required: true } },
                                                                   deleted: { custom_inclusion: { in: [true, false] } },
                                                                   write_access: { custom_inclusion: { in: [true] } } } }, if: -> { validation_context == :update }

  validate :validate_agent_data, if: -> { validation_context == :update }

  def initialize(request_params, group, options)
    self.request_params = request_params
    self.group = group
    PERMITTED_PARAMS.each do |param|
      safe_send("#{param}=", request_params[param]) if request_params.key?(param)
    end
    super(request_params, nil, options)
  end

  def validate_agent_data
    agents.each_with_index do |agent_hash, index|
      agent_hash = deep_symbolize_keys(agent_hash)
      invalid_params = agent_hash.keys.map(&:to_s) - PATCH_REQUEST_PARAMS
      if invalid_params.present?
        errors["agents[#{index}]"] << :not_included
        error_options["agents[#{index}]"] = { list: PATCH_REQUEST_PARAMS.join(',') }
        break
      end
    end
  end
end
