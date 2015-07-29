require_relative '../test_helper'
class ApiContactsControllerTest < ActionController::TestCase

  include ContactFieldsHelper

  def wrap_cname(params)
    { api_contact: params }
  end

  def user
    get_default_user
  end

  def get_company
    company = Company.first || create_company
    company
  end

  def controller_params(params = {})
    remove_wrap_params
    request_params.merge(params)
  end

  # Create User
  def test_create_contact
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email)
    assert_response :created
    match_json(contact_pattern(User.last))
  end

  def test_create_contact_without_name
    post :create, construct_params({},  email: Faker::Internet.email)
    match_json([bad_request_error_pattern('name','missing_field')])
  end

  def test_create_contact_without_any_contact_detail
    post :create, construct_params({},  name: Faker::Lorem.characters(10))
    match_json([bad_request_error_pattern('email','Please fill at least 1 of email, mobile, phone, twitter_id fields.'),
                bad_request_error_pattern('phone','Please fill at least 1 of email, mobile, phone, twitter_id fields.'),
                bad_request_error_pattern('mobile','Please fill at least 1 of email, mobile, phone, twitter_id fields.'),
                bad_request_error_pattern('twitter','Please fill at least 1 of email, mobile, phone, twitter_id fields.')])
  end

  def test_create_contact_with_existing_email
    email = Faker::Internet.email
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: email)
    assert_response :created
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: email)
    match_json([bad_request_error_pattern('primary_email.email', 'has already been taken'),
                bad_request_error_pattern('base', 'Email has already been taken')])
  end

  def test_create_contact_with_invalid_client_manager
    post :create, construct_params({},  name: Faker::Lorem.characters(15), 
                                        email: Faker::Internet.email,
                                        client_manager: "String",
                                        company_id: 1)
    match_json([bad_request_error_pattern('client_manager','not_included', list:'true,false')])
  end

  def test_create_contact_with_client_manager_without_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true)
    match_json([bad_request_error_pattern('company_id','is not a number')])
  end

  def test_create_contact_with_valid_client_manager
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id)
    assert User.last.client_manager == true
    assert_response :created
    match_json(contact_pattern(User.last))
  end

  def test_create_contact_with_invalid_language_and_timezone
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: 1,
                                        language: Faker::Lorem.characters(5),
                                        time_zone: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('language','not_included',
      list: I18n.available_locales.map(&:to_s).join(',')),
    bad_request_error_pattern('time_zone','not_included', list: ActiveSupport::TimeZone.all.map { |time_zone| time_zone.name }.join(','))])
  end

  def test_create_contact_with_valid_language_and_timezone
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: 1,
                                        language: "en",
                                        time_zone: "Mountain Time (US & Canada)")
    assert_response :created
    match_json(contact_pattern(User.last))
  end

  def test_create_contact_with_invalid_tags
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: 1,
                                        language: "en",
                                        tags: "tag1, tag2, tag3")
    match_json([bad_request_error_pattern('tags', 'data_type_mismatch', data_type: 'Array')])

  end

  def test_create_contact_with_invalid_avatar_attributes
    file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = {  name: Faker::Lorem.characters(15), email: Faker::Internet.email, client_manager: true, company_id: 1,
                language: "en", avatar_attributes: { dummyfield: Faker::Internet.email } }
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('dummyfield', 'invalid_field')])

  end

  def test_create_contact_with_invalid_custom_fields
    params = {  name: Faker::Lorem.characters(15), email: Faker::Internet.email, client_manager: true, company_id: 1,
                language: "en", custom_fields: { dummyfield: Faker::Lorem.characters(20) } }
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('dummyfield', 'invalid_field')])

  end

  def test_create_contact_with_tags_avatar_and_custom_fields
    cf_dept = create_contact_field(cf_params({ :type=>"text", :field_type=>"custom_text", :label=> "Department", :editable_in_signup => "true"}))
    tags = [Faker::Name.name, Faker::Name.name]
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: 1,
                                        language: "en",
                                        tags: tags,
                                        avatar_attributes: { content: file },
                                        custom_fields: { "cf_department" => "Sample Dept" })
    assert_response :created
    match_json(contact_pattern(User.last))
  end

  # Update user
  def test_update_user_with_blank_name
    params_hash  = { name:"" }
    sample_user = user
    sample_user.update_attribute(:phone,"1234567890")
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', "can't be blank")])
  end

  def test_update_user_without_any_contact_detail
    params_hash = { email: "", phone:"", mobile:"", twitter_id:"" }
    sample_user = user
    put :update, construct_params({id: sample_user.id}, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('email','Please fill at least 1 of email, mobile, phone, twitter_id fields.'),
                bad_request_error_pattern('phone','Please fill at least 1 of email, mobile, phone, twitter_id fields.'),
                bad_request_error_pattern('mobile','Please fill at least 1 of email, mobile, phone, twitter_id fields.'),
                bad_request_error_pattern('twitter','Please fill at least 1 of email, mobile, phone, twitter_id fields.')])
  end

  def test_update_user_with_valid_params
    cf_dept = create_contact_field(cf_params({ :type=>"text", :field_type=>"custom_text", :label=> "Department", :editable_in_signup => "true"}))
    tags = [Faker::Name.name, Faker::Name.name, "tag_sample_test_3"]
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    cf = { "cf_department" => "Sample Dept" }

    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: 1,
                                        language: "en",
                                        tags: ["tag_sample_test_1","tag_sample_test_2","tag_sample_test_3"],
                                        avatar_attributes: { content: file })
    sample_user = User.last
    assert_response :created

    params_hash = { language: "cs", 
                    time_zone: "Tokyo",
                    job_title: "emp",
                    custom_fields: cf,
                    tags: tags }
     
    put :update, construct_params({ id: sample_user.id }, params_hash)

    assert_response :success
    assert sample_user.reload.language == "cs"
    assert sample_user.reload.time_zone == "Tokyo"
    assert sample_user.reload.job_title == "emp"
    assert sample_user.reload.tag_names == tags.map { |t| t }.join(', ')
    assert sample_user.reload.custom_field == cf
    match_json(contact_pattern(sample_user.reload))
  end

  def test_update_contact_with_valid_company_id_and_client_manager
    comp = get_company
    sample_user = User.first
    params_hash = { company_id: comp.id, client_manager: true }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :success
    assert sample_user.reload.client_manager == true
    assert sample_user.reload.company_id == comp.id
    match_json(contact_pattern(sample_user.reload))
  end

  def test_update_client_manager_with_invalid_company_id
    sample_user = User.first
    comp = get_company
    params_hash = { company_id: 1, client_manager: true, phone: "1234567890" }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :success
    sample_user.reload
    params_hash = { company_id: nil }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :success
    assert sample_user.reload.company_id == nil
  end

  # Delete user

  def test_delete_contact
    sample_user = User.last
    sample_user.update_column(:deleted, false)
    delete :destroy, construct_params({id: sample_user.id})
    assert_response :no_content
    assert sample_user.reload.deleted == true
  end

  def test_delete_a_deleted_contact
    sample_user = User.last
    sample_user.update_column(:deleted, false)
    delete :destroy, construct_params({id: sample_user.id})
    assert_response :no_content
    delete :destroy, construct_params({id: sample_user.id})
    assert_response :not_found
  end

  def test_update_a_deleted_contact
    sample_user = User.last
    sample_user.update_column(:deleted, false)
    delete :destroy, construct_params({id: sample_user.id})
    assert_response :no_content
    params_hash = { language: "cs" }
    put :update, construct_params({id: sample_user.id}, params_hash)
    assert_response :not_found
  end

  def test_show_a_deleted_contact
    sample_user = User.last
    sample_user.update_column(:deleted, false)
    delete :destroy, construct_params({id: sample_user.id})
    assert_response :no_content
    get :show, construct_params({id: sample_user.id})
    match_json(deleted_contact_pattern(sample_user.reload))
  end

  def test_restore_a_deleted_contact
    sample_user = User.last
    sample_user.update_column(:deleted, false)
    delete :destroy, construct_params({id: sample_user.id})
    assert_response :no_content
    put :restore, construct_params({id: sample_user.id})
    assert_response :no_content
    get :show, construct_params({id: sample_user.id})
    match_json(contact_pattern(sample_user.reload))
  end

  # User Index and Filters
  def test_contact_index
    User.update_all(deleted: false)
    get :index, controller_params
    assert_response :success
    users = User.all
    pattern = users.map { |user| index_deleted_contact_pattern(user) }
    match_json(pattern)
  end

  def test_contact_filter_state
    User.update_all(deleted: false)
    User.first.update_column(:deleted, true)
    get :index, controller_params({state: 'deleted'})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_phone
    User.update_all(phone: nil)
    User.first.update_column(:phone, '1234567890')
    get :index, controller_params({phone: '1234567890'})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_email
    User.update_all(email: nil)
    email = Faker::Internet.email
    User.first.update_column(:email, email)
    get :index, controller_params({email: email})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_company_id
    comp = get_company
    User.update_all(customer_id: nil)
    User.first.update_column(:customer_id, comp.id)
    get :index, controller_params({company_id: comp.id})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_combined_filter
    email = Faker::Internet.email
    comp = get_company
    User.update_all(customer_id: nil)
    User.first.update_column(:customer_id, comp.id)
    User.first.update_column(:email, email)
    User.last.update_column(:customer_id,comp.id)
    get :index, controller_params({company_id: comp.id, email: email})
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_invalid
    get :index, controller_params({customer_id: 1})
    assert_response :bad_request
    match_json([bad_request_error_pattern('customer_id', "invalid_field")])
  end

  # Make agent out of a user

  def test_make_agent
    User.update_all(email: nil)
    User.first.update_attribute(:email,Faker::Internet.email)
    put :make_agent, construct_params({id: User.first.id})
    assert_response :success
    assert User.first.reload.helpdesk_agent == true
    assert Agent.last.user.id = User.first.id
  end

  def test_make_agent_out_of_a_user_without_email
    User.first.account.subscription.update_attribute(:agent_limit, nil)
    User.update_all(email: nil)
    put :make_agent, construct_params({id: User.first.id})
    assert_response :bad_request
    match_json([bad_request_error_pattern('email','Contact with email id can only be converted to agent')])
  end

  def test_make_agent_out_of_a_user_beyond_agent_limit
    User.first.account.subscription.update_attribute(:agent_limit,1)
    User.last.update_attribute(:email,Faker::Internet.email) if User.last.email.blank?
    put :make_agent, construct_params({id: User.last.id})
    assert_response :bad_request
    match_json([bad_request_error_pattern('id','You have reached the maximum number of agents your subscription allows. You need to delete an existing agent or contact your account administrator to purchase additional agents.')])
     
  end
end