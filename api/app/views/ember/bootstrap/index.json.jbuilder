json.agent do
  json.extract! @agent, "active_since", "available", "created_at", "id", "last_active_at", "occasional", "points", "scoreboard_level_id", "signature", "signature_html", "ticket_permission", "updated_at", "user_id", "user"

  json.assumable_agents @agent.assumable_agents.collect{|a| {name: a.name, id: a.id}}
  json.next_level @agent.send(:next_level)
  json.abilities @agent.user.abilities
  json.preferences @agent.preferences
  json.partial! 'shared/utc_date_format', item: @agent
  json.locale current_user.language
  json.time_zone @current_timezone
  json.avatar @avatar_hash
end
json.account do
  json.extract! current_account, "full_domain", "helpdesk_name", "name", "time_zone"
  json.date_format @data_date_format
  if current_user.privilege?(:manage_users) || current_user.privilege?(:manage_account)
    json.subscription do 
      json.extract! current_account.subscription, :agent_limit, :state, :addons
      json.subscription_plan current_account.subscription.subscription_plan.name
    end
  end
  json.settings do
    json.personalized_email_replies current_account.features.personalized_email_replies?
    json.componse_email_enabled current_account.compose_email_enabled?
    json.include_survey_manually @survey_in_specific_emails
  end
end
