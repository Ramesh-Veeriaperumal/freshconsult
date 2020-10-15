module Silkroad
  module Export
    module FeatureCheck
      include Silkroad::Constants::Ticket
      include Redis::RedisKeys
      include Redis::SilkroadRedis

      def send_to_silkroad?(export_params)
        export_params = export_params.deep_symbolize_keys
        check_export_type(export_params) &&
          check_account_and_user_features &&
          check_ticket_fields(export_params[:ticket_fields]) &&
          check_filter_conditions(export_params[:data_hash]) &&
          check_contacts_and_company_fields(export_params[:contact_fields], export_params[:company_fields]) &&
          check_default_time_format
      end

      def check_export_type(export_params)
        !export_params.key?(:archived_tickets)
      end

      def check_account_and_user_features
        silkroad_enabled = account.launched?(:silkroad_export) || account.launched?(:silkroad_shadow)
        ticket_field_limit_increased = account.launched?(:ticket_field_limit_increase)
        silkroad_enabled && !ticket_field_limit_increased
      end

      def check_ticket_fields(ticket_fields)
        inactive_ticket_fields = get_inactive_silkroad_features(SILKROAD_TICKET_FIELDS).map(&:to_sym)
        current_ticket_fields = ticket_fields.keys
        (current_ticket_fields & inactive_ticket_fields).blank?
      end

      def check_filter_conditions(filter_conditions)
        inactive_filter_conditions = get_inactive_silkroad_features(SILKROAD_FILTER_CONDITIONS)
        inactive_fsm_fields = inactive_filter_conditions & FSM_FIELDS
        if inactive_fsm_fields.present?
          ff_names = filter_conditions.map { |filter_condition| filter_condition[:ff_name] }
          contains_fsm_fields = inactive_fsm_fields.any? { |fsm_field| ff_names.grep(/#{fsm_field}/).any? }
          return false if contains_fsm_fields
        end
        current_filter_conditions = filter_conditions.map { |filter_condition| filter_condition[:condition] }
        (current_filter_conditions & inactive_filter_conditions).blank?
      end

      def check_contacts_and_company_fields(contact_fields, company_fields)
        custom_contact_fields = (contact_fields.keys - CONTACT_FIELDS_COLUMN_NAME_MAPPING.keys)
        custom_company_fields = (company_fields.keys - COMPANY_FIELDS_COLUMN_NAME_MAPPING.keys)
        custom_contact_fields.blank? && custom_company_fields.blank?
      end

      def check_default_time_format
        account.account_additional_settings.date_format == 1
      end

      def account
        Account.current
      end

      def user
        User.current
      end
    end
  end
end
