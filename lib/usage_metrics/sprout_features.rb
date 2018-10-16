module UsageMetrics::SproutFeatures

  REQUESTER_NOTIFICATION_METRICS_COUNT = 3
  AGENT_NOTIFICATION_METRICS_COUNT = 3

  def canned_response(args)
    args[:account].canned_responses.exists?
  end

  def email_notification(args)
    agent_notification_count = 0
    requester_notification_count = 0
    args[:account].email_notifications.each do |email_notification|
      agent_notification_count += 1 if email_notification.agent_notification
      requester_notification_count += 1 if email_notification.requester_notification
      if requester_notification_count > REQUESTER_NOTIFICATION_METRICS_COUNT ||
        agent_notification_count > AGENT_NOTIFICATION_METRICS_COUNT
        return true
      end
    end
    false
  end

  def scenario_automations(args)
    args[:account].scn_automations.active.exists?
  end

  def tags(args)
    args[:account].tags.exists?
  end

  def knowledge_base(args)
    args[:account].solution_articles.visible.exists?
  end

  def omni_channel_support(args)
    args[:account].twitter_handles_from_cache.present? || 
      args[:account].facebook_pages.exists? || 
      args[:account].freshchat_account.present?
  end

  def installed_apps(args)
    args[:account].installed_applications.exists?
  end
end