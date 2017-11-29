module FalconHelperMethods
  def falcon_redirect_check(root_path)
    if current_account && current_account.falcon_ui_enabled?(current_user)
      "parent.location.href='#{root_path}'"
    else
      "window.location.href='#{root_path}'"
    end
  end

  def mint_supported_languages
    @mint_langs ||= $redis_others.perform_redis_op("smembers", "FALCON_ENABLED_LANGUAGES")
  end

  def account_and_user_in_mint_langs?
    mint_langs = mint_supported_languages
    mint_langs.include?(current_account.language) && current_user && mint_langs.include?(current_user.language)
  end

  def mint_languages_hash(alert=false)
    @mint_languages ||= I18n.available_locales_with_name.select {|loc| mint_supported_languages.include?(loc[1].to_s)}
    if alert
      @mint_languages.concat([["-----", {:disabled => true}], 
              ["Coming soon in your language", {:disabled => true}]])
    end
    @mint_languages
  end

end
