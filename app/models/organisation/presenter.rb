class Organisation < ActiveRecord::Base
  include RepresentationHelper
  
  DATETIME_FIELDS = [:created_at, :updated_at]
  acts_as_api
  
  api_accessible :central_publish do |s|
    s.add :id
    s.add :organisation_id
    s.add :domain
    s.add :name
    s.add :alternate_domain
  end

  def model_changes_for_central(options = {})
    self.previous_changes
  end

  def central_publish_payload
    as_api_response(:central_publish)
  end

  def relationship_with_account
    'organisation'
  end
end
