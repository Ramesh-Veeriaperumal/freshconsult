class HelpWidget < ActiveRecord::Base

  acts_as_api

  api_accessible :s3_format do |t|
    t.add :id
    t.add :product_id
    t.add :account_id
    t.add :name
    t.add :widget_settings, as: :settings
    t.add :active
    t.add :created_at
    t.add :updated_at
    t.add :account_url
    t.add :languages
    t.add :date_format
  end

  def account_url
    "https://#{Account.current.full_domain}"
  end

  def languages
    {
      primary: Account.current.main_portal_from_cache.language,
      supported: Account.current.all_portal_languages
    }
  end

  def widget_settings
    settings[:appearance][:remove_freshworks_branding] = !Account.current.has_feature?(:branding)
    settings
  end

  def date_format
    Account.current.account_additional_settings_from_cache.date_format
  end
end
