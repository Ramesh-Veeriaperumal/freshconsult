require_relative '../unit_test_helper'

class ApiContactsDependencyTest < ActionView::TestCase
  def test_before_filters_contacts_controller
    expected_filters = [:determine_pod, :supress_logs, :activate_authlogic, :clean_temp_files, :select_shard, :unset_current_account,
                        :unset_current_portal, :unset_shard_for_payload, :set_current_account, :set_current_ip, :reset_language, :set_shard_for_payload,
                        :set_default_locale, :set_locale, :set_msg_id, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :check_account_state, :check_agent_deleted_forever, :set_time_zone, :check_day_pass_usage, :force_utf8_params,
                        :persist_user_agent, :set_cache_buster, :remove_pjax_param, :set_pjax_url, :set_last_active_time, :reset_language,
                        :set_affiliate_cookie, :verify_authenticity_token, :build_item, :load_multiple_items,
                        :redirect_to_mobile_url, :clean_params, :check_demo_site, :set_selected_tab, :load_item,
                        :can_change_password?, :load_password_policy, :check_agent_limit, :can_make_agent, :run_on_slave, :set_mobile,
                        :init_user_email, :load_companies, :check_parent, :fetch_contacts, :set_native_mobile, :set_required_fields,
                        :unset_thread_variables, :validate_state_param,
                        :set_validatable_custom_fields, :restrict_user_primary_email_delete, :ensure_proper_sts_header,
                        :set_ui_preference, :record_query_comment, :export_limit_reached?, :log_csrf, :remove_session_data,
                        :check_session_timeout]
    actual_filters = ContactsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_contact
    actual = User.validators.map { |x| [x.class, x.attributes, x.options] }
    expected = [
      [ActiveRecord::Validations::UniquenessValidator, [:twitter_id], { case_sensitive: true, scope: :account_id, allow_nil: true, allow_blank: true, unless: :uniqueness_validated }],
      [ActiveRecord::Validations::UniquenessValidator, [:external_id], { case_sensitive: true, scope: :account_id, allow_nil: true, allow_blank: true }],
      [ActiveRecord::Validations::UniquenessValidator, [:unique_external_id], { case_sensitive: false, scope: :account_id, allow_nil: true, unless: :uniqueness_validated }],
      [ActiveModel::Validations::NumericalityValidator, [:login_count], { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }],
      [ActiveModel::Validations::NumericalityValidator, [:failed_login_count], { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }],
      [ActiveModel::Validations::LengthValidator, [:password], { on: :update, minimum: 4, if: :has_no_credentials? }],
      [ActiveModel::Validations::ConfirmationValidator, [:password], { if: :require_password? }],
      [ActiveModel::Validations::LengthValidator, [:password_confirmation], { on: :update, minimum: 4, if: :has_no_credentials? }],
      [ActiveRecord::Validations::UniquenessValidator, [:perishable_token], { case_sensitive: true, if: :perishable_token_changed? }],
      [ActiveModel::Validations::PresenceValidator, [:persistence_token], {}], [ActiveRecord::Validations::UniquenessValidator, [:persistence_token], { case_sensitive: true, if: :persistence_token_changed? }],
      [ActiveRecord::Validations::UniquenessValidator, [:single_access_token], { case_sensitive: true, if: :single_access_token_changed? }],
      [ActiveModel::Validations::LengthValidator, [:user_skills], { maximum: 35 }]
    ]
    assert_equal expected, actual
  end
end
