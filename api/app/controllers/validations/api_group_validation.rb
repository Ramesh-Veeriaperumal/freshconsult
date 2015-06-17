class ApiGroupValidation < ApiValidation
  include ActiveModel::Validations
  attr_accessor :name, :escalate_to, :assign_time, :ticket_assign_type, :agent_list
  attr_reader :error_options
  validates :name, presence: true
  validates :escalate_to, numericality: true, allow_nil: true
  validates :assign_time, numericality: true, allow_nil: true
  validates :ticket_assign_type, numericality: true, allow_nil: true
  validate :validate_agents_list

  def validate_agents_list
    @error_options = {}
    bad_agent_ids = []
    unless agent_list.nil?
      if agent_list.is_a?(String) && !agent_list.empty?
        agent_list.split(',').each do |agent_id|
          bad_agent_ids << agent_id if (agent_id =~ /\A[-+]?[0-9]+\z/).nil?
        end
        if bad_agent_ids.any?
          errors.add('agent_list', 'list is invalid')
          @error_options = { meta: "#{bad_agent_ids.join(', ')}" }
        end
      else
        errors.add('agent_list', 'invalid_field')
      end
    end
  end

  def initialize(request_params, item)
    super(request_params, item)
  end
end
