require_relative '../unit_test_helper'

class ApiSolutionsFoldersDependencyTest < ActionView::TestCase
  def test_before_filters_solutions_folders_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, :unset_current_portal, :unset_shard_for_payload, :set_current_account, :reset_language, :set_shard_for_payload, :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_last_active_time, :reset_language, :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token, :language, :set_modal, :sanitize_item_id, :portal_check, :set_selected_tab, :load_meta, :validate_and_set_customers, :set_parent_for_old_params, :old_category, :check_new_category, :bulk_update_category, :clear_cache, :check_rate_limit]
    actual_filters = Solution::FoldersController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_solution_folder
    actual = Solution::Folder.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:name], {}], [ActiveRecord::Validations::UniquenessValidator, [:language_id], {:case_sensitive=>true, :scope=>[:account_id, :parent_id], :if=>"!solution_folder_meta.new_record?"}]]
    assert_equal expected, actual
  end
end
