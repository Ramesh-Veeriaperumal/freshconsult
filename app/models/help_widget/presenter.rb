class HelpWidget < ActiveRecord::Base

  acts_as_api

  api_accessible :s3_format do |t|
    t.add :id
    t.add :product_id
    t.add :account_id
    t.add :name
    t.add :settings
    t.add :active
    t.add :updated_at
    t.add :account_url
    t.add :language
    t.add :date_format
  end

  def account_url
    "https://#{Account.current.full_domain}"
  end

  def language
    product = Account.current.products_from_cache.detect { |p| product_id == p.id } if product_id
    portal = product && product.portal.present? ? product.portal : Account.current.main_portal_from_cache
    portal.language
  end

  def date_format
    Account.current.account_additional_settings.date_format
  end
  
end
