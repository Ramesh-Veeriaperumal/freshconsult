class DowngradePolicyReminderMailer < ActionMailer::Base
  layout 'email_font'

  PLACEHOLDER_KEYS = {
    subject: {
      downgrade: {
        in_days: [2, 7]
      },
      cancel: {
        in_days: [4, 7],
        in_hours: [2, 3]
      }
    },
    content: {
      downgrade: {
        in_days: [4, 7],
        in_hours: [2, 3]
      },
      cancel: {
        in_days: [4, 7],
        in_hours: [2, 3]
      }
    }
  }.freeze

  def send_reminder_email(to_emails, subscription, remaining_days, reminder_type)
    @subscription = subscription
    @subscription_request = subscription.subscription_request
    @from_plan_name = construct_plan_name(subscription, Account.current.field_service_management_enabled?)
    @to_plan_name = construct_plan_name(subscription.subscription_request, subscription.subscription_request.fsm_enabled?)
    @email_body = construct_email_body(reminder_type, remaining_days)
    @days_left = remaining_days
    @other_emails = to_emails[:other]
    @headers = {
      from: AppConfig['from_email'],
      to: to_emails[:group],
      subject: construct_email_subject(reminder_type, remaining_days),
      sent_on: Time.zone.now
    }
    mail(@headers) do |part|
      part.text { render '/subscription_admin/subscriptions/downgrade_policy_reminder.text.plain.erb' }
      part.html { render '/subscription_admin/subscriptions/downgrade_policy_reminder.text.html.erb' }
    end.deliver
  end

  private

    def construct_email_body(reminder_type, remaining_days)
      placeholders = {
        domain: Account.current.full_domain,
        next_renewal_at: @subscription.next_renewal_at.strftime('%-d %b %Y'),
        current_plan: @from_plan_name,
        to_plan: @to_plan_name
      }
      construct_email_content_and_subject(reminder_type, remaining_days, :content, placeholders)
    end
      
    def construct_email_content_and_subject(reminder_type, remaining_days, section, placeholders = {})
      PLACEHOLDER_KEYS[section][reminder_type].each do |key, range|
        return safe_send(key, reminder_type, remaining_days, section, placeholders) if remaining_days.between?(*range)
      end
      I18n.t("downgrade_policy_#{section}.#{reminder_type}_final_message", placeholders)
    end

    def in_days(reminder_type, remaining_days, section, placeholders = {})
      in_days_content = (section == :content && @subscription_request.feature_loss?) ? "downgrade_policy_#{section}.#{reminder_type}_in_days_with_feature_loss" : "downgrade_policy_#{section}.#{reminder_type}_in_days"
      I18n.t(in_days_content, placeholders.merge!(days: remaining_days))
    end

    def in_hours(reminder_type, remaining_days, section, placeholders = {})
      in_hours_content = (section == :content && @subscription_request.feature_loss?) ? "downgrade_policy_#{section}.#{reminder_type}_in_hours_with_feature_loss" : "downgrade_policy_#{section}.#{reminder_type}_in_hours"
      I18n.t(in_hours_content, placeholders.merge!(hours: remaining_days * 24))
    end

    def construct_email_subject(reminder_type, remaining_days)
      construct_email_content_and_subject(reminder_type, remaining_days, :subject)
    end

    def construct_plan_name(subscription, fsm_enabled)
      omin_fsm_str = []
      subscription_plan = subscription.subscription_plan
      omin_fsm_str << I18n.t('downgrade_policy_content.omni_channel') if subscription_plan.omni_plan? || subscription_plan.free_omni_channel_plan?
      omin_fsm_str << I18n.t('downgrade_policy_content.fsm') if fsm_enabled
      plan_name = subscription.subscription_plan.classic? ? subscription_plan.display_name + ' Classic' : subscription_plan.display_name 
      plan_name << '(' + omin_fsm_str.join('+') + ')' if omin_fsm_str.present?
      plan_name
    end
end
