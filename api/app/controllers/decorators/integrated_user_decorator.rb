class IntegratedUserDecorator < ApiDecorator
  delegate :id, :installed_application_id, :user_id, :auth_info, :remote_user_id, to: :record

  def to_hash
    {
      id: id,
      installed_application_id: installed_application_id,
      user_id: user_id,
      auth_info: validate_auth_hash,
      remote_user_id: remote_user_id
    }
  end

  def validate_auth_hash
    return {} unless auth_info.present?
    auth_info.symbolize_keys.except(*Integrations::Constants::EXCLUDE_FROM_APP_CONFIGS_HASH)
  end
end
