require_relative '../test_helper'

class ApiAgentsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_agents_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, 
      :unset_current_portal, :set_current_account, :set_default_locale, :set_locale, :ensure_proper_protocol, 
      :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone, 
      :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :logging_details, 
      :remove_pjax_param, :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token, :load_object, 
      :ssl_check, :can_assume_identity, :load_roles, :load_groups, :check_demo_site, :restrict_current_user, 
      :check_current_user, :check_agent_limit, :check_agent_limit_on_update, :validate_params, 
      :can_edit_roles_and_permissions, :set_selected_tab, :set_native_mobile]
    actual_filters = AgentsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_agent
    actual = Agent.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:user_id], {}]]
    assert_equal expected, actual
  end
end
