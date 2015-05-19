require_relative '../../test_helper'

class CategoriesDependencyTest < ActionDispatch::IntegrationTest
  
  def test_account_suspended_json
    subscription = @account.subscription
    subscription.update_column(:state, "suspended")
    post "/agents.json", nil, @headers.merge("CONTENT_TYPE" => 'application/json')
    response = parse_response(@response.body)
    assert_equal({"code"=>"account_suspended", "message" => "Your account has been suspended."}, response)
    assert_response :forbidden
    subscription.update_column(:state, "trial")
  end

  def test_day_pass_expired_json
    Agent.any_instance.stubs(:occasional).returns(true).once
    subscription = @account.subscription
    subscription.update_column(:state, "active")
    get "/agents.json", nil, @headers.merge("CONTENT_TYPE" => 'application/json')
    response = parse_response(@response.body)
    assert_equal({"code"=>"access_denied", "message" => "You are not authorized to perform this action."}, response)
    assert_response :forbidden
  end

  def test_handle_unverified_request
    with_forgery_protection do
      post "/contacts.json", {:version => "v2", :format => :json, :authenticity_token => 'foo'}, @headers.merge("HTTP_COOKIE" => "_helpkit_session=true")
    end
    response = parse_response(@response.body)
    assert_response :unauthorized
    assert_equal({"code"=>"unverified_request", "message"=>"You have initiated a unverifiable request."}, response)
  end

  def test_before_filters_application_controller
    expected_filters = [:response_headers, :determine_pod, :activate_authlogic, :clean_temp_files, :select_shard, 
      :unset_current_account, :unset_current_portal, :set_current_account, :ensure_proper_protocol, :check_privilege, 
      :check_account_state, :set_time_zone, :check_day_pass_usage, :force_utf8_params, :persist_user_agent, 
      :set_cache_buster, :logging_details, :remove_rails_2_flash_after, :set_affiliate_cookie, 
      :verify_authenticity_token, :load_object, :check_params, :validate_params, :manipulate_params, :build_object, 
      :load_objects, :load_association, :portal_check]
    actual_filters = ApiDiscussions::CategoriesController._process_action_callbacks.map {|c| c.filter.to_s}.reject{|f| f.starts_with?("_")}.compact
    assert_equal expected_filters.map(&:to_s).sort, actual_filters.sort
  end

  def test_validations_forum_category
    actual = ForumCategory.validators.collect{|x| [x.class, x.attributes, x.options]}
    expected = [[ActiveModel::Validations::PresenceValidator, [:name, :account_id], {}], [ActiveRecord::Validations::UniquenessValidator, [:name], {:case_sensitive=>false, :scope=>:account_id}]]
    assert_equal expected, actual
  end
end