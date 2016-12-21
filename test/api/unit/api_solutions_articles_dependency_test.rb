require_relative '../unit_test_helper'

class ApiSolutionsArticlesDependencyTest < ActionView::TestCase
  def test_before_filters_solutions_articles_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :set_current_account, :reset_language, :set_shard_for_payload, :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language, :remove_rails_2_flash_after, :set_affiliate_cookie, :print_logs, :verify_authenticity_token, :set_modal, :sanitize_item_id, :portal_check, :set_selected_tab, :page_title, :load_meta_objects, :check_create_privilege, :old_folder, :check_new_folder, :bulk_update_folder, :validate_author, :language, :cleanup_params_for_title, :language_scoper, :check_parent_params, :set_parent_for_old_params]
    actual_filters = Solution::ArticlesController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_solution_article
    actual = Solution::Article.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:title, :description, :user_id, :account_id], {}], [ActiveModel::Validations::LengthValidator, [:title], {:minimum=>3, :maximum=>240}], [ActiveModel::Validations::NumericalityValidator, [:user_id], {}], [ActiveRecord::Validations::UniquenessValidator, [:language_id], {:case_sensitive=>true, :scope=>[:account_id, :parent_id], :if=>"!solution_article_meta.new_record?"}], [ActiveModel::Validations::InclusionValidator, [:status], {:in=>1..2}]]
    assert_equal expected, actual
  end
end
