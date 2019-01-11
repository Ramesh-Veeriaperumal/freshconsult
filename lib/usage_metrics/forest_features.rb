module UsageMetrics::ForestFeatures
  include UsageMetrics::EstateFeatures

  def skill_based_round_robin(args)
    args[:account].groups_from_cache.any?(&:skill_based_round_robin_enabled?)
  end

  def mailbox(args)
    args[:account].imap_mailboxes.exists?
  end

  def whitelisted_ips(args)
    args[:account].whitelisted_ip.present?
  end

  def data_center_location(args)
    args[:shard].pod_info != PodConfig['GLOBAL_POD']
  end

  def sandbox(args)
    args[:account].sandbox_job.present? || args[:account]
      .account_additional_settings
      .additional_settings
      .try(:[], :sandbox)
      .try(:[], :status).present?
  end
end