require_relative '../unit_test_helper'

class CategoriesDependencyTest < ActionView::TestCase
  def test_before_filters_application_controller
    expected_filters = [:determine_pod, :supress_logs, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account,
                        :unset_current_portal, :unset_shard_for_payload, :set_current_account, :set_current_ip, :reset_language, :set_shard_for_payload,
                        :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params,
                        :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language,
                        :set_affiliate_cookie, :verify_authenticity_token, :build_object, :load_object, :log_old_ui_path,
                        :unset_thread_variables, :portal_check, :check_no_topics, :set_selected_tab, :content_scope, :fetch_spam_counts,
                        :ensure_proper_sts_header, :set_ui_preference, :complete_step, :record_query_comment, :log_csrf, :remove_session_data,
                        :check_session_timeout]
    actual_filters = DiscussionsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_forum_category
    actual = ForumCategory.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:name, :account_id], {}], [ActiveRecord::Validations::UniquenessValidator, [:name], { case_sensitive: false, scope: :account_id }]]
    assert_equal expected, actual
  end
end
