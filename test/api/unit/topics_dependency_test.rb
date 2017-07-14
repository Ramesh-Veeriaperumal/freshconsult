require_relative '../unit_test_helper'

class TopicsDependencyTest < ActionView::TestCase
  def test_before_filters_web_topics_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :set_current_account, :reset_language, :set_shard_for_payload, :set_default_locale, :set_locale, :set_msg_id, :set_ui_preference, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language, :remove_rails_2_flash_after, :set_affiliate_cookie, :print_logs, :verify_authenticity_token, :require_user, :find_topic, :portal_check, :fetch_monitorship, :set_page, :after_destroy_path, :verify_ticket_permission, :redirect_for_ticket, :set_selected_tab, :fetch_vote, :toggle_vote]
    actual_filters = Discussions::TopicsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_topic
    actual = Topic.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:forum, :user, :title], {}]]
    assert_equal expected, actual
  end
end
