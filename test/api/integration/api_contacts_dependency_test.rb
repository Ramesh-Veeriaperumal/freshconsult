require_relative '../test_helper'

class ApiContactsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_application_controller
    expected_filters =  [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account, :unset_current_portal, :set_current_account, :set_default_locale, :set_locale, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, :set_cache_buster, :logging_details, :remove_pjax_param, :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token, :build_item, :load_multiple_items, :add_to_history, :redirect_to_mobile_url, :clean_params, :check_demo_site, :set_selected_tab, :load_item, :can_change_password?, :load_password_policy, :check_agent_limit, :can_make_agent, :run_on_slave, :set_mobile, :init_user_email, :check_parent, :fetch_contacts, :set_native_mobile, :set_required_fields, :set_validatable_custom_fields, :restrict_user_primary_email_delete]
    actual_filters = ContactsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_contact
    actual = User.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [[ActiveRecord::Validations::UniquenessValidator, [:twitter_id], { case_sensitive: true, scope: :account_id, allow_nil: true, allow_blank: true }], [ActiveRecord::Validations::UniquenessValidator, [:external_id], { case_sensitive: true, scope: :account_id, allow_nil: true, allow_blank: true }], [ActiveModel::Validations::NumericalityValidator, [:login_count], { only_integer: :true, greater_than_or_equal_to: 0, allow_nil: true }], [ActiveModel::Validations::NumericalityValidator, [:failed_login_count], { only_integer: :true, greater_than_or_equal_to: 0, allow_nil: true }], [ActiveModel::Validations::LengthValidator, [:password], { on: :update, minimum: 4, if: :has_no_credentials? }], [ActiveModel::Validations::ConfirmationValidator, [:password], { if: :require_password? }], [ActiveModel::Validations::LengthValidator, [:password_confirmation], { on: :update, minimum: 4, if: :has_no_credentials? }], [ActiveRecord::Validations::UniquenessValidator, [:perishable_token], { case_sensitive: true, if: :perishable_token_changed? }], [ActiveModel::Validations::PresenceValidator, [:persistence_token], {}], [ActiveRecord::Validations::UniquenessValidator, [:persistence_token], { case_sensitive: true, if: :persistence_token_changed? }], [ActiveRecord::Validations::UniquenessValidator, [:single_access_token], { case_sensitive: true, if: :single_access_token_changed? }]]
    assert_equal expected, actual
  end
end
