require_relative '../test_helper'

class ApiEmailConfigsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_application_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard,
                        :unset_current_account, :unset_current_portal, :set_current_account, :set_default_locale,
                        :set_locale, :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder,
                        :remove_rails_2_flash_before, :check_account_state, :set_time_zone, :check_day_pass_usage,
                        :force_utf8_params, :persist_user_agent, :set_cache_buster, :logging_details, :remove_pjax_param,
                        :remove_rails_2_flash_after, :set_affiliate_cookie, :verify_authenticity_token, :set_selected_tab,
                        :build_object, :load_object]
    actual_filters = Admin::EmailConfigsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_email_config
    actual = EmailConfig.validators.map { |x| [x.class, x.attributes, x.options] }
    expected =  [[ActiveModel::Validations::PresenceValidator, [:to_email, :reply_email], {}], [ActiveModel::Validations::FormatValidator, [:to_email], {:with=>/\A[A-Z0-9_\.&%\+\-']+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,13})\z/i, :message=>"is invalid"}], [ActiveRecord::Validations::UniquenessValidator, [:reply_email], {:case_sensitive=>true, :scope=>:account_id}], [ActiveModel::Validations::FormatValidator, [:reply_email], {:with=>/\A[A-Z0-9_\.&%\+\-']+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,13})\z/i, :message=>"is invalid"}], [ActiveRecord::Validations::UniquenessValidator, [:activator_token], {:case_sensitive=>true, :allow_nil=>true}]]
    assert_equal expected, actual
  end
end
