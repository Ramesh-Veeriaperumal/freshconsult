require_relative '../../test_helper'

class ForumsDependencyTest < ActionDispatch::IntegrationTest
  def test_before_filters_application_controller
    expected_filters = [:response_headers, :determine_pod, :activate_authlogic, :clean_temp_files, :select_shard,
     :unset_current_account, :unset_current_portal, :set_current_account, :ensure_proper_protocol, :check_privilege, 
     :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, 
     :set_cache_buster, :logging_details, :remove_rails_2_flash_after, :set_affiliate_cookie,
     :verify_authenticity_token, :build_object, :load_object, :load_objects, :validate_params, 
     :back_up_topic_ids, :manipulate_params, :assign_forum_category_id, :portal_check, 
     :set_account_and_category_id]
    actual_filters = ApiDiscussions::ForumsController._process_action_callbacks.map {|c| c.filter.to_s}.reject{|f| f.starts_with?("_")}.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_forum_category
    actual = Forum.validators.collect{|x| [x.class, x.attributes, x.options]}
    expected =[[ActiveModel::Validations::PresenceValidator, [:name, :forum_category, :forum_type], {}], 
               [ActiveRecord::Validations::UniquenessValidator, [:name], {:case_sensitive=>false, :scope=>:forum_category_id}], 
               [ActiveModel::Validations::InclusionValidator, [:forum_type], {:in=>1..4}], 
               [ActiveModel::Validations::InclusionValidator, [:forum_visibility], {:in=>1..4}]]
    assert_equal expected, actual
  end
end