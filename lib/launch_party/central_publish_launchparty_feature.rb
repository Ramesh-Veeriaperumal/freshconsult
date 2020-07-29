# frozen_string_literal: true

require 'launch_party/launch_party_feature'

class CentralPublishLaunchpartyFeatures < LaunchPartyFeature
  CENTRAL_LP_FEATURE_LOG = 'CentralPublishLPFeatures :: Worker :: '
  def on_launch(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      Rails.logger.info "#{CENTRAL_LP_FEATURE_LOG} OnLaunch :: feature #{feature_name} :: publishing event"
      publish_account_central_payload(account, feature_name)
      Account.reset_current_account
    end
  end

  def on_rollback(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      Rails.logger.info "#{CENTRAL_LP_FEATURE_LOG} OnRollback :: feature #{feature_name} :: publishing event"
      publish_account_central_payload(account, feature_name)
      Account.reset_current_account
    end
  end

  private

    def publish_account_central_payload(account, feature_name)
      model_changes = construct_model_changes(feature_name)
      if model_changes.present?
        account.model_changes = model_changes
        account.manual_publish_to_central(nil, :update, nil, false)
      end
    end

    def construct_model_changes(feature_name)
      features = { features: { added: [], removed: [] } }
      if Account.current.launched?(feature_name)
        features[:features][:added] << feature_name.to_s
      else
        features[:features][:removed] << feature_name.to_s
      end
      features
    end
end
