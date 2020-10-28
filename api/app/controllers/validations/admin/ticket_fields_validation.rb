module Admin
  class TicketFieldsValidation < ApiValidation
    include Admin::TicketFieldHelper
    include Admin::TicketFieldConstants
    include Admin::TicketFieldFsmHelper

    CHECK_PARAMS_SET_FIELDS = %i[portal_cc_to portal_cc label choices dependent_fields type required_for_agents
                                 section_mappings label_for_customers position required_for_closure
                                 required_for_customers customers_can_edit displayed_to_customers].freeze

    attr_accessor(*PERMITTED_PARAMS)
    attr_accessor :request_params, :tf, :include_rel, :include_rel_key, :portal_cc_to_set

    # requester field options validation
    validates :portal_cc, custom_inclusion: { in: [true, false] }, if: -> { tf.requester_field? && instance_variable_defined?(:@portal_cc) }, on: :update
    validates :portal_cc_to, data_type: { required: true, rules: String }, if: -> { tf.requester_field? && portal_cc.present? && !valid_portalcc_values? }, on: :update
    validates :portal_cc_to, custom_inclusion: { in: PORTAL_CC_TO_VALUES }, if: -> { tf.requester_field? && instance_variable_defined?(:@portal_cc_to) }, on: :update
    validates :portal_cc_to, custom_absence: { message: :invalid_field }, if: lambda {
      tf.requester_field? && instance_variable_defined?(:@portal_cc_to) &&
        ((portal_cc.blank? && tf.field_options['portalcc'].blank?) ||
        (portal_cc.blank? && instance_variable_defined?(:@portal_cc)))
    }, on: :update
    validates :portal_cc, :portal_cc_to, custom_absence: { message: :portal_and_cc_param_error }, if: -> { create_or_update? && !tf.requester_field? && portal_param? }

    # label validation
    validates :label, :label_for_customers, :type, :position, custom_absence: { message: :fsm_field_not_editable }, if: -> { tf.fsm? }, on: :update
    validates :label, :label_for_customers, :type, presence: true, on: :create
    validates :label, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING },
                      if: -> { create_or_update? && instance_variable_defined?(:@label) && !tf.default? }
    validates :label_for_customers, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING },
                                    if: -> { create_or_update? && instance_variable_defined?(:@label_for_customers) }
    validates :label, custom_absence: { message: :field_not_editable }, if: -> { tf.default? && instance_variable_defined?(:@label) }, on: :update

    # portal params validation
    validates :required_for_closure, :required_for_agents, :required_for_customers,
              :customers_can_edit, :displayed_to_customers,
              custom_inclusion: { in: [true, false] }, if: -> { create_or_update? }
    validates :displayed_to_customers, :customers_can_edit, custom_inclusion: { in: [true] },
                                                            if: -> { required_for_customers.present? && create_or_update? }
    validates :displayed_to_customers, custom_inclusion: { in: [true] }, if: -> { customers_can_edit.present? && create_or_update? }
    validates :required_for_closure, :required_for_agents, :required_for_customers, :customers_can_edit,
              :displayed_to_customers, custom_absence: { message: :fsm_field_not_editable },
                                       if: -> { tf.fsm? }, on: :update

    # ticket field position validation
    validates :position, data_type: { rules: Integer }, numericality: { greater_than: 0 },
                         if: -> { instance_variable_defined?(:@position) && !instance_variable_defined?(:@section_mappings) }
    validate :ticket_field_position_validation, if: -> { instance_variable_defined?(:@position) }

    # choices validation
    validates :choices, presence: true, if: -> { choices_required_for_type? }, on: :create
    validates :choices, data_type: { rules: Array }, if: lambda {
      create_or_update? && (choices_required_for_type? || status_field? || source_field?) && instance_variable_defined?(:@choices)
    }
    validates :choices, custom_absence: { message: :ticket_field_choice_condition }, if: lambda {
      create_or_update? && !choices_required_for_type? && instance_variable_defined?(:@choices) && !status_field? && !source_field?
    }
    validates :choices, custom_absence: { message: :sprout_plan_choices_error }, if: lambda {
      instance_variable_defined?(:@choices) && !Account.current.custom_ticket_fields_enabled? && !default_ticket_type? && !status_choice_update?
    }

    # nested field validation
    validates :dependent_fields, presence: true, if: -> { nested_field? }, on: :create
    validates :dependent_fields, data_type: { rules: Array, allow_blank: false },
                                 array: { data_type: { rules: Hash, allow_blank: false } },
                                 if: -> { create_or_update? && nested_field? && instance_variable_defined?(:@dependent_fields) }
    validates :dependent_fields, custom_absence: { message: :invalid_field },
                                 if: -> { !nested_field? && instance_variable_defined?(:@dependent_fields) }, on: :create

    validate :nested_level_param_validation, if: -> { create_or_update? && nested_field? && dependent_fields.present? }

    # section mapping validation
    validates :section_mappings, data_type: { rules: Array, allow_blank: false },
                                 if: -> { instance_variable_defined?(:@section_mappings) && create_or_update? }
    validate :section_mappings_params_validation, if: -> { section_mappings.present? && create_or_update? }

    # Archive ticket fields validation
    validates :archived, custom_inclusion: { in: [true, false] }, if: -> { instance_variable_defined?(:@archived) }, on: :update
    validate :archive_combined_with_other_params_validation, if: -> { instance_variable_defined?(:@archived) }, on: :update
    validate :archive_ticket_fields_feature?, if: -> { instance_variable_defined?(:@archived) }, on: :update
    validate :restrict_update_on_archived_fields, if: -> { tf.deleted? && !instance_variable_defined?(:@archived) }, on: :update
    validate :restrict_archive_param_on_tf_creation, if: -> { instance_variable_defined?(:@archived) }, on: :create

    validate :validate_params

    validate :multi_product_feature?, if: -> { not_index? && tf.present? && tf.product_field? }
    validate :dynamic_section?, if: -> { create_or_update? && instance_variable_defined?(:@section_mappings) }
    validate :multi_company_feature?, if: -> { not_index? && tf.present? && tf.company_field? }
    validate :fsm_field_check, if: -> { ((update_action? && instance_variable_defined?(:@archived)) || delete_action?) && tf.fsm? }
    validate :default_field_check, if: -> { ((update_action? && instance_variable_defined?(:@archived)) || delete_action?) && tf.default? } # need to handle for fsm too
    validate :custom_ticket_fields_feature?, if: -> { tf.present? && !tf.default? }
    validate :hipaa_encrypted_field?, if: -> { tf.present? && (tf.encrypted_field? || encrypted_field?) }
    validate :ticket_field_has_section?, if: -> { (update_action? && instance_variable_defined?(:@archived)) || delete_action? }
    validate :can_delete_nested_field?, if: -> { update_or_destroy? && tf.nested_field? }
    validate :validate_include, if: -> { include_rel_key.present? && show_or_index? }
    validate :ticket_field_job_progress_error, if: -> { update_or_destroy? && tf.update_in_progress?.present? }
    validates :type, custom_absence: { message: :field_type_error }, if: -> { instance_variable_defined?(:@type) }, on: :update
    validates :section_mappings, custom_absence: { message: :default_field_section_mapping_error },
                                 if: -> { instance_variable_defined?(:@section_mappings) && tf.present? && tf.default? }, on: :update
    validate :validate_fsm_params, if: -> { update_action? && tf.fsm? }
    validate :secure_fields_enabled?, if: -> { tf.present? && (tf.secure_field? || secure_field?) }

    def initialize(request_params, item, options)
      self.request_params = request_params
      self.tf = item
      PERMITTED_PARAMS.each do |param|
        safe_send("#{param}=", request_params[param]) if request_params.key?(param)
      end
      self.include_rel = request_params[:include]
      self.include_rel_key = request_params && request_params.key?(:include)
      super(request_params, nil, options) # sending model attribute as nil to avoid request param definition
    end

    private

      def validate_params
        return if errors.present?

        validate_type if instance_variable_defined?(:@type)
      end

      def validate_type
        valid_ticket_field_type = FIELD_TYPE_TO_COL_TYPE_MAPPING.stringify_keys.keys - SKIP_FSM_FIELD_TYPES
        unless type.in?(valid_ticket_field_type)
          invalid_data_type(:type, valid_ticket_field_type.join(', '), type)
          return
        end
      end

      def validate_include
        rel = include_rel.to_s.split(',')
        if include_rel.nil?
          errors[:include] << :datatype_mismatch
          error_options[:include] = { expected_data_type: :string }
        elsif (include_rel && rel.blank?) || ((rel & ALLOWED_FIELD_INSIDE_INCLUDE) != rel)
          errors[:include] << :not_included
          error_options[:include] = { list: ALLOWED_FIELD_INSIDE_INCLUDE.join(', ') }
        elsif rel.include?(:section)
          dynamic_section?
        end
      end

      def portal_param?
        instance_variable_defined?(:@portal_cc) ||
          instance_variable_defined?(:@portal_cc_to)
      end

      def valid_portalcc_values?
        tf.present? && PORTAL_CC_TO_VALUES.include?(tf.field_options['portalcc_to'])
      end
  end
end
