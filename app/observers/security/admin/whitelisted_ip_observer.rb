class Security::Admin::WhitelistedIpObserver < ActiveRecord::Observer

  observe WhitelistedIp

  include SecurityNotification
  
  def after_commit(whitelisted_ip)
    if whitelisted_ip.send(:transaction_include_action?, :create)
      commit_on_create(whitelisted_ip)
    elsif whitelisted_ip.send(:transaction_include_action?, :update)
      commit_on_update(whitelisted_ip)
    end
    true
  end

  def commit_on_create(whitelisted_ip)
    subject = "#{whitelisted_ip.account.name}: New IP restrictions have been added in your helpdesk"
    notify_admins(whitelisted_ip, subject, "trusted_ip_creation", whitelisted_ip.ip_ranges)
  end

  def commit_on_update(whitelisted_ip)
    if whitelisted_ip.previous_changes.keys.include?("ip_ranges") || whitelisted_ip.previous_changes.keys.include?("enabled")
      subject = "#{whitelisted_ip.account.name}: The IP restrictions in your helpdesk has been modified"
      notify_admins(whitelisted_ip, subject, "trusted_ip_update", whitelisted_ip.previous_changes["enabled"])
    end
  end

end
