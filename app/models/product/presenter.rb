class Product < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at]


  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :name
    g.add :description
    g.add :account_id
    g.add proc { |x| x.portal.id unless x.portal.nil? }, as: :portal_id
    g.add proc { |x| x.email_configs.map(&:id) }, as: :email_config_ids
    DATETIME_FIELDS.each do |key|
      g.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end

  end

  api_accessible :central_publish_associations do |t|
    t.add :portal, template: :central_publish
    t.add :email_configs, template: :central_publish
  end

  # if anyone want to add product as association in other models please use this template instead whole central publish
  api_accessible :product_as_association do |g|
    g.add :id
    g.add :name
    g.add :account_id
    g.add proc { |x| x.portal.id unless x.portal.nil? }, as: :portal_id
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    'products'
  end
end