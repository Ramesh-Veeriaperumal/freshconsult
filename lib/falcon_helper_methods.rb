module FalconHelperMethods
  include Cache::LocalCache

  def falcon_redirect_check(root_path)
    if current_account && current_account.falcon_ui_enabled?(current_user)
      "parent.location.href='#{root_path}'"
    else
      "window.location.href='#{root_path}'"
    end
  end

  def available_mint_locales
    @mint_langs ||= fetch_lcached_set(FALCON_ENABLED_LANGUAGES, 5.minutes)
  end

  def mint_locale_names
    @mint_langs_name ||= I18n.available_locales_with_name.select {|loc| available_mint_locales.include?(loc[1].to_s)}
  end

  def account_and_user_in_mint_langs?
    mint_langs = available_mint_locales
    mint_langs.include?(current_account.language) && current_user && mint_langs.include?(current_user.language)
  end

  def mint_locales_with_separator
    mint_locale_names + [["----------", {:disabled => true}], 
            ["Coming soon in your language", {:disabled => true}]]
  end

end