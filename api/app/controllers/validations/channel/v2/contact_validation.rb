module Channel::V2
  class ContactValidation < ::ContactValidation
    CHECK_PARAMS_SET_FIELDS += %w[created_at updated_at].freeze
    attr_accessor :created_at, :updated_at, :deleted, :facebook_id,
                  :blocked, :blocked_at, :deleted_at, :whitelisted, :external_id,
                  :preferences, :parent_id, :crypted_password, :password_salt,
                  :last_login_at, :current_login_at, :history_column, :extn,
                  :last_login_ip, :current_login_ip, :login_count, :second_email,
                  :last_seen_at, :posts_count, :user_role, :delta, :privileges,
                  :failed_login_count

    include TimestampsValidationConcern

    validates :import_id, :login_count, :failed_login_count, :parent_id, :posts_count,
              :user_role, numericality: { only_integer: true, greater_than_or_equal_to: 0,
                                          allow_nil: true, ignore_string: :allow_string_param }

    validates :facebook_id, :external_id, :crypted_password,
              :password_salt, :current_login_ip, :second_email, :last_login_ip, :privileges, :extn,
              data_type: { rules: String,
                           allow_nil: true },
              custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }

    validates :blocked_at, :deleted_at, :last_login_at, :current_login_at,
              :last_seen_at, date_time: { allow_nil: true }

    validates :preferences, :history_column, data_type: { rules: Hash }, allow_nil: true

    validates :deleted, :blocked, :whitelisted, :delta, data_type: { rules: 'Boolean',
                                                                     ignore_string: :allow_string_param,
                                                                     allow_nil: true }
  end
end
