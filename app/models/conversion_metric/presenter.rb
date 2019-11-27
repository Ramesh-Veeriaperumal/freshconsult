class ConversionMetric < ActiveRecord::Base
  include RepresentationHelper

  CONVERSATION_METRIC = 'conversion_metric'.freeze
  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add :account_id
    s.add :city_name
    s.add :region_name
    s.add :country
    s.add :zip_code
    s.add :first_referrer
    s.add :first_landing_url, as: :landing_url
    s.add :ga_client_id
    s.add :signup_method, as: :signup_type
    s.add :spam_score
    s.add :lead_source_choice
    s.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    s.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
  end

  def model_changes_for_central
    previous_changes
  end

  def central_publish_payload
    as_api_response(:central_publish)
  end

  def relationship_with_account
    CONVERSATION_METRIC
  end
end
