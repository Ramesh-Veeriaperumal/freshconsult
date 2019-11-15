module Admin
  class SkillValidation < ApiValidation
    include Admin::SkillConstants
    include Admin::ConditionFieldConstants
    include Admin::ConditionConstants
    include Admin::ConditionErrorHelper

    attr_accessor(*REQUEST_PERMITTED_PARAMS)
    attr_accessor :custom_field_hash, :field_position, :type_name

    validates :name, presence: true, data_type: { rules: String }, on: :create
    validates :name, data_type: { rules: String }, if: -> { name.present? }, on: :update
    validates :rank, data_type: { rules: Integer }, if: -> { rank.present? }, on: :update
    validates :agents, data_type: { rules: Array },
              array: { data_type: { rules: Hash }, hash: -> { { id: { data_type: { rules: Integer, presence: true } } } } }, if: -> { @request_params.key?(:agents) }
    validates :match_type, data_type: { rules: String }, custom_inclusion: { in: MATCH_TYPES }, if: -> { @request_params.key?(:match_type) }
    validates :conditions, data_type: { rules: Array }, array: { data_type: { rules: Hash } }, if: -> { @request_params.key?(:conditions) }

    validate :validate_position, if: -> { @request_params.key?(:rank) }
    validate :validate_agents, if: -> { @request_params.key?(:agents) }
    validate :validate_conditions, if: -> { @request_params.key?(:conditions) }

    def initialize(request_params, custom_fields_hash, agent_user_ids, item = nil, allow_string_param = false)
      REQUEST_PERMITTED_PARAMS.each { |param| safe_send("#{param}=", request_params[param]) }
      super(request_params, item, allow_string_param)
      @expected_agent_ids = agent_user_ids
      @request_params = request_params
      @custom_fields = custom_fields_hash
    end

    private

      def validate_position
        field_not_allowed('rank') and return unless @request_params[:action] == 'update'

        max_position = current_account.skills.size
        invalid_position_error('rank', max_position) if @rank > max_position
      end

      def validate_agents
        agent_ids = agents.map { |agent| agent[:id] }
        invalid_value_list('agents', agent_ids - @expected_agent_ids) unless agent_ids & @expected_agent_ids == agent_ids
      end

      def validate_conditions
        resource_types = conditions.map { |condition| condition[:resource_type] || 'ticket' }.map(&:to_sym)
        invalid_value_list('conditions[:resource_type]', resource_types - EVALUATE_ON_MAPPINGS_INVERT.keys) and
            return if (resource_types - EVALUATE_ON_MAPPINGS_INVERT.keys).present?

        EVALUATE_ON_MAPPINGS_INVERT.keys.each do |resource_type|
          grouped_conditions = conditions_by_resource_type(conditions, resource_type)
          next unless grouped_conditions

          all_fields = all_fields_hash(resource_type)
          conditions_validation = conditions_validation_class.new(grouped_conditions, CONDITION_FIELDS[resource_type],
                                                                  @custom_fields[resource_type], all_fields, :skill)
          unless conditions_validation.valid?
            merge_to_parent_errors(conditions_validation)
            error_options.merge! conditions_validation.error_options
          end
        end
      end

      def conditions_by_resource_type(conditions, resource_type)
        conditions.group_by { |cond| cond[:resource_type].try(:to_sym) || :ticket }[resource_type]
      end

      def all_fields_hash(resource_type)
        fields_hash = case resource_type
                      when :contact
                        CONDITION_CONTACT_FIELDS_HASH
                      when :company
                        CONDITION_COMPANY_FIELDS_HASH
                      else
                        CONDITION_TICKET_FIELDS_HASH
                      end
        fields_hash.select { |fh| CONDITION_FIELDS[resource_type].include? fh[:name]  } + @custom_fields[resource_type][1]
      end

      def conditions_validation_class
        'ConditionsValidation'.constantize
      end

      def current_account
        @current_account = Account.current
      end
  end
end