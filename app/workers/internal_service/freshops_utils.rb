module InternalService::FreshopsUtils
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