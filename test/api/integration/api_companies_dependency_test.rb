require_relative '../test_helper'

class ApiCompaniesDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_application_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard,
                        :unset_current_account, :unset_current_portal, :set_current_account, :set_default_locale,
                        :set_locale, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage,
                        :force_utf8_params, :persist_user_agent, :set_cache_buster, :logging_details, :remove_pjax_param,
                        :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token,
                        :load_multiple_items, :add_to_history, :set_selected_tab, :load_item, :build_item,
                        :set_required_fields, :set_validatable_custom_fields]
    actual_filters = CompaniesController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_company
    actual = Company.validators.collect { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveModel::Validations::PresenceValidator, [:name, :account], {}], [ActiveRecord::Validations::UniquenessValidator, [:name], { case_sensitive: false, scope: :account_id }]]
    assert_equal expected, actual
  end
end
