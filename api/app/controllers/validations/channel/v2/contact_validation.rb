module Channel::V2
  class ContactValidation < ::ContactValidation
    CHECK_PARAMS_SET_FIELDS += %w[created_at updated_at twitter_profile_status twitter_followers_count twitter_requester_handle_id].freeze
    attr_accessor :created_at, :updated_at, :deleted, :facebook_id,
                  :blocked, :blocked_at, :deleted_at, :whitelisted, :external_id,
                  :preferences, :parent_id, :crypted_password, :password_salt,
                  :last_login_at, :current_login_at, :history_column, :extn,
                  :last_login_ip, :current_login_ip, :login_count, :second_email,
                  :last_seen_at, :posts_count, :user_role, :delta, :privileges,
                  :failed_login_count, :twitter_profile_status, :twitter_followers_count, :twitter_requester_handle_id

    include TimestampsValidationConcern

    validates :import_id, :login_count, :failed_login_count, :parent_id, :posts_count,
              :user_role, :twitter_followers_count, numericality: { only_integer: true, greater_than_or_equal_to: 0,
                                                                    allow_nil: true, ignore_string: :allow_string_param }

    validates :facebook_id, :external_id, :crypted_password,
              :password_salt, :current_login_ip, :second_email, :last_login_ip, :privileges, :extn, :twitter_requester_handle_id,
              data_type: { rules: String,
                           allow_nil: true },
              custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

    validates :twitter_requester_handle_id, custom_absence:
                             { message: :require_feature_for_attribute,
                               code: :inaccessible_field,
                               message_options: {
                                 attribute: 'twitter_requester_handle_id',
                                 feature: :twitter_api_compliance
                               } },
                                            unless: :twitter_api_compliance_enabled?

    validates :blocked_at, :deleted_at, :last_login_at, :current_login_at,
              :last_seen_at, date_time: { allow_nil: true }

    validates :preferences, :history_column, data_type: { rules: Hash }, allow_nil: true

    validates :deleted, :blocked, :whitelisted, :delta, :twitter_profile_status, data_type: { rules: 'Boolean',
                                                                                              ignore_string: :allow_string_param,
                                                                                              allow_nil: true }

    def twitter_api_compliance_enabled?
      Account.current.twitter_api_compliance_enabled?
    end
  end
end
