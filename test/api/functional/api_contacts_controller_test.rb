require_relative '../test_helper'
class ApiContactsControllerTest < ActionController::TestCase
  include ContactFieldsHelper

  def wrap_cname(params)
    { api_contact: params }
  end

  def get_user
    @account.all_contacts.where(deleted: false).first
  end

  def get_user_with_email
    @account.all_contacts.where('email is not null and deleted is false').first
  end

  def get_company
    company = Company.first || create_company
    company
  end

  def controller_params(params = {})
    remove_wrap_params
    request_params.merge(params)
  end

  # Show User
  def test_show_a_contact
    sample_user = get_user
    get :show, construct_params(id: sample_user.id)
    match_json(contact_pattern(sample_user.reload))
  end

  def test_show_a_non_existing_contact
    sample_user = get_user
    get :show, construct_params(id: 0)
    assert_response :not_found
  end

  # Create User
  def test_create_contact
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email)
    assert_response :created
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_without_name
    post :create, construct_params({},  email: Faker::Internet.email)
    match_json([bad_request_error_pattern('name', 'missing_field')])
  end

  def test_create_contact_without_any_contact_detail
    post :create, construct_params({},  name: Faker::Lorem.characters(10))
    match_json([bad_request_error_pattern('email', 'Please fill at least 1 of email, mobile, phone, twitter_id fields.')])
  end

  def test_create_contact_with_existing_email
    email = Faker::Internet.email
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: email)
    assert_response :created
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: email)
    match_json([bad_request_error_pattern('email', 'Email has already been taken')])
  end

  def test_create_contact_with_invalid_client_manager
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: 'String',
                                        company_id: comp.id)
    match_json([bad_request_error_pattern('client_manager', 'data_type_mismatch', data_type: 'Boolean')])
  end

  def test_create_contact_with_client_manager_without_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true)
    match_json([bad_request_error_pattern('company_id', 'company_id_required')])
  end

  def test_create_contact_with_valid_client_manager
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id)
    assert User.last.client_manager == true
    assert_response :created
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_with_invalid_language_and_timezone
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id,
                                        language: Faker::Lorem.characters(5),
                                        time_zone: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('language', 'not_included',
                                          list: I18n.available_locales.map(&:to_s).join(',')),
                bad_request_error_pattern('time_zone', 'not_included', list: ActiveSupport::TimeZone.all.map(&:name).join(','))])
  end

  def test_create_contact_with_valid_language_and_timezone
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        time_zone: 'Mountain Time (US & Canada)')
    assert_response :created
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_with_invalid_tags
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        tags: 'tag1, tag2, tag3')
    match_json([bad_request_error_pattern('tags', 'data_type_mismatch', data_type: 'Array')])
  end

  def test_create_contact_with_invalid_avatar
    comp = get_company
    params = {  name: Faker::Lorem.characters(15),
                email: Faker::Internet.email,
                client_manager: true,
                company_id: comp.id,
                language: 'en',
                avatar: Faker::Internet.email }
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('avatar', 'data_type_mismatch', data_type: 'format')])
  end

  def test_create_contact_with_invalid_avatar_file_type
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    comp = get_company
    params = {  name: Faker::Lorem.characters(15),
                email: Faker::Internet.email,
                client_manager: true,
                company_id: comp.id,
                language: 'en',
                avatar: file }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('avatar', 'Invalid file type. Please upload a jpg or png file')])
  end

  def test_create_contact_with_invalid_avatar_file_size
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = {  name: Faker::Lorem.characters(15), email: Faker::Internet.email, client_manager: true, company_id: 1,
                language: 'en', avatar: file }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    post :create, construct_params({},  params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    match_json([bad_request_error_pattern('avatar', 'invalid_size', max_size: '5 MB')])
  end

  def test_create_contact_with_invalid_field_in_custom_fields
    comp = get_company
    params = {  name: Faker::Lorem.characters(15),
                email: Faker::Internet.email,
                client_manager: true,
                company_id: comp.id,
                language: 'en',
                custom_fields: { dummyfield: Faker::Lorem.characters(20) } }
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('dummyfield', 'invalid_field')])
  end

  def test_create_contact_with_tags_avatar_and_custom_fields
    cf_dept = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Department', editable_in_signup: 'true'))
    tags = [Faker::Name.name, Faker::Name.name]
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    comp = get_company
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        tags: tags,
                                        avatar: file,
                                        custom_fields: { 'cf_department' => 'Sample Dept' })
    assert_response :created
    match_json(deleted_contact_pattern(User.last))
  end

  # Custom fields validation during creation
  def test_create_contact_with_custom_fields
    comp = get_company

    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Department', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Sample check box', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'sample_date', editable_in_signup: 'true'))

    create_contact_field(cf_params(type: 'text', field_type: 'custom_dropdown', label: 'sample_dropdown', editable_in_signup: 'true'))
    ContactFieldChoice.create(value: 'Choice 1', position: 1)
    ContactFieldChoice.create(value: 'Choice 2', position: 2)
    ContactFieldChoice.create(value: 'Choice 3', position: 3)
    ContactFieldChoice.update_all(account_id: @account.id)
    ContactFieldChoice.update_all(contact_field_id: ContactField.find_by_name('cf_sample_dropdown').id)

    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        custom_fields: { 'cf_department' => 'Sample Dept', 'cf_sample_check_box' => true, 'cf_sample_date' => '2010-11-01', 'cf_sample_dropdown' => 'Choice 1' })
    assert_response :created
    assert User.last.custom_field['cf_sample_check_box'] == true
    assert User.last.custom_field['cf_department'] == 'Sample Dept'
    assert User.last.custom_field['cf_sample_date'].to_date == Date.parse('2010-11-01')
    assert User.last.custom_field['cf_sample_dropdown'] == 'Choice 1'
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_with_invalid_custom_fields
    comp = get_company
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Check Me', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'DOJ', editable_in_signup: 'true'))

    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        custom_fields: { 'cf_check_me' => 'aaa', 'cf_doj' => 2010 })
    assert_response :bad_request
    match_json([bad_request_error_pattern('cf_check_me', 'data_type_mismatch', data_type: 'Boolean'),
                bad_request_error_pattern('cf_doj', 'is not a date')])
  end

  def test_create_contact_with_invalid_dropdown_field
    comp = get_company

    create_contact_field(cf_params(type: 'text', field_type: 'custom_dropdown', label: 'Choose Me', editable_in_signup: 'true'))
    ContactFieldChoice.create(value: 'Choice 1', position: 1)
    ContactFieldChoice.create(value: 'Choice 2', position: 2)
    ContactFieldChoice.create(value: 'Choice 3', position: 3)
    ContactFieldChoice.where(account_id: nil).update_all(account_id: @account.id)
    ContactFieldChoice.where(contact_field_id: nil).update_all(contact_field_id: ContactField.find_by_name('cf_choose_me').id)

    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        client_manager: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        custom_fields: { 'cf_choose_me' => 'Choice 4' })
    assert_response :bad_request
    match_json([bad_request_error_pattern('cf_choose_me', 'not_included', list: 'Choice 1,Choice 2,Choice 3')])
  end

  def test_create_length_invalid
    post :create, construct_params({}, name: Faker::Lorem.characters(300), job_title: Faker::Lorem.characters(300), mobile: Faker::Lorem.characters(300), address: Faker::Lorem.characters(300), email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com", twitter_id: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(300)])
    match_json([bad_request_error_pattern('name', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('job_title', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('mobile', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('address', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('email', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('twitter_id', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('phone', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('tags', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
  end

  def test_create_length_valid_with_trailing_spaces
    post :create, construct_params({}, name: Faker::Lorem.characters(20) + white_space, job_title: Faker::Lorem.characters(20) + white_space, mobile: Faker::Lorem.characters(20) + white_space, address: Faker::Lorem.characters(20) + white_space, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space, twitter_id: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space])
    assert_response :created
    match_json(deleted_contact_pattern(User.last))
  end

  # Update user
  def test_update_user_with_blank_name
    params_hash  = { name: '' }
    sample_user = get_user
    sample_user.update_attribute(:phone, '1234567890')
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('name', "can't be blank")])
  end

  def test_update_user_without_any_contact_detail
    params_hash = { phone: '', mobile: '', twitter_id: '' }
    sample_user = get_user
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('email', 'Please fill at least 1 of email, mobile, phone, twitter_id fields.')])
    sample_user.update_attribute(:email, email)
  end

  def test_update_user_with_valid_params
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'city', editable_in_signup: 'true'))
    tags = [Faker::Name.name, Faker::Name.name, 'tag_sample_test_3']
    cf = { 'cf_city' => 'Chennai' }

    sample_user = User.where(helpdesk_agent: false).last
    params_hash = { language: 'cs',
                    time_zone: 'Tokyo',
                    job_title: 'emp',
                    custom_fields: cf,
                    tags: tags }

    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :success
    assert sample_user.reload.language == 'cs'
    assert sample_user.reload.time_zone == 'Tokyo'
    assert sample_user.reload.job_title == 'emp'
    assert sample_user.reload.tag_names.split(', ').sort == tags.sort
    assert sample_user.reload.custom_field['cf_city'] == 'Chennai'
    match_json(deleted_contact_pattern(sample_user.reload))
  end

  def test_update_contact_with_valid_company_id_and_client_manager
    comp = get_company
    sample_user = get_user
    params_hash = { company_id: comp.id, client_manager: true }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :success
    assert sample_user.reload.client_manager == true
    assert sample_user.reload.company_id == comp.id
    match_json(deleted_contact_pattern(sample_user.reload))
  end

  def test_update_client_manager_with_invalid_company_id
    sample_user = get_user
    comp = get_company
    params_hash = { company_id: comp.id, client_manager: true, phone: '1234567890' }
    sample_user.update_attributes(params_hash)
    sample_user.reload
    params_hash = { company_id: nil }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :success
    assert sample_user.reload.company_id.nil?
    assert sample_user.reload.client_manager == false
  end

  def test_update_client_manager_with_unavailable_company_id
    sample_user = get_user
    comp = get_company
    sample_user.update_attribute(:client_manager, false)
    sample_user.update_attribute(:company_id, nil)
    params_hash = { company_id: 10_000 }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :bad_request
    assert sample_user.reload.company_id.nil?
    match_json([bad_request_error_pattern('company_id', 'Should not be invalid_value/blank')])
  end

  def test_update_email_when_email_is_not_nil
    sample_user = get_user_with_email
    email = Faker::Internet.email
    params_hash = { email: email }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :bad_request
    match_json([bad_request_error_pattern('email', 'Email cannot be updated')])
  end

  def test_update_email_when_email_is_nil
    sample_user = get_user
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    email = Faker::Internet.email
    params_hash = { email: email }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :success
    assert sample_user.reload.email == email
    sample_user.update_attribute(:email, email)
  end

  def test_update_the_email_of_a_contact_without_email
    user1 = @account.all_contacts.first
    user2 = @account.all_contacts.last
    email = user1.email
    user2.update_attribute(:email, nil)
    put :update, construct_params({ id: user2.id }, email: email)
    match_json([bad_request_error_pattern('email', 'Email has already been taken')])
  end

  def test_update_length_invalid
    sample_user = get_user
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    put :update, construct_params({ id: sample_user.id }, name: Faker::Lorem.characters(300), job_title: Faker::Lorem.characters(300), mobile: Faker::Lorem.characters(300), address: Faker::Lorem.characters(300), email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com", twitter_id: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(300)])
    match_json([bad_request_error_pattern('name', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('job_title', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('mobile', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('address', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('email', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('twitter_id', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('phone', 'is too long (maximum is 255 characters)'),
                bad_request_error_pattern('tags', 'is too long (maximum is 255 characters)')])
    assert_response :bad_request
    sample_user.update_attribute(:email, email)
  end

  def test_update_length_valid_with_trailing_space
    sample_user = get_user
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    put :update, construct_params({ id: sample_user.id }, name: Faker::Lorem.characters(20) + white_space, job_title: Faker::Lorem.characters(20) + white_space, mobile: Faker::Lorem.characters(20) + white_space, address: Faker::Lorem.characters(20) + white_space, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space, twitter_id: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space])
    assert_response :success
    match_json(deleted_contact_pattern(sample_user.reload))
    sample_user.update_attribute(:email, email)
  end

  # Delete user
  def test_delete_contact
    sample_user = get_user
    sample_user.update_column(:deleted, false)
    delete :destroy, construct_params(id: sample_user.id)
    assert_response :no_content
    assert sample_user.reload.deleted == true
  end

  def test_delete_a_deleted_contact
    sample_user = get_user
    sample_user.update_column(:deleted, true)
    delete :destroy, construct_params(id: sample_user.id)
    assert_response :not_found
  end

  def test_update_a_deleted_contact
    sample_user = get_user
    sample_user.update_column(:deleted, true)
    params_hash = { language: 'cs' }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response :not_found
  end

  def test_show_a_deleted_contact
    sample_user = get_user
    sample_user.update_column(:deleted, true)
    get :show, construct_params(id: sample_user.id)
    match_json(deleted_contact_pattern(sample_user.reload))
  end

  def test_restore_a_deleted_contact
    sample_user = get_user
    sample_user.update_column(:deleted, true)
    put :restore, construct_params(id: sample_user.id)
    assert_response :no_content
  end

  def test_restore_a_deleted_contact_with_params
    sample_user = get_user
    sample_user.update_column(:deleted, true)
    put :restore, construct_params({ id: sample_user.id }, job_title: 'Employee')
    assert_response :bad_request
    match_json([bad_request_error_pattern('job_title', 'invalid_field')])
  end

  def test_restore_a_merged_contact
    (user1, user2) = @account.all_contacts.where(deleted: false).first(2)
    user2.update_attribute(:deleted, true)
    user2.update_attribute(:parent_id, user1.id)
    put :restore, construct_params(id: user2.id)
    assert_response :not_found
    assert user2.deleted == true
  end

  # User Index and Filters
  def test_contact_index
    @account.all_contacts.update_all(deleted: false)
    get :index, controller_params
    assert_response :success
    users = @account.all_contacts
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern)
  end

  def test_contact_filter
    @account.all_contacts.update_all(deleted: true)
    @account.all_contacts.first.update_column(:deleted, false)
    get :index, controller_params
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
    @account.all_contacts.update_all(deleted: false)
  end

  def test_contact_filter_state
    @account.all_contacts.update_all(blocked: false)
    sample_user = @account.all_contacts.first
    sample_user.update_attribute(:blocked, true)
    sample_user.update_attribute(:deleted, true)
    sample_user.update_attribute(:blocked_at, Time.now)
    sample_user.update_attribute(:deleted_at, Time.now)
    get :index, controller_params(state: 'blocked')
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_phone
    @account.all_contacts.update_all(phone: nil)
    @account.all_contacts.first.update_column(:phone, '1234567890')
    get :index, controller_params(phone: '1234567890')
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_mobile
    @account.all_contacts.update_all(mobile: nil)
    @account.all_contacts.first.update_column(:mobile, '1234567890')
    get :index, controller_params(mobile: '1234567890')
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_email
    @account.all_contacts.update_all(email: nil)
    email = Faker::Internet.email
    @account.all_contacts.first.update_column(:email, email)
    get :index, controller_params(email: email)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_company_id
    comp = get_company
    @account.all_contacts.update_all(customer_id: nil)
    @account.all_contacts.first.update_column(:customer_id, comp.id)
    get :index, controller_params(company_id: comp.id)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_combined_filter
    email = @account.all_contacts.first.email || Faker::Internet.email
    comp = get_company
    @account.all_contacts.update_all(customer_id: nil)
    @account.all_contacts.first.update_column(:customer_id, comp.id)
    @account.all_contacts.first.update_column(:email, email) if @account.all_contacts.first.email != email
    @account.all_contacts.last.update_column(:customer_id, comp.id)
    get :index, controller_params(company_id: comp.id, email: email)
    assert_response :success
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_invalid
    get :index, controller_params(customer_id: 1)
    assert_response :bad_request
    match_json([bad_request_error_pattern('customer_id', 'invalid_field')])
  end

  # Make agent out of a user
  def test_make_agent
    assert_difference 'Agent.count', 1 do
      sample_user = get_user_with_email
      put :make_agent, construct_params(id: sample_user.id)
      assert_response :success
      assert sample_user.reload.helpdesk_agent == true
      assert Agent.last.user.id = sample_user.id
    end
  end

  def test_make_agent_with_params
    sample_user = get_user_with_email
    put :make_agent, construct_params({ id: sample_user.id }, job_title: 'Employee')
    assert_response :bad_request
    match_json([bad_request_error_pattern('job_title', 'invalid_field')])
  end

  def test_make_agent_out_of_a_user_without_email
    @account.subscription.update_attribute(:agent_limit, nil)
    sample_user = get_user
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    put :make_agent, construct_params(id: sample_user.id)
    assert_response :conflict
    sample_user.update_attribute(:email, email)
    match_json(request_error_pattern('inconsistent_state'))
    sample_user.update_attribute(:email, email)
  end

  def test_make_agent_out_of_a_user_beyond_agent_limit
    @account.subscription.update_attribute(:agent_limit, 1)
    sample_user = get_user_with_email
    put :make_agent, construct_params(id: sample_user.id)
    assert_response :forbidden
    match_json(request_error_pattern('max_agents_reached'))
  end

  def test_make_agent_fails_in_user_validation
    assert_no_difference 'Agent.count' do
      sample_user = get_user
      last_user = User.last
      twitter_handle = Faker::Internet.email
      last_user.update_attribute(:twitter_id, twitter_handle)
      sample_user.update_column(:twitter_id, twitter_handle)
      put :make_agent, construct_params(id: sample_user.id)
      assert_response :conflict
      assert sample_user.helpdesk_agent == false
    end
  end

  # Misc
  def test_demosite_delete
    sample_user = get_user
    sample_user.update_column(:deleted, false)

    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      delete :destroy, construct_params(id: sample_user.id)
    end

    assert_response :not_found
  end

  def test_demosite_update
    sample_user = get_user
    sample_user.update_column(:deleted, false)

    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      put :update, construct_params({ id: sample_user.id }, time_zone: 'Chennai')
    end

    assert_response :not_found
  end

  def test_demosite_create
    params = { name: Faker::Lorem.characters(15), email: Faker::Internet.email }

    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      post :create, construct_params({}, params)
    end

    assert_response :not_found
  end

  def test_update_array_field_with_empty_array
    sample_user = get_user
    put :update, construct_params({ id: sample_user.id }, tags: [])
    assert_response :success
    match_json(deleted_contact_pattern(sample_user.reload))
  end

  def test_update_array_fields_with_compacting_array
    tag = Faker::Name.name
    sample_user = get_user
    put :update, construct_params({ id: sample_user.id }, tags: [tag, '', ''])
    assert_response :success
    match_json(deleted_contact_pattern({ tags: [tag] }, sample_user.reload))
  end

  def test_index_with_link_header
    3.times do
      add_new_user(@account)
    end
    per_page =  @account.all_contacts.where(deleted: false).count - 1
    get :index, controller_params(per_page: per_page)
    assert_response :success
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/contacts?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response :success
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end
end
