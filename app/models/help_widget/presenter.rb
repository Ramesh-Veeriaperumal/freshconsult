class HelpWidget < ActiveRecord::Base
  include RepresentationHelper

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

  api_accessible :central_publish do |f|
    f.add :id
    f.add :name
    f.add :active
    f.add :product_id
    f.add :account_id
  end

  api_accessible :central_publish_destroy do |cf|
    cf.add :id
    cf.add :account_id
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
    settings[:appearance][:remove_freshworks_branding] = !Account.current.branding_enabled?
    settings
  end

  def date_format
    Account.current.account_additional_settings_from_cache.date_format
  end

  def relationship_with_account
    :help_widgets
  end
end
