require_relative '../../test_helper'

class TopicsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_web_topics_controller
    expected_filters =  [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard,
                         :unset_current_account, :unset_current_portal, :set_current_account, :set_default_locale, :set_locale,
                         :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before,
                         :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent,
                         :set_cache_buster, :logging_details, :remove_pjax_param, :remove_rails_2_flash_after, :set_affiliate_cookie,
                         :verify_authenticity_token, :require_user, :find_topic, :portal_check, :fetch_monitorship, :set_page,
                         :after_destroy_path, :set_selected_tab, :verify_ticket_permission, :redirect_for_ticket, :set_selected_tab]
    actual_filters = Discussions::TopicsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_topic
    actual = Topic.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:forum, :user, :title], {}]]
    assert_equal expected, actual
  end
end
