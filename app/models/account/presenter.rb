class Account < ActiveRecord::Base
  include RepresentationHelper

  ACCOUNT_DESTROY = 'account_destroy'.freeze

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
    s.add :freshid_account_id
    s.add proc { |x| x.fs_cookie }, as: :fs_cookie
    s.add proc { |x| x.anonymous_account? }, as: :anonymous_account
    s.add proc { |x| x.account_configuration.account_configuration_for_central }, as: :account_configuration
  end

  api_accessible :central_publish_associations do |t|
    t.add :subscription, template: :central_publish
    t.add :organisation, template: :central_publish
    t.add :conversion_metric, template: :central_publish
  end

  def model_changes_for_central(options = {})
    return @model_changes if @model_changes.present?
    changes = self.previous_changes
    changes = merge_feature_changes(changes)
    changes.delete(:shared_secret) if changes['shared_secret']
    changes
  end

  def merge_feature_changes(changes)
    if changes['plan_features']
      plan_feature = { features: { added: [], removed: [] } }
      FEATURES_DATA[:plan_features][:feature_list].each do |feature, value|
        old_feature_code = changes['plan_features'][0].to_i
        new_feature_code = changes['plan_features'][1].to_i
        unless ((old_feature_code ^ new_feature_code) & (2**value)).zero?
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

  def self.disallow_payload?(payload_type)
    return false if payload_type == ACCOUNT_DESTROY

    super
  end
end
