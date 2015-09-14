require_relative '../../test_helper'

class ForumsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_web_forums_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account,
                        :unset_current_portal, :set_current_account, :set_default_locale, :set_locale, :ensure_proper_protocol,
                        :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone,
                        :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :logging_details,
                        :remove_pjax_param, :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token, :portal_check,
                        :set_selected_tab, :find_or_initialize_forum, :fetch_monitorship, :load_topics, :set_customer_forum_params,
                        :fetch_selected_customers]
    actual_filters = Discussions::ForumsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_forum
    actual = Forum.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:name, :forum_category, :forum_type], {}],
                [ActiveRecord::Validations::UniquenessValidator, [:name], { case_sensitive: false, scope: :forum_category_id }],
                [ActiveModel::Validations::InclusionValidator, [:forum_type], { in: 1..4 }],
                [ActiveModel::Validations::InclusionValidator, [:forum_visibility], { in: 1..4 }]]
    assert_equal expected, actual
  end
end
