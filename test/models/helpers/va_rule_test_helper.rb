module VaRuleTestHelper

  def update_va_rule
    va_rule = Account.current.va_rules.first
    va_rule.name = Faker::Number.number(10)
    va_rule.save
  end

  def central_publish_post_pattern(va_rule)
    {
      id: va_rule.id,
      name: va_rule.name,
      description: va_rule.description,
      match_type: va_rule.match_type,
      filter_data: va_rule.filter_data,
      condition_data: va_rule.condition_data,
      action_data: va_rule.action_data,
      account_id: va_rule.account_id,
      rule_type: va_rule.rule_type,
      active: va_rule.active,
      position: va_rule.position,
      created_at: va_rule.created_at.try(:utc).try(:iso8601),
      updated_at: va_rule.updated_at.try(:utc).try(:iso8601)
    }
  end
end
