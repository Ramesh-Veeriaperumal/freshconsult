module SegmentFiltersTestHelper
  CONTACT_FILTER_PARAMS = {"name"=>"This month", "query_hash"=>[{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"month"}, {"condition"=>"tag_names", "operator"=>"is_in", "type"=>"default", "value"=>["apple"]}]}
  CONTACT_UPDATED_FILTER_PARAMS = {"name"=>"This month", "query_hash"=>[{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"month"}, {"condition"=>"tag_names", "operator"=>"is_in", "type"=>"default", "value"=>["apple", "RK"]}]}



  COMPANY_FILTER_PARAMS = {"name"=>"First Com Filter", "query_hash"=>[{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"today"}]}

  COMPANY_UPDATED_FILTER_PARAMS = {"name"=>"First Com Filter", "query_hash"=>[{"condition"=>"created_at", "operator"=>"is_greater_than", "type"=>"default", "value"=>"month"}]}

  def create_contact_segment
    contact_filter = @account.contact_filters.new({name: Faker::Name.name, data: CONTACT_FILTER_PARAMS["query_hash"]})
    contact_filter.save!
    contact_filter
  end

  def create_company_segment
    company_filter = @account.company_filters.new({name: Faker::Name.name, data: COMPANY_FILTER_PARAMS["query_hash"]})
    company_filter.save!
    company_filter
  end

  def test_prevent_unauthorized_access
    remove_privilege(@agent, :manage_segments)
    post :create, construct_params({ version: 'private'}, filter_params)
    assert_response 403
  ensure
    add_privilege(@agent, :manage_segments)
  end

  def test_create_segment_filter
    Ember::Segments::BaseFiltersController.const_set(:SEGMENT_LIMIT, '5368709119.0')
    Ember::Segments::ContactFiltersController.any_instance.stubs(:limit_exceeded?).returns(false)
    Ember::Segments::CompanyFiltersController.any_instance.stubs(:limit_exceeded?).returns(false)
    post :create, construct_params({ version: 'private'}, filter_params)
    assert_response 200
    Ember::Segments::BaseFiltersController.safe_send(:remove_const, :SEGMENT_LIMIT)
  end

  def test_update_segment_filter
    segment = create_segment
    put :update, construct_params({id: segment.id, version: 'private'}, updated_filter_params)
    assert_response 200
  end

  def test_segment_list_access_to_agent
    create_segment
    remove_privilege(@agent, :manage_segments)
    get :index, controller_params(version: 'private')
    assert_response 200
  ensure
    add_privilege(@agent, :manage_segments)
  end

  def test_delete_segment_filter
    segment = create_segment
    delete :destroy, construct_params({id: segment.id, version: 'private'})
    assert_response 204
  end
end