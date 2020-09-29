module FalconHelperMethods
  include Cache::LocalCache

  def falcon_redirect_check(root_path)
    "parent.location.href='#{root_path}'"
  end

  def mint_locale_names
    @mint_langs_name ||= I18n.available_locales_with_name
  end

  def account_and_user_in_mint_supported_langs?
    mint_langs = I18n.available_locales_with_name.collect{|loc| loc[1].to_s}
    mint_langs.include?(current_account.language) && current_user && mint_langs.include?(current_user.language)
  end

  def mint_locales_with_separator
    @locale_names ||= mint_locale_names + [["----------", {:disabled => true}], 
            ["Coming soon in your language", {:disabled => true}]]
  end

end