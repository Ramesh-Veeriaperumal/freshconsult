# frozen_string_literal: true

module Admin
  class SecurityDelegator < BaseDelegator
    include Admin::SecurityConstants
    attr_accessor :record, :notification_emails, :agent_password_policy, :contact_password_policy
    validate :check_attributes_feature
    validate :check_notification_emails, if: -> { notification_emails.present? }
    validate :check_contact_password_policy, if: -> { contact_password_policy.present? }
    validate :check_agent_password_policy, if: -> { agent_password_policy.present? }
    def initialize(record, options)
      super(record, options)

      @record = record
      @notification_emails = options[:notification_emails]
      @agent_password_policy = options[:agent_password_policy]
      @contact_password_policy = options[:contact_password_policy]
      @error_options ||= {}
    end

    private

      def check_attributes_feature
        ATTRIBUTE_FEATURE_MAPPING.each_pair do |attr, features|
          next unless attribute_changed?(attr)

          missing_features = missing_features(features.try(:[], :enabled))
          unwanted_features = unwanted_features(features.try(:[], :disabled))
          if missing_features.present?
            add_error(:require_feature_for_attribute, feature: missing_features.join(','), attribute: attr)
          end
          if unwanted_features.present?
            add_error(:unwanted_feature_for_attribute, feature: unwanted_features.join(','), attribute: attr)
          end
        end
      end

      def check_notification_emails
        add_error(:not_included, list: 'account_managers emails', attribute: :notification_emails) if non_manager_emails.present?
        if emails_not_uniq?
          add_error(:duplicate_not_allowed, name: 'notification_emails', list: notification_emails.uniq.join(', '), attribute: :notification_emails)
        end
      end

      PasswordPolicy::USER_TYPE.keys.each do |value|
        attribute = "#{value}_password_policy"
        define_method "check_#{attribute}" do
          add_error(:action_restricted, action: 'password policies update', reason: 'when sso is enabled', attribute: attribute) if record.sso_enabled?
        end
      end

      def non_manager_emails
        notification_emails - Account.current.account_managers.map(&:email)
      end

      def emails_not_uniq?
        notification_emails.count > notification_emails.uniq.count
      end

      def attribute_changed?(model)
        record.try(model).try(:changed?)
      end

      def missing_features(features)
        features.select { |feature| !record.safe_send("#{feature}_enabled?") } if features.present?
      end

      def unwanted_features(features)
        features.select { |feature| record.safe_send("#{feature}_enabled?") } if features.present?
      end

      def add_error(error_key, options)
        attribute = options[:attribute]
        errors[attribute] << error_key
        (@error_options[attribute] ||= {}).merge!(options)
      end
  end
end
