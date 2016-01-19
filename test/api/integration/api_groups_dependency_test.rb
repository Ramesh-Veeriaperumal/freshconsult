require_relative '../test_helper'

class ApiGroupsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_application_controller
    expected_filters = [:determine_pod, :activate_authlogic, :clean_temp_files, :select_shard,
                        :unset_current_account, :unset_current_portal, :set_current_account, :set_default_locale, :set_locale,
                        :ensure_proper_protocol, :check_privilege, :freshdesk_form_builder, :remove_rails_2_flash_before,
                        :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent,
                        :set_cache_buster, :remove_pjax_param, :remove_rails_2_flash_after, :set_affiliate_cookie,
                        :verify_authenticity_token, :set_selected_tab, :set_last_active_time]
    actual_filters = GroupsController._process_action_callbacks.map { |c| c.filter.to_s }.reject { |f| f.starts_with?('_') }.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  # def test_validations_group
  #   actual = Group.validators.map { |x| [x.class, x.attributes, x.options] }
  #   expected = [[ActiveModel::Validations::PresenceValidator, [:name], {}], [ActiveRecord::Validations::UniquenessValidator, [:name], { case_sensitive: true, scope: :account_id }]]
  #   assert_equal expected, actual
  # end
end
