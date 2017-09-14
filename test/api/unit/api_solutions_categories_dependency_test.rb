require_relative '../unit_test_helper'

class ApiSolutionsCategoriesDependencyTest < ActionView::TestCase
  def test_before_filters_solution_categories_controller
    expected_filters =  [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, 
      :unset_current_portal, :unset_shard_for_payload, :set_current_account, :reset_language, :set_shard_for_payload, 
      :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, 
      :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, 
      :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language, 
      :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token, :language, :set_modal, :sanitize_item_id, 
      :portal_check, :set_selected_tab, :page_title, :load_meta, :load_category_with_folders, :find_portal, :set_default_order, 
      :load_portal_solution_category_ids, :run_on_slave, :ensure_proper_sts_header, :set_ui_preference]
    actual_filters = Solution::CategoriesController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_solution_category
    actual = Solution::Category.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:name, :account], {}], [ActiveRecord::Validations::UniquenessValidator, [:language_id], {:case_sensitive=>true, :scope=>[:account_id, :parent_id], :if=>"!solution_category_meta.new_record?"}]]
    assert_equal expected, actual
  end
end
