class Portal < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at]

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :name
    g.add :product_id
    g.add :account_id
    g.add :portal_url
    g.add :language
    g.add :main_portal
    g.add :ssl_enabled
    DATETIME_FIELDS.each do |key|
      g.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  api_accessible :central_publish_associations do |t|
    t.add :product, template: :product_as_association
  end

  api_accessible :central_publish_destroy do |br|
    br.add :id
    br.add :portal_url
    br.add :account_id
  end

  def relationship_with_account
    :portals
  end

   def model_changes_for_central
    @model_changes
  end
end
