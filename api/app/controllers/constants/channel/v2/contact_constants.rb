module Channel::V2::ContactConstants
  PROTECTED_FIELDS = %w[created_at updated_at deleted_at blocked blocked_at
                        whitelisted external_id crypted_password password_salt
                        last_login_at current_login_at posts_count user_role
                        last_login_ip current_login_ip login_count second_email
                        failed_login_count privileges extn history_column
                        last_seen_at delta].freeze

  CHANNEL_CREATE_FIELDS = CHANNEL_UPDATE_FIELDS = (ContactConstants::CONTACT_FIELDS + PROTECTED_FIELDS +
                            %w[deleted import_id facebook_id preferences parent_id twitter_profile_status twitter_followers_count]).freeze
end
