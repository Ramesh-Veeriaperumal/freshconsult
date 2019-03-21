module InternalService::FreshopsUtils
  def invoke_enable_old_ui
    Rails.logger.info('Old UI enable start')
    @account.technicians.find_each do |user|
      begin
        user.make_current
        unless user.text_uc01.try(:[], :agent_preferences).try(:[], :falcon_ui)
          user.merge_preferences = { agent_preferences: { falcon_ui: true } }
          user.save!
        end
      rescue StandardError => e
        Rails.logger.info("Exception invoke_enable_old_ui ::: #{e.inspect} -- #{user.id}")
      end
      User.reset_current_user
    end
    @account.revoke_feature(:disable_old_ui)
    Rails.logger.info("Old UI enabled for account #{@account.full_domain} -- #{@account.id}")
  end

  def export_daypass_usage(mon_duration, to_email)
    Rails.logger.info('export_daypass_usage start')
    csv_string = CSVBridge.generate do |csv|
      csv << [ "Email", "Granted on"]
      @account.day_pass_usages.where("created_at > ?", max_limit(mon_duration).months.ago).preload(:user).find_each do |usage|
        if usage.user
          csv << [ usage.user.email, usage.granted_on.strftime("%d %B %Y") ]
        else
          csv << [ usage, usage.granted_on.strftime("%d %B %Y") ]
        end
      end
    end
    FreshopsMailer.send_daypass_usage_export(to_email, csv_string)
  end

  def max_limit(last_n_months)
    last_n_months.to_i > 60 ? 60 : last_n_months.to_i
  end
end