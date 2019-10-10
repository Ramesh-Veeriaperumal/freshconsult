class DowngradePolicyReminderMailer < ActionMailer::Base
  include SubscriptionsHelper
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
    @email_body = construct_email_body(reminder_type, remaining_days, subscription)
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

    def construct_email_body(reminder_type, remaining_days, subscription)
      placeholders = {
        domain: Account.current.full_domain,
        next_renewal_at: subscription.next_renewal_at.strftime('%-d %b %Y'),
        current_plan: subscription.subscription_plan.display_name
      }
      days_count_placeholder_value(reminder_type, remaining_days, :content, placeholders)
    end
      
    def days_count_placeholder_value(reminder_type, remaining_days, section, placeholders = {})
      PLACEHOLDER_KEYS[section][reminder_type].each do |key, range|
        return safe_send(key, reminder_type, remaining_days, section, placeholders) if remaining_days.between?(*range)
      end
      I18n.t("downgrade_policy_#{section}.#{reminder_type}_final_message", placeholders)
    end

    def in_days(reminder_type, remaining_days, section, placeholders = {})
      I18n.t("downgrade_policy_#{section}.#{reminder_type}_in_days", placeholders.merge!(days: remaining_days))
    end

    def in_hours(reminder_type, remaining_days, section, placeholders = {})
      I18n.t("downgrade_policy_#{section}.#{reminder_type}_in_hours", placeholders.merge!(hours: remaining_days * 24))
    end

    def construct_email_subject(reminder_type, remaining_days)
      days_count_placeholder_value(reminder_type, remaining_days, :subject)
    end
end
