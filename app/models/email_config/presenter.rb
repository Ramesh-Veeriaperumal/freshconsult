class EmailConfig < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at]

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id    
    g.add :account_id
    g.add :product_id
    g.add :to_email
    g.add :reply_email
    g.add :group_id
    g.add :primary_role
    g.add :active
    g.add :name
    g.add :category
    g.add :outgoing_email_domain_category_id
    DATETIME_FIELDS.each do |key|
      g.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end

  end
  
end