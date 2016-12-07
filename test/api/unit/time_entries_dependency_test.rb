require_relative '../unit_test_helper'

class TimeEntriesDependencyTest < ActionView::TestCase
  def test_before_filters_web_time_sheets_controller
    expected_filters =  [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :set_current_account, :reset_language, :set_shard_for_payload, :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language, :remove_rails_2_flash_after, :set_affiliate_cookie, :print_logs, :verify_authenticity_token, :load_time_entry, :load_ticket, :create_permission, :validate_params, :timer_permission, :verify_permission, :check_agents_in_account, :set_mobile, :set_native_mobile]
    actual_filters = Helpdesk::TimeSheetsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_time_sheet
    actual = Helpdesk::TimeSheet.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = []
    assert_equal expected, actual
  end
end
