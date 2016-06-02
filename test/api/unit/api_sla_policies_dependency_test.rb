require_relative '../unit_test_helper'

class ApiSlaPoliciesDependencyTest < ActionView::TestCase
  def test_before_filters_application_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard,
                        :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :set_current_account, :set_default_locale,
                        :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage,
                        :force_utf8_params, :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_shard_for_payload,
                        :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token,
                        :set_selected_tab, :load_sla_policy, :load_item, :validate_params,
                        :initialize_escalation_level_details, :set_last_active_time]
    actual_filters = Helpdesk::SlaPoliciesController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_sla_policy
    actual = Helpdesk::SlaPolicy.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:name, :account], {}], [ActiveRecord::Validations::UniquenessValidator, [:name], { case_sensitive: true, scope: :account_id }]]
    assert_equal expected, actual
  end
end
