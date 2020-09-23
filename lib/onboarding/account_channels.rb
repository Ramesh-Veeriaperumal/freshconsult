module Onboarding::AccountChannels

  def toggle_forums_channel enable=true
    enable ? current_account.features.forums.save : current_account.features.forums.destroy
    #to prevent trusted ip middleware caching the association cache
    current_account.clear_association_cache
  end

  def toggle_social_channel enable=true
    account_additional_settings = current_account.account_additional_settings
    if account_additional_settings.additional_settings.present?
      account_additional_settings.additional_settings[:enable_social] = enable
    else
      additional_settings = {
        :enable_social => enable
      }
    account_additional_settings.additional_settings = additional_settings
    end
    account_additional_settings.save
  end
end
