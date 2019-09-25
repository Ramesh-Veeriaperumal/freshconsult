module Admin
  class TicketFieldsValidation < ApiValidation
    include Admin::TicketFieldHelper

    attr_accessor :tf

    validate :default_field_check, if: -> { tf.default? }, on: :destroy # need to handle for fsm too
    validate :custom_ticket_fields_feature?, unless: -> { tf.default? }
    validate :ticket_field_has_section?, on: :destroy
    validate :can_delete_nested_field?, if: -> { tf.nested_field? }, on: :destroy

    def initialize(request_params, item, options)
      self.tf = item
      super(request_params, item, options)
    end
  end
end
