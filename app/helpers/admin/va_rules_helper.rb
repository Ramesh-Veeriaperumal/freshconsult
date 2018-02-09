module Admin::VaRulesHelper
  def event_placeholders
    {:events => [['{{triggered_event}}', t('placeholder.triggered_event'), t('placeholder.tooltip.triggered_event'), 'triggered_event']]}
  end

  def va_rule_checkbox_options va_rule
      contains_restricted_email_action?(va_rule) ? {:class => 'activate', :disabled => true} : {:class => 'activate'}
    end

    def va_rule_link_options va_rule
      contains_restricted_email_action?(va_rule) ? {:class => 'item_info disabled'} : {:class => 'item_info'}
    end

    def contains_restricted_email_action? va_rule
      !Account.current.verified? && va_rule.any_restricted_actions?
    end
end