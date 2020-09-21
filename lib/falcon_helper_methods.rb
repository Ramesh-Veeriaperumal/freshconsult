module FalconHelperMethods
  include Cache::LocalCache

  def falcon_redirect_check(root_path)
    "parent.location.href='#{root_path}'"
  end

  def available_mint_locales
    @mint_langs ||= fetch_lcached_set(FALCON_ENABLED_LANGUAGES, 5.minutes)
  end

  def mint_locale_names
    @mint_langs_name ||= I18n.available_locales_with_name.select {|loc| available_mint_locales.include?(loc[1].to_s)}
  end

  def account_and_user_in_mint_supported_langs?
    mint_langs = available_mint_locales
    mint_langs.include?(current_account.language) && current_user && mint_langs.include?(current_user.language)
  end

  def mint_locales_with_separator
    @locale_names ||= mint_locale_names + [["----------", {:disabled => true}], 
            ["Coming soon in your language", {:disabled => true}]]
  end

end