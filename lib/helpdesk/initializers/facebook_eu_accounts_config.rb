module FacebookEuAccountsConfig
  account_ids = YAML.load_file(File.join(Rails.root, 'config', 'facebook_eu_accounts.yml'))[Rails.env][PodConfig["CURRENT_POD"]]
  ACCOUNT_IDS = account_ids.present? ? account_ids.freeze.to_set : [].to_set
end
