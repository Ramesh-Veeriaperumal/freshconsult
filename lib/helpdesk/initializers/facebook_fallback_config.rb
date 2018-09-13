module FacebookFallbackConfig
  account_ids = YAML.load_file(File.join(Rails.root, 'config', 'facebook_fallback_accounts.yml'))[Rails.env][PodConfig['CURRENT_POD']]
  euc_account_ids = YAML.load_file(File.join(Rails.root, 'config', 'facebook_euc_accounts.yml'))

  ACCOUNT_IDS = account_ids.present? ? account_ids.freeze.to_set : [].to_set
  EUC_ACCOUNT_IDS = euc_account_ids.present? ? euc_account_ids.freeze.to_set : [].to_set
end
