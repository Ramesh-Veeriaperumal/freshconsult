require_relative '../unit_test_helper'

class ApiEmailConfigsDependencyTest < ActionView::TestCase
  def test_before_filters_application_controller
    expected_filters = [:determine_pod, :supress_logs, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account,
                        :unset_current_portal, :unset_shard_for_payload, :set_current_account, :set_current_ip, :reset_language, :set_shard_for_payload,
                        :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params,
                        :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language,
                        :set_affiliate_cookie, :verify_authenticity_token, :set_selected_tab, :build_object,
                        :unset_thread_variables, :load_object, :ensure_proper_sts_header, :load_imap_error_mapping, :record_query_comment, :log_csrf, :remove_session_data]
    actual_filters = Admin::EmailConfigsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_email_config
    actual = EmailConfig.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:to_email, :reply_email], {}], [ActiveModel::Validations::FormatValidator, [:to_email], { with: /\A[A-Z0-9_\.&%\+\-']+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,13})\z/i, message: 'is invalid' }], [ActiveRecord::Validations::UniquenessValidator, [:reply_email], { case_sensitive: true, scope: :account_id }], [ActiveModel::Validations::FormatValidator, [:reply_email], { with: /\A[A-Z0-9_\.&%\+\-']+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,13})\z/i, message: 'is invalid' }], [ActiveRecord::Validations::UniquenessValidator, [:activator_token], { case_sensitive: true, allow_nil: true }]]
    assert_equal expected, actual
  end
end
