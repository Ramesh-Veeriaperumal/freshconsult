require_relative '../unit_test_helper'

class ApiCommentsDependencyTest < ActionView::TestCase
  def test_before_filters_web_posts_controller
    expected_filters = [:determine_pod, :supress_logs, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account,
                        :unset_current_portal, :unset_shard_for_payload, :set_current_account, :set_current_ip, :reset_language, :set_shard_for_payload,
                        :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :log_old_ui_path,
                        :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language,
                        :set_affiliate_cookie, :verify_authenticity_token, :find_post, :find_topic, :unset_thread_variables,
                        :check_lock, :ensure_proper_sts_header, :record_query_comment, :log_csrf, :remove_session_data, :check_session_timeout]
    actual_filters = Discussions::PostsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_post
    actual = Post.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:user_id, :body_html, :topic], {}]]
    assert_equal expected, actual
  end

  def no_privilege_for_update
    fields_dependant_on_update_privilege = DiscussionConstants::UPDATE_COMMENT_FIELDS[:all]
    update_privilege = ABILITIES[:'api_discussions/api_comment'].map(&:action).include?(:update)
    # both should be false or both should be true
    assert (update_privilege && fields_dependant_on_update_privilege) == (update_privilege || fields_dependant_on_update_privilege)
  end
end
