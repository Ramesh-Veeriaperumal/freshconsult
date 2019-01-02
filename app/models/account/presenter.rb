class Account < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api
  
  api_accessible :central_publish do |s|
    s.add :id
    s.add :name
    s.add :full_domain
    s.add :time_zone
    s.add :helpdesk_name
    s.add :sso_enabled
    s.add :sso_options
    s.add :ssl_enabled
    s.add :reputation
    s.add :account_type_hash, as: :account_type
    s.add :premium
    s.add proc { |x| x.features_list }, as: :features
    s.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    s.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish_associations do |t|
    t.add :subscription, template: :central_publish
  end

  def model_changes_for_central(options = {})
    return @model_changes if @model_changes.present?
    changes = self.previous_changes
    if changes['plan_features']
      plan_feature = { features: { added: [], removed: [] } }
      FEATURES_DATA[:plan_features][:feature_list].each do |feature, value|
        if changes['plan_features'][1].to_i == changes['plan_features'][0].to_i ^ 2**value
          if self.has_feature?(feature)
            plan_feature[:features][:added] << feature.to_s
          else
            plan_feature[:features][:removed] << feature.to_s
          end
        end
      end
      changes.delete('plan_features')
      changes = changes.merge(plan_feature)
    end
    changes.delete(:shared_secret) if changes['shared_secret']
    changes
  end

  def central_publish_payload
    as_api_response(:central_publish)
  end

  def account_type_hash
    { 
      id: account_type, 
      name: ACCOUNT_TYPES.key(account_type)
    }
  end

end
