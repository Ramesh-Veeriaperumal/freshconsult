require_relative '../unit_test_helper'

class ApiCompaniesDependencyTest < ActionView::TestCase
  def test_before_filters_application_controller
    expected_filters = [:determine_pod, :supress_logs, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account,
                        :unset_current_portal, :unset_shard_for_payload, :set_current_account, :set_current_ip, :reset_language, :set_shard_for_payload,
                        :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :log_old_ui_path,
                        :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language,
                        :set_affiliate_cookie, :verify_authenticity_token, :load_multiple_items, :unset_thread_variables,
                        :set_selected_tab, :load_item, :build_item, :set_required_fields, :set_validatable_custom_fields,
                        :set_native_mobile, :ensure_proper_sts_header, :set_validatable_default_fields, :record_query_comment, :check_archive_feature, :export_limit_reached?, :log_csrf, :remove_session_data,
                        :check_session_timeout, :redirect_old_ui_routes]

    actual_filters = CompaniesController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_company
    actual = Company.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:name, :account], {}], [ActiveRecord::Validations::UniquenessValidator, [:name], { case_sensitive: false, scope: :account_id, unless: :uniqueness_validated }]]
    assert_equal expected, actual
  end
end
