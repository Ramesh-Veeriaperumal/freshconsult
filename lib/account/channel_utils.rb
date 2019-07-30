module Account::ChannelUtils

  def toggle_forums_channel(toggle_value = true)
    if toggle_value
      features.forums.save
      add_feature(:forums)
    else
      features.forums.destroy
      revoke_feature(:forums)
    end
    # to prevent trusted ip middleware caching the association cache
    clear_association_cache
  end

  def toggle_social_channel(toggle_value = true)
    toggle_additional_settings_for_channel('social', toggle_value)
  end

  def toggle_phone_channel(toggle_value = true)
    toggle_additional_settings_for_channel('phone', toggle_value)
  end

  def toggle_chat_channel(toggle_value = true)
    toggle_additional_settings_for_channel('freshchat', toggle_value)
  end

  def toggle_additional_settings_for_channel(channel, toggle_value)
    additional_settings = account_additional_settings.additional_settings || {}
    additional_settings["enable_#{channel}".to_sym] = toggle_value
    account_additional_settings.additional_settings = additional_settings
    account_additional_settings.save
  end

  def enable_forums_channel
    toggle_forums_channel
  end

  def enable_social_channel
    toggle_social_channel
  end

  def phone_channel_enabled?
    (account_additional_settings.try(:additional_settings).try(:[], :enable_phone) == true)
  end

  def social_channel_enabled?
    (account_additional_settings.try(:additional_settings).try(:[], :enable_social) == true)
  end
end
