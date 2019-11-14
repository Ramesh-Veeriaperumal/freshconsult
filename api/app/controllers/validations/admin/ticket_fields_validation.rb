module Admin
  class TicketFieldsValidation < ApiValidation
    include Admin::TicketFieldHelper
    include Admin::TicketFieldConstants

    attr_accessor :tf, :include_rel, :include_rel_key

    validate :multi_product_feature?, if: -> { not_index? && tf.present? && tf.product_field? }
    validate :multi_company_feature?, if: -> { not_index? && tf.present? && tf.company_field? }
    validate :default_field_check, if: -> { tf.default? }, on: :destroy # need to handle for fsm too
    validate :custom_ticket_fields_feature?, if: -> { tf.present? && !tf.default? }
    validate :ticket_field_has_section?, on: :destroy
    validate :can_delete_nested_field?, if: -> { tf.nested_field? }, on: :destroy
    validate :validate_include, if: -> { include_rel_key.present? && show_or_index? }

    def initialize(request_params, item, options)
      self.tf = item
      self.include_rel = request_params[:include]
      self.include_rel_key = request_params && request_params.key?(:include)
      super(request_params, item, options)
    end

    private

      def validate_include
        rel = include_rel.to_s.split(',')
        if include_rel.nil?
          errors[:include] << :datatype_mismatch
          error_options[:include] = { expected_data_type: :string }
        elsif (include_rel && rel.blank?) || ((rel & ALLOWED_FIELD_INSIDE_INCLUDE) != rel)
          errors[:include] << :not_included
          error_options[:include] = { list: ALLOWED_FIELD_INSIDE_INCLUDE.join(', ') }
        elsif rel.include?(:section)
          (tf.default? && dynamic_section?) || (!tf.default && multi_dynamic_section?)
        end
      end
  end
end
