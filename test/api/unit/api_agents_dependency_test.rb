require_relative '../unit_test_helper'

class ApiAgentsDependencyTest < ActionView::TestCase
  def test_before_filters_agents_controller
    expected_filters = [:determine_pod, :supress_logs, :activate_authlogic, :clean_temp_files, :select_shard,
                        :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :set_current_account,
                        :set_current_ip, :reset_language, :set_shard_for_payload, :set_default_locale, :set_locale, :set_msg_id,
                        :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent,
                        :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language,
                        :set_affiliate_cookie, :verify_authenticity_token, :load_object,
                        :ssl_check, :can_assume_identity, :load_roles, :load_groups, :check_demo_site, :restrict_current_user,
                        :check_current_user, :check_agent_limit, :check_agent_limit_on_update, :validate_params,
                        :can_edit_roles_and_permissions, :set_selected_tab, :set_native_mobile, :filter_params,
                        :check_occasional_agent_params, :unset_thread_variables, :log_old_ui_path,
                        :set_skill_data, :set_filter_data, :ensure_proper_sts_header, :access_denied, :record_query_comment, :sanitize_params,
                        :log_csrf, :remove_session_data, :check_field_agent_limit, :check_role_permission, :check_session_timeout]
    actual_filters = AgentsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_agent
    actual = Agent.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:user_id], {}]]
    assert_equal expected, actual
  end
end
