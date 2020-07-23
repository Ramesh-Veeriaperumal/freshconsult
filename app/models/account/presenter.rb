class Account < ActiveRecord::Base
  include RepresentationHelper
  include CentralLib::Util

  ACCOUNT_DESTROY = 'account_destroy'.freeze
  ACCOUNT_CREATE = 'account_create'.freeze
  ACCOUNT_UPDATE = 'account_update'.freeze

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
    s.add :set_portal_languages, as: :portal_languages
    s.add :set_all_languages, as: :all_languages
    s.add proc { |x| x.features_list }, as: :features
    s.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    s.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    s.add :freshid_account_id
    s.add proc { |x| x.fs_cookie }, as: :fs_cookie
    s.add proc { |x| x.account_configuration.account_configuration_for_central }, as: :account_configuration
    s.add :set_account_additional_settings, as: :account_additional_settings
    s.add proc { |x| x.account_additional_settings.rts_account_id }, as: :rts_account_id, if: proc { Account.current.agent_collision_revamp_enabled? }
    s.add proc { |x| x.encrypt_for_central(x.account_additional_settings.rts_account_secret, 'account_additional_settings') }, as: :rts_account_secret, if: proc { Account.current.agent_collision_revamp_enabled? }
    s.add proc { |x| x.encryption_key_name('account_additional_settings') }, as: :cipher_key, if: proc { Account.current.agent_collision_revamp_enabled? }
  end

  api_accessible :central_publish_associations do |t|
    t.add :subscription, template: :central_publish
    t.add :organisation, template: :central_publish
    t.add :conversion_metric, template: :central_publish
  end

  api_accessible :touchstone do |t|
    t.add :id, as: :freshdesk_account_id
    t.add :full_domain, as: :freshdesk_domain
    t.add :omni_bundle_id, as: :bundle_id
    t.add proc { |x| x.organisation.try(:organisation_id) }, as: :organisation_id
  end

  def model_changes_for_central(options = {})
    if @model_changes.present? && @model_changes.key?(:rts_account_secret)
      @model_changes[:rts_account_secret].map! { |x| EncryptorDecryptor.new(RTSConfig['db_cipher_key']).decrypt(x) if x.present? }
      @model_changes[:rts_account_secret].map! { |x| encrypt_for_central(x, 'account_additional_settings') if x.present? }
    end
    if @model_changes.present? && @model_changes.key?(:all_languages)
      all_languages_model_changes = { added: [], removed: [] }
      all_languages_model_changes[:added] = language_details(@model_changes[:all_languages][1] - @model_changes[:all_languages][0])
      all_languages_model_changes[:removed] = language_details(@model_changes[:all_languages][0] - @model_changes[:all_languages][1])
      @model_changes[:all_languages] = all_languages_model_changes
    end
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

  def set_portal_languages
    if self.account_additional_settings.present? && self.account_additional_settings.portal_languages.present?
      return self.account_additional_settings.portal_languages
    end
    []
  end

  def set_all_languages
    all_languages = if self.account_additional_settings.present? && self.account_additional_settings.supported_languages.present?
                      self.account_additional_settings.supported_languages + [self.main_portal.language]
                    else
                      [self.main_portal.language]
                    end
    language_details(all_languages)
  end

  def language_details(language_codes)
    language_codes.map { |code| Language.find_by_code(code).as_json }
  end

  def self.disallow_payload?(payload_type)
    return false if payload_type == ACCOUNT_DESTROY

    super
  end

  def set_account_additional_settings
    {}.tap do |settings|
      settings[:bundle_id] = omni_bundle_id
      settings[:bundle_name] = omni_bundle_name
    end
  end

  def bundle_info(payload_type)
    return {} unless [ACCOUNT_CREATE, ACCOUNT_UPDATE].include?(payload_type)

    {
      bundle: {
        type: omni_bundle_name
      }
    }
  end
end
