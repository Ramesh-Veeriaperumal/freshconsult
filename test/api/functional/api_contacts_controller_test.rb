require_relative '../test_helper'
['social_tickets_creation_helper.rb', 'twitter_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class ApiContactsControllerTest < ActionController::TestCase
  include UsersTestHelper
  include CustomFieldsTestHelper
  include TwitterHelper
  include SocialTicketsCreationHelper

  def setup
    super
    initial_setup
  end

  @@initial_setup_run = false

  def initial_setup
    @account.reload
    return if @@initial_setup_run
    @account.features.multiple_user_companies.create
    @account.add_feature(:falcon)
    @account.add_feature(:multiple_user_companies)
    @account.add_feature(:multi_timezone)
    @account.add_feature(:multi_language)
    @account.reload

    20.times do
      @account.companies.build(name: Faker::Name.name)
    end
    @account.save

    @@initial_setup_run = true
  end

  def wrap_cname(params)
    query_params = params[:query_params]
    cparams = params.clone
    cparams.delete(:query_params)
    return query_params.merge(api_contact: cparams) if query_params

    { api_contact: cparams }
  end

  def get_user_with_multiple_companies
    new_user = add_new_user(@account)
    company_ids = Company.all.map(&:id)
    new_user.user_companies.create(:company_id => company_ids.first, :default => true)
    new_user.user_companies.create(:company_id => company_ids.second)
    new_user.save!
    new_user.reload
  end

  def get_user_with_default_company
    new_user = add_new_user(@account)
    new_user.user_companies.create(:company_id => get_company.id, :default => true)
    new_user.save!
    new_user.reload
  end

  def get_company
    company = Company.first
    return company if company
    company = Company.create(name: Faker::Name.name, account_id: @account.id)
    company.save
    company
  end

  def create_company(options = {})
    company = @account.companies.find_by_name(options[:name])
    return company if company
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = @account.id
    company.save!
    company
  end

  def construct_other_companies_hash(company_ids)
    other_companies = []
    (1..company_ids.count-1).each do |itr|
      company_hash = {}
      company_hash[:company_id] = company_ids[itr]
      company_hash[:view_all_tickets] = true
      other_companies.push(company_hash)
    end
    other_companies
  end

  def get_user
    @account.all_contacts.where(deleted: false, blocked: false).first
  end

  def set_max_extended_companies
    account_additional_settings = Account.current.account_additional_settings
    account_additional_settings.additional_settings['extended_user_companies'] = 500
    account_additional_settings.save
  end

  def reset_max_extended_companies
    account_additional_settings = Account.current.account_additional_settings
    account_additional_settings.additional_settings.delete('extended_user_companies')
    account_additional_settings.save
  end

  # Show User
  def test_show_a_contact
    sample_user = add_new_user(@account)
    get :show, construct_params(id: sample_user.id)
    ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
    match_json(contact_pattern(sample_user.reload).except(*ignore_keys))
    assert_response 200
  end

  def test_show_a_contact_with_avatar
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    sample_user = add_new_user(@account)
    sample_user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
    get :show, construct_params(id: sample_user.id)
    ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
    match_json(contact_pattern(sample_user.reload).except(*ignore_keys))
    assert_response 200
  end

  def test_show_a_contact_without_csat_rating
    sample_user = create_contact_with_csat_rating(@account, nil)
    get :show, construct_params(id: sample_user.id)
    assert_response 200
    res = JSON.parse(response.body)
    assert_nil res['csat_rating']
  end

  def test_show_a_contact_with_csat_rating
    sample_user = create_contact_with_csat_rating(@account, 103)
    get :show, construct_params(id: sample_user.id)
    assert_response 200
    res = JSON.parse(response.body)
    assert_equal 103, res['csat_rating']
  end

  def test_show_a_contact_with_preferred_source
    sample_user = add_new_user(@account)
    sample_user.merge_preferences = { preferred_source: 2 }
    sample_user.save_without_session_maintenance
    get :show, construct_params(id: sample_user.id)
    assert_response 200
    res = JSON.parse(response.body)
    assert_equal Helpdesk::Source.default_ticket_source_token_by_key[2].to_s, res['preferred_source']
  end

  def test_show_a_contact_without_preferred_source
    sample_user = add_new_user(@account)
    get :show, construct_params(id: sample_user.id)
    assert_response 200
    res = JSON.parse(response.body)
    assert_nil res['preferred_source']
  end

  def test_show_a_non_existing_contact
    sample_user = add_new_user(@account)
    get :show, construct_params(id: 0)
    assert_response :missing
  end

  # Create User
  def test_create_contact
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email)
    assert_response 201
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_without_name
    post :create, construct_params({},  email: Faker::Internet.email)
    match_json([bad_request_error_pattern('name', :missing_field)])
    assert_response 400
  end

  def test_create_contact_without_name_when_non_mandatory
    name_field = Account.current.contact_form.default_fields.find_by_name('name')
    name_field.required_for_agent = false
    name_field.save!
    Account.current.reload
    post :create, construct_params({},  email: Faker::Internet.email)
    assert_response 201
  ensure
    name_field.required_for_agent = true
    name_field.save!
    Account.current.reload
  end

  def test_create_contact_tags_with_comma
    post :create, construct_params({},  email: Faker::Internet.email, name: Faker::Lorem.characters(10), tags: ['test,,,,comma', 'test'])
    match_json([bad_request_error_pattern('tags', :special_chars_present, chars: ',')])
    assert_response 400
  end

  def test_create_contact_without_any_contact_detail
    post :create, construct_params({},  name: Faker::Lorem.characters(10))
    match_json([bad_request_error_pattern('email', :fill_a_mandatory_field, field_names: 'email, mobile, phone, twitter_id')])
    assert_response 400
  end

  def test_create_contact_with_existing_email
    email = Faker::Internet.email
    user = add_new_user(@account, name: Faker::Lorem.characters(15), email: email)
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: email)
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['user_id'], user.id
    match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'has already been taken')])
    assert_response 409
  end

  def test_create_contact_with_existing_twitter_id
    twitter_id = Faker::Lorem.characters(10)
    user = add_new_user_with_twitter_id(@account, name: Faker::Lorem.characters(15), twitter_id: twitter_id)
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        twitter_id: twitter_id)
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['user_id'], user.id
    match_json([bad_request_error_pattern_with_additional_info('twitter_id', additional_info, :'has already been taken')])
    assert_response 409
  end

  def test_create_contact_with_existing_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    unique_external_id = Faker::Lorem.characters(10)
    user = add_new_user(@account, name: Faker::Lorem.characters(15), unique_external_id: unique_external_id)
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        unique_external_id: unique_external_id)
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_equal additional_info['user_id'], user.id
    match_json([bad_request_error_pattern_with_additional_info('unique_external_id', additional_info, :'has already been taken')])
    assert_response 409
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_create_contact_with_prohibited_email
    post :create, construct_params({},  name: Faker::Name.name,
                                        email: 'mailer-daemon@gmail.com')
    assert_response 201
    match_json(deleted_contact_pattern(User.last))
    assert User.last.deleted == true
  end

  def test_create_contact_with_invalid_client_manager
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: 'String',
                                        company_id: comp.id)
    match_json([bad_request_error_pattern('view_all_tickets', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_create_contact_with_client_manager_without_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true)
    match_json([bad_request_error_pattern('company_id', :company_id_required, code: :missing_field)])
    assert_response 400
  end

  def test_create_contact_with_valid_client_manager
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id)
    assert User.last.user_companies.select{|x| x.company_id == comp.id}.first.client_manager == true
    assert_response 201
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_with_invalid_language_and_timezone
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: Faker::Lorem.characters(5),
                                        time_zone: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('language', :not_included,
                                          list: I18n.available_locales.map(&:to_s).join(',')),
                bad_request_error_pattern('time_zone', :not_included, list: ActiveSupport::TimeZone.all.map(&:name).join(','))])
    assert_response 400
  end

  def test_create_contact_with_language_and_timezone_without_feature
    comp = get_company
    Account.any_instance.stubs(:multi_timezone_enabled?).returns(false)
    Account.any_instance.stubs(:features?).with(:multi_language).returns(false)
    Account.any_instance.stubs(:features?).with(:multiple_user_companies).returns(false)
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: Faker::Lorem.characters(5),
                                        time_zone: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('language', :require_feature_for_attribute, code: :inaccessible_field, attribute: 'language', feature: :multi_language),
                bad_request_error_pattern('time_zone', :require_feature_for_attribute, code: :inaccessible_field, attribute: 'time_zone', feature: :multi_timezone)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:multi_timezone_enabled?)
    Account.any_instance.unstub(:features?)
  end

  def test_create_contact_with_valid_language_and_timezone
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        time_zone: 'Mountain Time (US & Canada)')
    assert_response 201
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_with_default_language
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        time_zone: 'Mountain Time (US & Canada)')
    assert_response 201
    match_json(deleted_contact_pattern(User.last))
    assert_equal User.last.language, @account.language
  end

  def test_create_contact_with_invalid_tags
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        tags: 'tag1, tag2, tag3')
    match_json([bad_request_error_pattern('tags', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_create_contact_with_invalid_avatar
    comp = get_company
    params = {  name: Faker::Lorem.characters(15),
                email: Faker::Internet.email,
                view_all_tickets: true,
                company_id: comp.id,
                language: 'en',
                avatar: Faker::Internet.email }
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('avatar', :datatype_mismatch, expected_data_type: 'valid file format', prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_create_contact_with_invalid_avatar_file_type
    file = fixture_file_upload('files/attachment.txt', 'plain/text', :binary)
    comp = get_company
    params = {  name: Faker::Lorem.characters(15),
                email: Faker::Internet.email,
                view_all_tickets: true,
                company_id: comp.id,
                language: 'en',
                avatar: file }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({},  params)
    DataTypeValidator.any_instance.unstub(:valid_type?)
    match_json([bad_request_error_pattern('avatar', :upload_jpg_or_png_file, current_extension: '.txt')])
    assert_response 400
  end

  def test_create_contact_with_invalid_avatar_file_size
    file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
    params = {  name: Faker::Lorem.characters(15), email: Faker::Internet.email, view_all_tickets: true, company_id: 1,
                language: 'en', avatar: file }
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('avatar', :invalid_size, max_size: '5 MB', current_size: '19.1 MB')])
    assert_response 400
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
    Rack::Test::UploadedFile.any_instance.unstub(:size)
  end

  def test_create_contact_with_invalid_field_in_custom_fields
    comp = get_company
    params = {  name: Faker::Lorem.characters(15),
                email: Faker::Internet.email,
                view_all_tickets: true,
                company_id: comp.id,
                language: 'en',
                custom_fields: { dummyfield: Faker::Lorem.characters(20) } }
    post :create, construct_params({},  params)
    match_json([bad_request_error_pattern('dummyfield', :invalid_field)])
    assert_response 400
  end

  def test_create_contact_with_tags_avatar_and_custom_fields
    cf_dept = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Department', editable_in_signup: 'true'))
    tags = [Faker::Name.name, Faker::Name.name]
    file = fixture_file_upload('files/image33kb.jpg')
    comp = get_company
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        tags: tags,
                                        avatar: file,
                                        custom_fields: { 'department' => 'Sample Dept' })
    match_json(deleted_contact_pattern(User.last))
    assert User.last.avatar.content_content_type == 'image/jpeg'
    assert_response 201
  ensure
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  # Custom fields validation during creation
  def test_create_contact_with_custom_fields
    comp = get_company
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Department', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Sample check box', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Another check box', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'sample_date', editable_in_signup: 'true'))

    create_contact_field(cf_params(type: 'text', field_type: 'custom_dropdown', label: 'sample_dropdown', editable_in_signup: 'true'))
    ContactFieldChoice.create(value: 'Choice 1', position: 1)
    ContactFieldChoice.create(value: 'Choice 2', position: 2)
    ContactFieldChoice.create(value: 'Choice 3', position: 3)
    ContactFieldChoice.update_all(account_id: @account.id)
    ContactFieldChoice.update_all(contact_field_id: ContactField.find_by_name('cf_sample_dropdown').id)

    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        custom_fields: { 'department' => 'Sample Dept', 'sample_check_box' => true, 'another_check_box' => false, 'sample_date' => '2010-11-01', 'sample_dropdown' => 'Choice 1' })
    assert_response 201
    assert User.last.custom_field['cf_sample_check_box'] == true
    assert User.last.custom_field['cf_another_check_box'] == false
    assert User.last.custom_field['cf_department'] == 'Sample Dept'
    assert User.last.custom_field['cf_sample_date'].to_date == Date.parse('2010-11-01')
    assert User.last.custom_field['cf_sample_dropdown'] == 'Choice 1'
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_contact_with_invalid_custom_url_and_custom_date
    create_contact_field(cf_params(type: 'url', field_type: 'custom_url', label: 'Sample URL', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'Sample Date', editable_in_signup: 'true'))
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        custom_fields: { 'sample_url' => 'aaaa', 'sample_date' => '2015-09-09T08:00' })
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('sample_date'), :invalid_date, accepted: 'yyyy-mm-dd'),
                bad_request_error_pattern(custom_field_error_label('sample_url'), :invalid_format, accepted: 'valid URL')])
  end

  def test_create_contact_without_required_custom_fields
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))

    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email)

    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('code'), :datatype_mismatch, code: :missing_field, expected_data_type: String)])
    ensure
      cf.delete
  end

  def test_create_contact_with_invalid_custom_fields
    comp = get_company
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Check Me', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'DOJ', editable_in_signup: 'true'))

    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        custom_fields: { 'check_me' => 'aaa', 'doj' => 2010 })
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('check_me'), :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(custom_field_error_label('doj'), :invalid_date, accepted: 'yyyy-mm-dd')])
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
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        custom_fields: { 'choose_me' => 'Choice 4' })
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('choose_me'), :not_included, list: 'Choice 1,Choice 2,Choice 3')])
  end

  def test_create_length_invalid
    post :create, construct_params({}, name: Faker::Lorem.characters(300), job_title: Faker::Lorem.characters(300), mobile: Faker::Lorem.characters(300), address: Faker::Lorem.characters(300), email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com", twitter_id: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(34)])
    match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('job_title', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('mobile', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('address', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('email', :'Has 328 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('twitter_id', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('phone', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('tags', :'It should only contain elements that have maximum of 32 characters')])
    assert_response 400
  end

  def test_create_length_valid_with_trailing_spaces
    params = { name: Faker::Lorem.characters(20) + white_space, job_title: Faker::Lorem.characters(20) + white_space, mobile: Faker::Lorem.characters(20) + white_space, address: Faker::Lorem.characters(20) + white_space, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space, twitter_id: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space] }
    post :create, construct_params({}, params)
    match_json(deleted_contact_pattern(User.last))
    assert_response 201
  end

  def test_create_duplicate_tags
    @account.tags.create(name: 'existingtag')
    @account.tags.create(name: 'TestCapsTag')
    params = { name: Faker::Lorem.characters(20), tags: ['newtag', '<1>newtag', 'existingtag', 'testcapstag', '<2>existingtag', 'ExistingTag', 'NEWTAG'],
               email: Faker::Internet.email }
    assert_difference 'Helpdesk::Tag.count', 1 do # only new should be inserted.
      assert_difference 'Helpdesk::TagUse.count', 3 do # duplicates should be rejected
        post :create, construct_params({}, params)
      end
    end
    params[:tags] = %w(newtag existingtag TestCapsTag)
    u = User.last
    match_json(deleted_contact_pattern(params, u))
    match_json(deleted_contact_pattern({}, u))
    assert_response 201
  end

  def test_create_user_active
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        active: true)
    assert_response 201
  end

  def test_create_user_active_string
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        active: "mystring")
    assert_response 400
  end

  def test_create_user_active_false
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        active: false)
    match_json([bad_request_error_pattern('active', "Active field can only be set to true")])
    assert_response 400
  end

  def test_create_deleted_user_activate
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        deleted: true,
                                        active: true)
    assert_response 400
  end

  def test_create_blocked_user_activate
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        blocked: true,
                                        active: true)
    assert_response 400
  end

  # Update user
  def test_update_user_with_blank_name
    params_hash  = { name: '' }
    sample_user = add_new_user(@account)
    sample_user.update_attribute(:phone, '1234567890')
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('name', :blank)])
  end

  def test_update_contact_tags_with_comma
    params_hash = { tags: ['test,,,,comma', 'test'] }
    put :update, construct_params({ id: add_new_user(@account).id }, params_hash)
    match_json([bad_request_error_pattern('tags', :special_chars_present, chars: ',')])
    assert_response 400
  end

  def test_update_user_without_any_contact_detail
    params_hash = { phone: '', mobile: '', twitter_id: '' }
    sample_user = add_new_user(@account)
    email = sample_user.email
    sample_user.update_attribute(:fb_profile_id, nil)
    sample_user.update_attribute(:email, nil)
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('mobile', :fill_a_mandatory_field, code: :invalid_value, field_names: 'email, mobile, phone, twitter_id')])
    sample_user.update_attribute(:email, email)
  end

  def test_update_user_with_valid_params
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'city', editable_in_signup: 'true'))
    tags = [Faker::Name.name, Faker::Name.name, 'tag_sample_test_3']
    cf = { 'city' => 'Chennai' }

    sample_user = User.where(helpdesk_agent: false).last
    params_hash = { language: 'cs',
                    time_zone: 'Tokyo',
                    job_title: 'emp',
                    custom_fields: cf,
                    tags: tags }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert sample_user.reload.language == 'cs'
    assert sample_user.reload.time_zone == 'Tokyo'
    assert sample_user.reload.job_title == 'emp'
    assert sample_user.reload.tag_names.split(', ').sort == tags.sort
    assert sample_user.reload.custom_field['cf_city'] == 'Chennai'
    match_json(deleted_contact_pattern(sample_user.reload))
    assert_response 200
  end

  def test_update_contact_with_valid_company_id_and_client_manager
    comp = get_company
    sample_user = add_new_user(@account)
    params_hash = { company_id: comp.id, view_all_tickets: true }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert sample_user.reload.user_companies.select{|x| x.default }.first.client_manager == true
    assert sample_user.reload.company_id == comp.id
    match_json(deleted_contact_pattern(sample_user.reload))
  end

  def test_update_client_manager_with_negative_company_id
    sample_user = add_new_user(@account)
    params_hash = { company_id: -1 }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      'company_id', :datatype_mismatch,
      code: :invalid_value, expected_data_type: 'Positive Integer' )]
    )
  end

  def test_update_client_manager_with_invalid_company_id
    sample_user = add_new_user(@account)
    sample_user.user_companies.each { |ua| ua.destroy }
    sample_user.reload
    comp = get_company
    params_hash = { company_id: comp.id, view_all_tickets: true, phone: '1234567890' }
    sample_user.update_attributes(params_hash)
    sample_user.reload
    params_hash = { company_id: nil }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    match_json(deleted_contact_pattern(params_hash, sample_user.reload))
    assert sample_user.reload.company_id == nil
    assert sample_user.reload.client_manager == false
  end

  def test_update_contact_with_valid_company_id_again
    sample_user = add_new_user(@account)
    comp = get_company
    params_hash = { company_id: comp.id, view_all_tickets: true, phone: '1234567890' }
    sample_user.update_attributes(params_hash)
    sample_user.reload
    company = Company.create(name: Faker::Name.name, account_id: @account.id)
    params_hash = { company_id: company.id }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    match_json(deleted_contact_pattern(sample_user.reload))
    assert sample_user.reload.company_id == company.id
    assert sample_user.reload.client_manager == false
  end

  def test_update_client_manager_with_unavailable_company_id
    sample_user = add_new_user(@account)
    sample_user.update_attribute(:client_manager, false)
    sample_user.update_attribute(:company_id, nil)
    params_hash = { company_id: 10_000 }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 400
    assert sample_user.reload.company_id.nil?
    match_json([bad_request_error_pattern('company_id', :absent_in_db, resource: :company, attribute: :company_id)])
  end

  def test_update_client_manager_with_unavailable_company_id_with_existing_company_id
    sample_user = add_new_user(@account)
    sample_user.update_attribute(:client_manager, false)
    sample_user.update_attribute(:company_id, Company.first.id)
    params_hash = { company_id: 10_000 }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('company_id', :absent_in_db, resource: :company, attribute: :company_id)])
  end

  def test_update_email_when_email_is_not_nil
    sample_user = add_new_user(@account)
    email = 'sample_' + Time.zone.now.to_i.to_s + '@sampledomain.com'
    params_hash = { email: email }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    match_json(deleted_contact_pattern(sample_user.reload))
    assert sample_user.reload.email == email
  end

  def test_update_email_when_email_is_nil
    sample_user = add_new_user(@account)
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    email = Faker::Internet.email
    params_hash = { email: email }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert sample_user.reload.email == email
    sample_user.update_attribute(:email, email)
  end

  def test_update_contact_with_existing_twitter_id
    twitter_id = Faker::Lorem.characters(10)
    user1 = add_new_user_with_twitter_id(@account, twitter_id: twitter_id)
    user2 = add_new_user_without_email(@account)
    put :update, construct_params({ id: user2.id }, twitter_id: twitter_id)
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_response 409
    assert_equal additional_info['user_id'], user1.id
    match_json([bad_request_error_pattern_with_additional_info('twitter_id', additional_info, :'has already been taken')])
  end

  def test_update_contact_with_existing_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    unique_external_id = Faker::Lorem.characters(10)
    user1 = add_new_user(@account, unique_external_id: unique_external_id)
    user2 = add_new_user_without_email(@account)
    put :update, construct_params({ id: user2.id }, unique_external_id: unique_external_id)
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_response 409
    assert_equal additional_info['user_id'], user1.id
    match_json([bad_request_error_pattern_with_additional_info('unique_external_id', additional_info, :'has already been taken')])
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_update_the_email_of_a_contact_with_user_email
    user1 = add_new_user(@account)
    user2 = add_new_user_without_email(@account)
    email = user1.email
    put :update, construct_params({ id: user2.id }, email: email)
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    assert_response 409
    assert_equal additional_info['user_id'], user1.id
    match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'has already been taken')])
  end

  def test_update_length_invalid
    sample_user = add_new_user(@account)
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    put :update, construct_params({ id: sample_user.id }, name: Faker::Lorem.characters(300), job_title: Faker::Lorem.characters(300), mobile: Faker::Lorem.characters(300), address: Faker::Lorem.characters(300), email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com", twitter_id: Faker::Lorem.characters(300), phone: Faker::Lorem.characters(300), tags: [Faker::Lorem.characters(34)])
    match_json([bad_request_error_pattern('name', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('job_title', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('mobile', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('address', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('email', :'Has 328 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('twitter_id', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('phone', :'Has 300 characters, it can have maximum of 255 characters'),
                bad_request_error_pattern('tags', :'It should only contain elements that have maximum of 32 characters')])
    assert_response 400
    sample_user.update_attribute(:email, email)
  end

  def test_update_contact_with_language_and_timezone_without_feature
    sample_user = add_new_user(@account)
    Account.any_instance.stubs(:multi_timezone_enabled?).returns(false)
    Account.any_instance.stubs(:features?).with(:multi_language).returns(false)
    Account.any_instance.stubs(:features?).with(:multiple_user_companies).returns(false)
    put :update, construct_params({ id: sample_user.id },
                                  language: Faker::Lorem.characters(5),
                                  time_zone: Faker::Lorem.characters(5))
    match_json([bad_request_error_pattern('language', :require_feature_for_attribute, code: :inaccessible_field, attribute: 'language', feature: :multi_language),
                bad_request_error_pattern('time_zone', :require_feature_for_attribute, code: :inaccessible_field, attribute: 'time_zone', feature: :multi_timezone)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:multi_timezone_enabled?)
    Account.any_instance.unstub(:features?)
  end

  def test_update_length_valid_with_trailing_space
    sample_user = add_new_user(@account)
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    params = { name: Faker::Lorem.characters(20) + white_space, job_title: Faker::Lorem.characters(20) + white_space, mobile: Faker::Lorem.characters(20) + white_space, address: Faker::Lorem.characters(20) + white_space, email: "#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(20)}.com" + white_space, twitter_id: Faker::Lorem.characters(20) + white_space, phone: Faker::Lorem.characters(20) + white_space, tags: [Faker::Lorem.characters(20) + white_space] }
    put :update, construct_params({ id: sample_user.id }, params)
    match_json(deleted_contact_pattern(sample_user.reload))
    assert_response 200
    sample_user.update_attribute(:email, email)
  end

  def test_update_user_created_with_fb_id
    sample_user = add_new_user(@account)
    params_hash = { mobile: '', email: '', phone: '', twitter_id: '', fb_profile_id: 'profile_id_1' }
    sample_user.update_attributes(params_hash)
    email = Faker::Internet.email
    put :update, construct_params({ id: sample_user.id }, name: 'sample_user', email: email)
    assert_response 200
    assert sample_user.reload.email == email
    assert sample_user.reload.name == 'sample_user'
  end

  def test_update_user_active
    sample_user = add_new_user(@account)
    email = Faker::Internet.email
    params_hash = { name: 'New Name', email: email }
    sample_user.update_attributes(params_hash)
    sample_user.active = false
    sample_user.save
    put :update, construct_params({ id: sample_user.id }, active: true)
    assert_response 200
    assert sample_user.reload.active == true
  end

  def test_update_user_active_false
    sample_user = add_new_user(@account)
    email = Faker::Internet.email
    params_hash = { name: 'New Name', email: email }
    sample_user.update_attributes(params_hash)
    
    put :update, construct_params({ id: sample_user.id }, active: false)
    match_json([bad_request_error_pattern('active', "Active field can only be set to true")])
    assert_response 400
  end

  def test_update_user_active_string
    sample_user = add_new_user(@account)
    email = Faker::Internet.email
    params_hash = { name: 'New Name', email: email }
    sample_user.update_attributes(params_hash)
    
    put :update, construct_params({ id: sample_user.id }, active: "mystring")
    assert_response 400
  end

  def test_update_deleted_user_active
    sample_user = add_new_user(@account)
    email = Faker::Internet.email
    params_hash = { name: 'New Name', email: email, deleted: 1 }
    sample_user.update_attributes(params_hash)
    put :update, construct_params({ id: sample_user.id }, active: true)
    assert_response 405
  end

  def test_update_blocked_user_active
    sample_user = add_new_user(@account)
    email = Faker::Internet.email
    params_hash = { name: 'New Name', email: email}
    sample_user.update_attributes(params_hash)
    sample_user.update_column(:blocked, true)
    put :update, construct_params({ id: sample_user.id }, active: true)
    assert_response 405
  end


  # Delete user
  def test_delete_contact
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, false)
    delete :destroy, construct_params(id: sample_user.id)
    assert_response 204
    assert sample_user.reload.deleted == true
  end

  def test_delete_a_deleted_contact
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, true)
    delete :destroy, construct_params(id: sample_user.id)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'DELETE'))
    assert_equal 'GET', response.headers['Allow']
  ensure
    sample_user.update_column(:deleted, false)
  end

  def test_delete_a_blocked_contact
    sample_user = add_new_user(@account)
    sample_user.update_column(:blocked, true)
    delete :destroy, construct_params(id: sample_user.id)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'DELETE'))
    assert_equal 'GET', response.headers['Allow']
  ensure
    sample_user.update_column(:blocked, false)
  end

  def test_update_a_deleted_contact
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, true)
    params_hash = { language: 'cs' }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'PUT'))
    assert_equal 'GET', response.headers['Allow']
  ensure
    sample_user.update_column(:deleted, false)
  end

  def test_update_a_blocked_contact
    sample_user = add_new_user(@account)
    sample_user.update_column(:blocked, true)
    params_hash = { language: 'cs' }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 405
    response.body.must_match_json_expression(base_error_pattern('method_not_allowed', methods: 'GET', fired_method: 'PUT'))
    assert_equal 'GET', response.headers['Allow']
  ensure
    sample_user.update_column(:blocked, false)
  end

  def test_show_a_deleted_contact
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, true)
    get :show, construct_params(id: sample_user.id)
    match_json(deleted_contact_pattern(sample_user.reload))
    assert_response 200
  end

  #hard delete user
  def test_hard_delete_a_normal_user
    sample_user = add_new_user(@account)
    delete :hard_delete, construct_params(id: sample_user.id)
    assert_response 400
  end

  def test_hard_delete_a_deleted_user
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, true)
    delete :hard_delete, construct_params(id: sample_user.id)
    assert_response 204
  end

  def test_hard_delete_a_non_existing_user
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, true)
    delete :hard_delete, construct_params(id: sample_user.id + 100)
    assert_response 404
  end

  # User Index and Filters
  def test_contact_index
    @account.all_contacts.update_all(deleted: false)
    @account.all_contacts.update_all(blocked: false)
    sample_user = @account.all_contacts.first
    sample_user.update_attribute(:blocked, true)
    get :index, controller_params
    assert_response 200
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false && x.blocked == false }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  end

  def test_contact_index_all_blocked
    @account.all_contacts.update_all(deleted: false)
    @account.all_contacts.update_all(blocked: true)
    get :index, controller_params
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size
    @account.all_contacts.update_all(blocked: false)
  end

  def test_contact_filter
    @account.all_contacts.update_all(deleted: true)
    @account.all_contacts.first.update_column(:deleted, false)
    get :index, controller_params
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  ensure
    @account.all_contacts.update_all(deleted: false)
  end

  def test_contact_filter_state_blocked
    @account.all_contacts.update_all(whitelisted: false)
    @account.all_contacts.update_all(blocked: true)
    @account.all_contacts.update_all(blocked_at: Time.zone.now)
    @account.all_contacts.first.update_attribute(:whitelisted, true)
    count = @account.all_contacts.count - 1
    get :index, controller_params(state: 'blocked')
    assert_response 200
    response = parse_response @response.body
    assert_equal count, response.size
    users = @account.all_contacts.order('users.name').select { |x| ((x.deleted == true && x.deleted_at <= Time.zone.now + 5.days) || (x.blocked == true && x.blocked_at <= Time.zone.now + 5.days)) && x.whitelisted == false }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  ensure
    @account.all_contacts.update_all(blocked: false)
    @account.all_contacts.update_all(whitelisted: false)
  end

  def test_contact_filter_state_blocked_with_deleted_contact
    @account.all_contacts.update_all(whitelisted: false)
    @account.all_contacts.update_all(deleted: true)
    @account.all_contacts.update_all(deleted_at: Time.zone.now)
    @account.all_contacts.first.update_attribute(:whitelisted, true)
    count = @account.all_contacts.count - 1
    get :index, controller_params(state: 'blocked')
    assert_response 200
    response = parse_response @response.body
    assert_equal count, response.size
    users = @account.all_contacts.order('users.name').select { |x| ((x.deleted == true && x.deleted_at <= Time.zone.now + 5.days) || (x.blocked == true && x.blocked_at <= Time.zone.now + 5.days)) && x.whitelisted == false }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  ensure
    @account.all_contacts.update_all(deleted: false)
    @account.all_contacts.update_all(whitelisted: false)
  end

  def test_contact_filter_state_blocked_whitelisted_true
    @account.all_contacts.update_all(whitelisted: true)
    @account.all_contacts.update_all(blocked: true)
    @account.all_contacts.update_all(blocked_at: Time.zone.now)
    get :index, controller_params(state: 'blocked')
    assert_response 200
    response = parse_response @response.body
    assert_equal 0, response.size
    @account.all_contacts.update_all(blocked: false)
    @account.all_contacts.update_all(whitelisted: false)
  ensure
    @account.all_contacts.update_all(blocked: false)
  end

  def test_contact_filter_phone
    @account.all_contacts.update_all(phone: nil)
    @account.all_contacts.first.update_column(:phone, '1234567890')
    get :index, controller_params(phone: '1234567890')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = @account.all_contacts.order('users.name').select { |x|  x.phone == '1234567890' }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  end

  def test_contact_filter_mobile
    @account.all_contacts.update_all(mobile: nil)
    @account.all_contacts.first.update_column(:mobile, '1234567890')
    get :index, controller_params(mobile: '1234567890')
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = @account.all_contacts.order('users.name').select { |x|  x.mobile == '1234567890' }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  end

  def test_contact_filter_email
    @account.all_contacts.update_all(email: nil)
    email = Faker::Internet.email
    @account.all_contacts.first.update_column(:email, email)
    @account.all_contacts.first.primary_email.update_column(:email, email)
    get :index, controller_params(email: email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = @account.all_contacts.order('users.name').select { |x|  x.email == email }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  end

  def test_contact_filter_secondary_email
    email = Faker::Internet.email
    @account.all_contacts.first.user_emails.create(email: email)
    get :index, controller_params(email: email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = [@account.user_emails.find_by_email(email).user]
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern)
  end

  def test_contact_filter_company_id
    comp = get_company
    @account.all_contacts.find_each do |contact|
      contact.update_attributes({:customer_id => nil, :deleted => false})
    end
    @account.all_contacts.first.update_attribute(:company_id, comp.id)
    get :index, controller_params(company_id: "#{comp.id}")
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = @account.all_contacts.order('users.name').select { |x|  x.customer_id == comp.id }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  end

  def test_contact_filter_updated_at
    update_timestamp = Time.now.utc.iso8601.to_datetime
    @account.all_contacts.first.update_column(:updated_at, update_timestamp)
    get :index, controller_params(_updated_since: update_timestamp)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = @account.all_contacts.order('users.name').select { |x|  x.updated_at == update_timestamp }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  end

  def test_contact_combined_filter
    email = Faker::Internet.email
    comp = get_company
    @account.all_contacts.find_each do |contact|
      contact.update_attributes({:customer_id => nil})
    end
    @account.all_contacts.first.update_attribute(:company_id, comp.id)
    @account.all_contacts.first.user_emails.create(email: email)
    @account.all_contacts.last.update_column(:customer_id, comp.id)
    get :index, controller_params(company_id: "#{comp.id}", email: email)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  end

  def test_contact_filter_invalid
    get :index, controller_params(customer_id: 1)
    assert_response 400
    match_json([bad_request_error_pattern('customer_id', :invalid_field)])
  end

  def test_contact_filter_invalid_company_id
    comp = get_company
    @account.all_contacts.update_all(customer_id: nil)
    @account.all_contacts.first.update_column(:customer_id, comp.id)
    get :index, controller_params(company_id: 'a')
    assert_response 400
    match_json [bad_request_error_pattern('company_id', :datatype_mismatch, expected_data_type: 'Positive Integer')]
  end

  def test_contact_filter_invalid_updated_at
    get :index, controller_params(_updated_since: 'Invalid String')
    assert_response 400
    match_json [bad_request_error_pattern('_updated_since', :invalid_date, accepted: 'combined date and time ISO8601')]
  end

  def test_contact_filter_invalid_nil_updated_at
    get :index, controller_params(_updated_since: nil)
    assert_response 400
    match_json [bad_request_error_pattern('_updated_since', :invalid_date, accepted: 'combined date and time ISO8601')]
  end

  def test_contact_blocked_in_future_should_not_be_listed_in_the_index
    current_timezone = Time.zone
    current_agent_timezone = @agent.time_zone
    Time.zone = 'Astana'
    @agent.time_zone = 'Astana'
    sample_user = add_new_user(@account)
    sample_user.update_attribute(:blocked, true)
    sample_user.update_attribute(:blocked_at, Time.zone.now + 5.days + 3.hours)
    sample_user.update_attribute(:whitelisted, false)
    get :index, controller_params(state: 'blocked')
    assert_response 200
    assert @response.body !~ /#{sample_user.email}/
  ensure
    sample_user.update_attribute(:blocked, false)
    sample_user.update_attribute(:blocked_at, nil)
    Time.zone = current_timezone
    @agent.time_zone = current_agent_timezone
  end

  def test_contact_index_deleted_filter
    @account.all_contacts.update_all(deleted: false)
    @account.all_contacts.last.update_attributes(deleted: true)
    @account.all_contacts.first.update_attributes(deleted: true)
    get :index, controller_params(state: 'deleted')
    assert_response 200
    response = parse_response @response.body
    assert_equal 2, response.size
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == true }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  ensure
    @account.all_contacts.update_all(deleted: false)
  end

  def test_contact_index_with_include_company_params
    sample_user = get_user_with_default_company
    company_ids = Company.all.map(&:id) - sample_user.company_ids
    sample_user.user_companies.build(company_id: company_ids.first, client_manager: true)
    sample_user.user_companies.build(company_id: company_ids.last, client_manager: true)
    sample_user.save
    get :index, controller_params(include: 'company')
    assert_response 200
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false && x.blocked == false }
    pattern = users.map { |user| index_contact_pattern(user, { include: 'company' }) }
    match_json(pattern.ordered!)
  end

  def test_contact_index_without_include_company_params
    sample_user = get_user_with_default_company
    company_ids = Company.all.map(&:id) - sample_user.company_ids
    sample_user.user_companies.build(company_id: company_ids.first, client_manager: true)
    sample_user.user_companies.build(company_id: company_ids.last, client_manager: true)
    sample_user.save
    get :index, controller_params
    assert_response 200
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false && x.blocked == false }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  end

  # Make agent out of a user
  def test_make_agent
    assert_difference 'Agent.count', 1 do
      sample_user = add_new_user(@account)
      @controller.stubs(:agent_limit_reached?).returns(false)
      put :make_agent, construct_params(id: sample_user.id)
      assert_response 200
      assert sample_user.reload.helpdesk_agent == true
      assert Agent.last.user.id == sample_user.id
      assert Agent.last.occasional == false
    end
  ensure
    @controller.unstub(:agent_limit_reached?)
  end

  def test_make_agent_with_params
    assert_difference 'Agent.count', 1 do
      sample_user = add_new_user(@account)
      role_ids = Role.limit(2).pluck(:id)
      group_ids = [create_group(@account).id]
      @controller.stubs(:agent_limit_reached?).returns(false)
      params = { occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2, role_ids: role_ids, group_ids: group_ids }
      put :make_agent, construct_params({ id: sample_user.id }, params)
      assert_response 200
      assert sample_user.reload.helpdesk_agent == true
      match_json(make_agent_pattern({}, sample_user))
      match_json(make_agent_pattern(params, sample_user))
      assert Agent.last.user.id == sample_user.id
      assert Agent.last.occasional == false
    end
  ensure
    @controller.unstub(:agent_limit_reached?)
  end

  def test_make_agent_with_invalid_params
    sample_user = add_new_user(@account)
    put :make_agent, construct_params({ id: sample_user.id }, job_title: 'Employee')
    assert_response 400
    match_json([bad_request_error_pattern(:job_title, :invalid_field)])
  end

  def test_make_agent_with_inaccessible_fields
    role_ids = Role.limit(2).pluck(:id)
    params = { ticket_scope: 2, role_ids: role_ids }
    put :make_agent, construct_params({ id: @agent.id }, params)
    assert_response 404
  end

  def test_make_agent_with_array_fields_invalid
    sample_user = add_new_user(@account)
    params = { role_ids: '1,2', group_ids: '34,4', occasional: true }
    put :make_agent, construct_params({ id: sample_user.id }, params)
    match_json([bad_request_error_pattern(:role_ids, :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(:group_ids, :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_make_agent_with_array_fields_invalid_model
    sample_user = add_new_user(@account)
    params = { role_ids: [123, 567], group_ids: [466, 566], occasional: true }
    put :make_agent, construct_params({ id: sample_user.id }, params)
    match_json([bad_request_error_pattern(:role_ids, :invalid_list, list: params[:role_ids].join(', ')),
                bad_request_error_pattern(:group_ids, :invalid_list, list: params[:group_ids].join(', '))])
    assert_response 400
  end

  def test_make_agent_without_any_groups
    sample_user = add_new_user(@account)
    params = { group_ids: [] }
    put :make_agent, construct_params({ id: sample_user.id }, params)
    assert_response 200
    refute AgentGroup.exists?(user_id: sample_user.id)
  end

  def test_make_agent_with_only_role_ids
    sample_user = add_new_user(@account)
    roles = Role.limit(2)
    params = { role_ids: roles.map(&:id) }
    put :make_agent, construct_params({ id: sample_user.id }, params)
    updated_agent = User.find(sample_user.id)
    assert updated_agent.union_privileges(roles).to_s, updated_agent.privileges
    assert_response 200
  end

  def test_make_agent_with_string_enumerators_for_level_and_scope
    sample_user = add_new_user(@account)
    params = { ticket_scope: '2' }
    put :make_agent, construct_params({ id: sample_user.id }, params)
    match_json([bad_request_error_pattern(:ticket_scope, :not_included, code: :datatype_mismatch, list: Agent::PERMISSION_TOKENS_BY_KEY.keys.join(','), prepend_msg: :input_received, given_data_type: String)])
    assert_response 400
  end

  def test_make_agent_with_agent_limit_reached_invalid
    sample_user = add_new_user(@account)
    role_ids = Role.limit(2).pluck(:id)
    group_ids = [create_group(@account).id]
    Subscription.any_instance.stubs(:agent_limit).returns(@account.full_time_support_agents.count - 1)
    DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
    params = { occasional: false, signature: Faker::Lorem.paragraph, ticket_scope: 2, role_ids: role_ids, group_ids: group_ids }
    put :make_agent, construct_params({ id: sample_user.id }, params)
    match_json([bad_request_error_pattern(:occasional, :max_agents_reached, code: :incompatible_value, max_count: (@account.full_time_support_agents.count - 1))])
    assert_response 400
  ensure
    Subscription.any_instance.unstub(:agent_limit)
    DataTypeValidator.any_instance.unstub(:valid_type?)
  end

  def test_make_agent_with_occasional_valid
    assert_difference 'Agent.count', 1 do
      sample_user = add_new_user(@account)
      put :make_agent, construct_params({ id: sample_user.id }, occasional: true)
      assert_response 200
      assert sample_user.reload.helpdesk_agent == true
      assert Agent.last.user.id == sample_user.id
      assert Agent.last.occasional == true
    end
  end

  def test_make_agent_with_occasional_invalid
    sample_user = add_new_user(@account)
    put :make_agent, construct_params({ id: sample_user.id }, occasional: 'true')
    assert_response 400
    match_json([bad_request_error_pattern(:occasional, :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
  end

  def test_make_agent_out_of_a_user_without_email
    @account.subscription.update_column(:agent_limit, nil)
    sample_user = add_new_user(@account)
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    put :make_agent, construct_params(id: sample_user.id)
    assert_response 409
    sample_user.update_attribute(:email, email)
    match_json(request_error_pattern(:inconsistent_state))
    sample_user.update_attribute(:email, email)
  end

  def test_make_agent_with_invalid_params_out_of_a_user_without_email
    @account.subscription.update_column(:agent_limit, nil)
    sample_user = add_new_user(@account)
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    params = { occasional: 'false', signature: Faker::Lorem.paragraph, ticket_scope: '2', role_ids: [1234], group_ids: [2_344_234] }
    put :make_agent, construct_params({ id: sample_user.id }, params)
    assert_response 409
    sample_user.update_attribute(:email, email)
    match_json(request_error_pattern(:inconsistent_state))
    sample_user.update_attribute(:email, email)
  end

  def test_make_agent_out_of_a_user_beyond_agent_limit
    @account.subscription.update_column(:agent_limit, 1)
    sample_user = add_new_user(@account)
    put :make_agent, construct_params(id: sample_user.id)
    assert_response 403
    match_json(request_error_pattern(:max_agents_reached, max_count: 1))
  end

  def test_make_agent_out_of_a_user_without_email_and_beyond_agent_limit
    @account.subscription.update_column(:agent_limit, 1)
    sample_user = add_new_user(@account)
    email = sample_user.email
    sample_user.update_attribute(:email, nil)
    put :make_agent, construct_params(id: sample_user.id)
    assert_response 409
    sample_user.update_attribute(:email, email)
    match_json(request_error_pattern(:inconsistent_state))
    sample_user.update_attribute(:email, email)
  end

  def test_make_occasional_agent_out_of_a_user_beyond_agent_limit
    assert_difference 'Agent.count', 1 do
      @account.subscription.update_column(:agent_limit, 1)
      sample_user = add_new_user(@account)
      put :make_agent, construct_params({ id: sample_user.id }, occasional: true)
      assert_response 200
      assert sample_user.reload.helpdesk_agent == true
      assert Agent.last.user.id == sample_user.id
      assert Agent.last.occasional == true
    end
  end

  def test_make_agent_fails_in_user_validation
    assert_no_difference 'Agent.count' do
      sample_user = add_new_user(@account)
      last_user = add_new_user(@account)
      twitter_handle = Faker::Internet.email
      last_user.update_attribute(:twitter_id, twitter_handle)
      sample_user.update_column(:twitter_id, twitter_handle)
      @controller.stubs(:agent_limit_reached?).returns(false)
      put :make_agent, construct_params(id: sample_user.id)
      assert_response 409
      assert sample_user.helpdesk_agent == false
    end
  ensure
    @controller.unstub(:agent_limit_reached?)
  end

  def test_make_field_agent
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)

    sample_user = add_new_user(@account)
    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT)
    assert_response 200
    assert sample_user.reload.helpdesk_agent == true
    agent = Agent.last
    assert agent.user.id == sample_user.id
    assert agent.agent_type == field_agent_type.agent_type_id
    assert agent.occasional == false
    assert agent.ticket_permission == 3
  ensure
    field_agent_type.destroy
    sample_user.destroy
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  def test_make_field_agent_as_an_occasional_agent
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)

    sample_user = add_new_user(@account)
    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT, occasional: true)
    assert_response 400
    match_json([bad_request_error_pattern('occasional', :field_agent_state)])
  ensure
    field_agent_type.destroy
    sample_user.destroy
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  def test_make_field_agent_with_support_group
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)

    sample_user = add_new_user(@account)
    sample_group = create_group(@account)
    group_id = sample_group.id
    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT, group_ids: [group_id])
    assert_response 400
    match_json([bad_request_error_pattern('group_ids', :should_not_be_support_group)])
  ensure
    field_agent_type.destroy
    sample_group.destroy
    sample_user.destroy
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  def test_make_field_agent_with_admin_role
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    sample_user = add_new_user(@account)
    role_ids = Role.admin.pluck(:id)

    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT, role_ids: role_ids)
    assert_response 400
    match_json([bad_request_error_pattern('role_ids', I18n.t('activerecord.errors.messages.field_agent_roles', role: 'field technician'))])
  ensure
    field_agent_type.destroy
    sample_user.destroy
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  def test_make_field_agent_with_field_tech_role
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    role = @account.roles.create(name: 'Field technician', default_role: true)
    sample_user = add_new_user(@account)

    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT, role_ids: [role.id])
    assert_response 200
    assert sample_user.reload.helpdesk_agent == true
    assert sample_user.role_ids == [role.id]
    agent = Agent.last
    assert agent.user.id == sample_user.id
    assert agent.agent_type == field_agent_type.agent_type_id
  ensure
    field_agent_type.destroy
    sample_user.destroy
    role.destroy
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  def test_make_field_agent_with_agent_role
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    sample_user = add_new_user(@account)

    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT, role_ids: [Role.find_by_name('Agent').id])
    assert_response 400
    match_json([bad_request_error_pattern('role_ids', I18n.t('activerecord.errors.messages.field_agent_roles', role: 'field technician'))])
  ensure
    field_agent_type.destroy
    sample_user.destroy
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  def test_make_field_agent_with_global_access
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)

    sample_user = add_new_user(@account)
    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT, ticket_scope: 1)
    assert_response 400
    match_json([bad_request_error_pattern('ticket_permission', :field_agent_scope)])
  ensure
    field_agent_type.destroy
    sample_user.destroy
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  def test_make_field_agent_with_field_agent_limit_reached
    Account.any_instance.stubs(:current).returns(@account)
    @account.add_feature(:field_service_management)
    field_agent_type = AgentType.create_agent_type(@account, Agent::FIELD_AGENT)
    Account.current.stubs(:reached_field_agent_limit?).returns(true)

    sample_user = add_new_user(@account)
    put :make_agent, construct_params({ id: sample_user.id }, type: Agent::FIELD_AGENT, ticket_scope: 1)
    assert_response 400
    match_json([bad_request_error_pattern('field_agent', :max_field_agents_reached)])
  ensure
    field_agent_type.destroy
    sample_user.destroy
    Account.current.unstub(:reached_field_agent_limit?)
    @account.revoke_feature(:field_service_management)
    Account.unstub(:current)
  end

  # Misc
  def test_demosite_delete
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, false)

    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      delete :destroy, construct_params(id: sample_user.id)
    end

    assert_response :missing
  end

  def test_demosite_update
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, false)

    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      put :update, construct_params({ id: sample_user.id }, time_zone: 'Chennai')
    end

    assert_response :missing
  end

  def test_demosite_create
    params = { name: Faker::Lorem.characters(15), email: Faker::Internet.email }

    stub_const(ApiConstants, 'DEMOSITE_URL', @account.full_domain) do
      post :create, construct_params({}, params)
    end

    assert_response :missing
  end

  def test_update_array_field_with_empty_array
    sample_user = add_new_user(@account)
    put :update, construct_params({ id: sample_user.id }, tags: [])
    match_json(deleted_contact_pattern(sample_user.reload))
    assert_response 200
  end

  def test_update_array_fields_with_compacting_array
    tag = Faker::Name.name
    sample_user = add_new_user(@account)
    put :update, construct_params({ id: sample_user.id }, tags: [tag, '', ''])
    match_json(deleted_contact_pattern({ tags: [tag] }, sample_user.reload))
    assert_response 200
  end

  def test_index_with_link_header
    3.times do
      add_new_user(@account)
    end
    per_page =  @account.all_contacts.where(deleted: false).count - 1
    get :index, controller_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/contacts?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, controller_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end

  def test_create_contact_with_invalid_tag_values
    comp = get_company
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: comp.id,
                                        language: 'en',
                                        tags: [1, 2, 3])
    match_json([bad_request_error_pattern('tags', :array_datatype_mismatch, expected_data_type: String)])
    assert_response 400
  end

  def test_create_contact_with_apostrophe_in_email
    name = "abc'd#{rand(1000)}"
    email = "#{rand(1000)}abc'd@f.com"
    post :create, construct_params({},  name: name,
                                        email: email)
    assert_response 201
    contact = User.last
    assert_equal name, contact.name
    assert_equal email, contact.email
  end

  def test_update_contact_with_nil_custom_fields
    params = { custom_fields: {} }
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, false)
    put :update, construct_params({ id: sample_user.reload.id }, params)
    match_json(deleted_contact_pattern(sample_user))
    assert_response 200
  end

  def test_update_invalid_format_custom_field
    sample_user = add_new_user(@account)
    put :update, construct_params({ id: sample_user.id }, custom_fields: [1, 2])
    match_json([bad_request_error_pattern(:custom_fields, :datatype_mismatch, expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: Array)])
    assert_response 400
  end

  def test_create_with_all_default_fields_required_invalid
    default_non_required_fiels = ContactField.where(required_for_agent: false, column_name: 'default')
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    post :create, construct_params({},  name: Faker::Name.name)
    assert_response 400

    match_json([bad_request_error_pattern(
                  'email', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String
                ),
                bad_request_error_pattern(
                  'job_title', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String
                ),
                bad_request_error_pattern(
                  'mobile', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String
                ),
                bad_request_error_pattern(
                  'address', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String
                ),
                bad_request_error_pattern(
                  'description', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String
                ),
                bad_request_error_pattern(
                  'twitter_id', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String
                ),
                bad_request_error_pattern(
                  'phone', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String
                ),
                bad_request_error_pattern(
                  'company_id', :datatype_mismatch, code: :missing_field,
                  expected_data_type: 'Positive Integer'
                ),
                bad_request_error_pattern(
                  'language', :not_included,
                    list: I18n.available_locales.map(&:to_s).join(','),
                    code: :missing_field
                  ),
                bad_request_error_pattern(
                  'time_zone', :not_included,
                  list: ActiveSupport::TimeZone.all.map(&:name).join(','),
                  code: :missing_field)]
                )
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
  end

  def test_create_with_all_default_fields_required_valid
    default_non_required_fiels = ContactField.where(required_for_agent: false,  column_name: 'default')
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        view_all_tickets: true,
                                        company_id: Company.first.id,
                                        language: 'en',
                                        time_zone: 'Mountain Time (US & Canada)',
                                        mobile: Faker::Lorem.characters(15),
                                        phone: Faker::Lorem.characters(15),
                                        job_title: Faker::Lorem.characters(15),
                                        description: Faker::Lorem.characters(300),
                                        tags: [Faker::Name.name, Faker::Name.name],
                                        twitter_id: Faker::Name.name,
                                        address: Faker::Lorem.characters(15)
                                  )
    assert_response 201
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
  end

  def test_update_with_all_default_fields_required_invalid
    default_non_required_fiels = ContactField.where(required_for_agent: false,  column_name: 'default')
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    sample_user = add_new_user(@account)
    put :update, construct_params({ id: sample_user.id },  email: nil,
                                                           view_all_tickets: nil,
                                                           company_id: nil,
                                                           language: nil,
                                                           time_zone: nil,
                                                           mobile: nil,
                                                           phone: nil,
                                                           job_title: nil,
                                                           description: nil,
                                                           tags: nil,
                                                           twitter_id: nil,
                                                           address: nil
                                 )
    assert_response 400
    match_json([bad_request_error_pattern(
                  'email', :datatype_mismatch, code: :missing_field,
                  expected_data_type: String,
                  prepend_msg: :input_received,
                  given_data_type: 'Null'
                ),
                bad_request_error_pattern(
                  'job_title', :datatype_mismatch, expected_data_type: String,
                  prepend_msg: :input_received,
                  given_data_type: 'Null'
                ),
                bad_request_error_pattern('mobile', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('address', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('twitter_id', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('phone', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern('tags', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'),
                bad_request_error_pattern(
                  'company_id', :datatype_mismatch,
                  expected_data_type: 'Positive Integer',
                  prepend_msg: :input_received,
                  given_data_type: 'Null'
                ),
                bad_request_error_pattern('language', :not_included,
                                          list: I18n.available_locales.map(&:to_s).join(',')),
                bad_request_error_pattern('time_zone', :not_included, list: ActiveSupport::TimeZone.all.map(&:name).join(','))])
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
  end

  # other_emails tests
  def test_create_with_other_emails
    email_array = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        other_emails: email_array)
    assert_response 201
    assert email_array.sort == other_emails_for_test(User.last).sort
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_with_other_emails_max_count_validation
    email_array = []
    (ContactConstants::MAX_OTHER_EMAILS_COUNT + 10).times do
      email_array << Faker::Internet.email
    end
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        other_emails: email_array)
    assert_response 400
    match_json([bad_request_error_pattern('other_emails', :too_long, element_type: :values, max_count: "#{ContactConstants::MAX_OTHER_EMAILS_COUNT}", current_count: email_array.size)])
  end

  def test_create_with_other_emails_max_length_validation
    email_array = ["#{Faker::Lorem.characters(23)}@#{Faker::Lorem.characters(300)}.com"]
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        other_emails: email_array)
    assert_response 400
    match_json([bad_request_error_pattern('other_emails', :'It should only contain elements that have maximum of 255 characters')])
  end

  def test_create_with_other_emails_with_duplication
    email1 = Faker::Internet.email
    email2 = Faker::Internet.email
    email_array = [email1, email2, email1, email2]
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        other_emails: email_array)
    assert_response 201
    assert email_array.uniq.sort == other_emails_for_test(User.last).sort
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_with_other_emails_with_nil
    email_array = [nil]
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        other_emails: email_array)
    assert_response 400
    match_json([bad_request_error_pattern('other_emails', "It should contain elements that are in the 'valid email address' format")])
  end

  def test_create_with_other_emails_with_invalid_emails
    email_array = [Faker::Lorem.characters(20), Faker::Lorem.characters(20)]
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        other_emails: email_array)
    assert_response 400
    match_json([bad_request_error_pattern('other_emails', "It should contain elements that are in the 'valid email address' format")])
  end

  def test_create_with_other_emails_without_primary_email
    email_array = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    put :create, construct_params({}, name: Faker::Lorem.characters(10), other_emails: email_array)
    assert_response 400
    match_json([bad_request_error_pattern('email', :fill_a_mandatory_field, field_names: 'email, mobile, phone, twitter_id')])
  end

  def test_update_contact_with_emails_associated_with_other_users_in_other_emails
    sample_user = add_new_user(@account)
    email = add_new_user(@account).email
    put :update, construct_params({ id: sample_user.id }, other_emails: [email])
    match_json([bad_request_error_pattern('other_emails', :email_already_taken, invalid_emails: [email])])
    assert_response 409
  end

  def test_create_contact_with_phone_name_and_other_emails
    email_array = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    put :create, construct_params({}, name: Faker::Lorem.characters(10), phone: '5783947366', other_emails: email_array)
    assert_response 400
    match_json([bad_request_error_pattern('email', :conditional_not_blank, child: 'other_emails')])
  end

  def test_update_contact_with_email_and_other_emails
    sample_user = add_new_user(@account)
    params_hash = { email: nil, phone: '1234567890' }
    sample_user.update_attributes(params_hash)
    sample_user.user_emails = []
    email = 'sample_b_' + Time.zone.now.to_i.to_s + '@sampledomain.com'
    email_array = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    put :update, construct_params({ id: sample_user.id },  email: email, other_emails: email_array)
    assert_response 200
    assert sample_user.reload.email = email
    assert email_array.sort == other_emails_for_test(sample_user).sort
  end

  # Existing { a }     Update { [y,z] }     Result  { a, [y,z] }
  def test_update_contact_with_other_emails
    add_new_user(@account, name: Faker::Lorem.characters(15), email: 'sample_a_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    sample_user = add_new_user(@account)
    email_array = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    put :update, construct_params({ id: sample_user.id }, other_emails: email_array)
    assert_response 200
    assert email_array.sort == other_emails_for_test(sample_user).sort
  end

  # Existing { }     Update { [y,z] }     Result  { Error }
  def test_update_contact_with_other_emails_without_primary_email
    sample_user = add_new_user(@account, name: Faker::Lorem.characters(15), phone: '9948592049')
    sample_user.update_attributes(email: nil)
    email_array = [Faker::Internet.email, Faker::Internet.email, Faker::Internet.email, Faker::Internet.email]
    put :update, construct_params({ id: sample_user.id }, other_emails: email_array)
    assert_response 400
    match_json([bad_request_error_pattern('email', :conditional_not_blank, child: 'other_emails')])
  end

  # Existing { a, [b,c] }     Update { x, [y,z] }     Result  { x, [y,z] }
  def test_update_contact_with_primary_and_other_emails_with_new_set_of_primary_and_other_emails
    add_new_user(@account, name: Faker::Lorem.characters(15), email: 'sample_b_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    sample_user = User.last
    email = Faker::Internet.email
    email_array = [Faker::Internet.email, Faker::Internet.email]
    put :update, construct_params({ id: sample_user.id }, email: email, other_emails: email_array)
    assert_response 200
    assert sample_user.reload.email == email
    assert email_array.sort == other_emails_for_test(sample_user).sort
  end

  # Existing { a, [b,c] }     Update { [y,z] }     Result  { a, [y,z] }
  def test_update_contact_with_primary_and_other_emails_with_new_set_of_other_emails
    add_new_user(@account, name: Faker::Lorem.characters(15), email: 'sample_c_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    sample_user = User.last
    email_array = [Faker::Internet.email, Faker::Internet.email]
    put :update, construct_params({ id: sample_user.id }, other_emails: email_array)
    assert_response 200
    assert email_array.sort == other_emails_for_test(sample_user).sort
  end

  # Existing { a, [b,c] }     Update { b, [c] }       Result  { b, [c] }
  def test_update_contact_with_primary_and_other_emails_by_selecting_new_primary_email_from_other_emails_case_1
    add_new_user(@account, name: Faker::Lorem.characters(15), email: 'sample_d_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    sample_user = User.last
    email_e = 'sample_e_' + Time.zone.now.to_i.to_s + '@sampledomain.com'
    email_f = 'sample_f_' + Time.zone.now.to_i.to_s + '@sampledomain.com'
    add_user_email(sample_user, email_e)
    add_user_email(sample_user, email_f)
    sample_user.reload
    email_array = [email_f]
    put :update, construct_params({ id: sample_user.id }, email: email_e, other_emails: email_array)
    assert_response 200
    assert email_array.sort == other_emails_for_test(sample_user).sort
    assert sample_user.reload.email == email_e
  end

  # Existing { a, [b] }       Update { b, [] }        Result  { b, [] }
  def test_update_contact_with_primary_and_other_emails_by_selecting_new_primary_email_from_other_emails_case_2
    sample_user = add_new_user(@account, name: Faker::Name.name, email: 'sample_f1_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    email_g = 'sample_g_' + Time.zone.now.to_i.to_s + '@sampledomain.com'
    add_user_email(sample_user, email_g)
    put :update, construct_params({ id: sample_user.id }, email: email_g, other_emails: [])
    assert_response 200
    assert other_emails_for_test(sample_user).blank?
    assert sample_user.reload.email == email_g
  end

  # Existing { a, [b] }     Update { [] }     Result  { a, [] }
  def test_update_delete_other_emails_from_contact_having_primary_and_other_emails
    add_new_user(@account, name: Faker::Lorem.characters(15), email: 'sample_h_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    sample_user = User.last
    email_i = 'sample_i_' + Time.zone.now.to_i.to_s + '@sampledomain.com'
    add_user_email(sample_user, email_i)
    sample_user.reload
    put :update, construct_params({ id: sample_user.id }, other_emails: [])
    assert_response 200
    assert other_emails_for_test(sample_user).blank?
  end

  # Existing { a, [...] }     Update { [a] }     Result  { Error }
  def test_update_contact_with_other_emails_having_primary_email_as_an_element
    sample_user = add_new_user(@account, name: Faker::Lorem.characters(15), email: 'sample_j_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    email = sample_user.email
    put :update, construct_params({ id: sample_user.id }, other_emails: [email])
    assert_response 400
    match_json([bad_request_error_pattern(
                  'other_emails', :cant_add_primary_resource_to_others,
                  resource: "#{email}", attribute: 'other_emails',
                  status: 'primary email')])
  end

  # Create/Update contact with email, passing an array to the email attribute

  def test_create_contact_with_email_array
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: [Faker::Internet.email])
    assert_response 400
    match_json([bad_request_error_pattern('email', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_contact_filter_email_array
    email = add_new_user(@account).email
    get :index, controller_params({ email: [email] }, false)
    assert_response 400
    match_json([bad_request_error_pattern('email', :datatype_mismatch, expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Array)])
  end

  def test_update_with_custom_fields_required_which_is_already_present
    cf_sample_field = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'SampleField', editable_in_signup: 'true', required_for_agent: true))
    user = add_new_user(@account, custom_fields: { 'cf_samplefield' => 'test value' })
    put :update, construct_params({ id: user.id }, name: 'Sample User 1')
    assert_response 200
  ensure
    cf_sample_field.update_attribute(:required_for_agent, false)
  end

  def test_update_contact_with_invalid_custom_url_and_custom_date
    sample_user = add_new_user(@account)
    put :update, construct_params({ id: sample_user.id },   name: Faker::Lorem.characters(15),
                                                            email: Faker::Internet.email,
                                                            custom_fields: { 'sample_url' => 'aaaa', 'sample_date' => '2015-09-09T08:00' })
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('sample_date'), :invalid_date, accepted: 'yyyy-mm-dd'),
                bad_request_error_pattern(custom_field_error_label('sample_url'), :invalid_format, accepted: 'valid URL')])
  end

  def test_update_contact_without_required_custom_fields
    cf_sample_field = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'RequiredField', editable_in_signup: 'true', required_for_agent: true))
    user = add_new_user(@account)
    put :update, construct_params({ id: user.id },  name: Faker::Lorem.characters(15),
                                                    email: Faker::Internet.email)

    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('requiredfield'), :datatype_mismatch, code: :missing_field, expected_data_type: String)])
    ensure
      cf_sample_field.update_attribute(:required_for_agent, false)
  end

  def test_update_contact_with_invalid_custom_fields
    comp = get_company
    sample_user = add_new_user(@account)
    put :update, construct_params({ id: sample_user.id }, name: Faker::Lorem.characters(15),
                                                          email: Faker::Internet.email,
                                                          view_all_tickets: true,
                                                          company_id: comp.id,
                                                          language: 'en',
                                                          custom_fields: { 'check_me' => 'aaa', 'doj' => 2010 })
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('check_me'), :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(custom_field_error_label('doj'), :invalid_date, accepted: 'yyyy-mm-dd')])
  end

  def test_update_contact_with_invalid_dropdown_field
    comp = get_company
    sample_user = add_new_user(@account)
    put :update, construct_params({ id: sample_user.id },  name: Faker::Lorem.characters(15),
                                                           email: Faker::Internet.email,
                                                           view_all_tickets: true,
                                                           company_id: comp.id,
                                                           language: 'en',
                                                           custom_fields: { 'choose_me' => 'Choice 4' })
    assert_response 400
    match_json([bad_request_error_pattern(custom_field_error_label('choose_me'), :not_included, list: 'Choice 1,Choice 2,Choice 3')])
  end

  def test_create_contact_with_email_and_other_emails_of_another_contact
    sample_user = add_user_with_multiple_emails(@account, 2)
    email = sample_user.email
    email_array = sample_user.user_emails.map(&:email) - [email]
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: email,
                                        other_emails: email_array)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'Email has already been taken')])
  end

  def test_update_contact_with_email_and_other_emails_of_another_contact
    sample_user = add_user_with_multiple_emails(@account, 2)
    email = sample_user.email
    email_array = sample_user.user_emails.map(&:email) - [email]

    sample_contact = add_new_user(@account)
    put :update, construct_params({ id: sample_contact.id }, email: email, other_emails: email_array)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'Email has already been taken')])
  end

  def test_update_contact_with_already_associated_email_in_uppercase
    add_new_user(@account, name: Faker::Lorem.characters(15), email: 'sample_p_' + Time.zone.now.to_i.to_s + '@sampledomain.com')
    sample_user = User.last
    email_q = 'sample_q_' + Time.zone.now.to_i.to_s + '@sampledomain.com'
    add_user_email(sample_user, email_q)
    sample_user.reload
    email_array = [email_q.upcase]
    put :update, construct_params({ id: sample_user.id }, other_emails: email_array)
    assert_response 200
    assert [email_q] == other_emails_for_test(sample_user)
  end

  def test_create_with_other_emails_with_mixedcase_duplicates
    email = Faker::Internet.email
    email_array = [email, email.upcase]
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        other_emails: email_array)
    assert_response 201
    assert [email] == other_emails_for_test(User.last)
    match_json(deleted_contact_pattern(User.last))
  end

  def test_create_with_email_in_uppercase
    email = Faker::Internet.email.upcase
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: email)
    assert_response 201
    assert User.last.email == email.downcase
    match_json(deleted_contact_pattern(User.last))
  end

  def test_update_contact_having_email_in_uppercase
    sample_user = add_new_user(@account)
    email = Faker::Internet.email
    sample_user.email = email.upcase
    sample_user.save
    put :update, construct_params({ id: sample_user.id }, phone: '1111122222')
    assert_response 200
    assert sample_user.reload.email == email.downcase
    match_json(deleted_contact_pattern(sample_user.reload))
  end

  def test_create_contact_with_existing_uppercase_email
    email = Faker::Internet.email.upcase
    contact_a = add_new_user(@account, name: Faker::Lorem.characters(15), email: email)
    assert contact_a.reload.email == email.downcase
    contact_b = add_new_user(@account)
    put :update, construct_params({ id: contact_b.id }, email: email.downcase)
    assert_response 409
    additional_info = parse_response(@response.body)['errors'][0]['additional_info']
    match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'Email has already been taken')])
  end

  def test_update_email_and_pass_other_emails_without_change
    sample_user = add_new_user(@account)
    sample_user.user_emails.build(email: Faker::Internet.email, primary_role: false)
    sample_user.user_emails.build(email: Faker::Internet.email, primary_role: false)
    sample_user.save
    sample_user.reload
    email_array = sample_user.user_emails.reject(&:primary_role).map(&:email)
    email = Faker::Internet.email
    put :update, construct_params({ id: sample_user.id }, email: email, other_emails: email_array)
    assert_response 200
    response = parse_response @response.body
    assert response['other_emails'].sort == email_array.sort
    assert response['email'] == email
  end

  # Other Companies test

  def test_create_contact_with_other_companies
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            {
                                              company_id: company_ids[1],
                                              view_all_tickets: true
                                            }
                                          ])
    assert_response 201
    match_json(deleted_contact_pattern(User.last))
    assert User.last.user_companies.find_by_default(true).company_id == company_ids[0]
    assert User.last.user_companies.find_by_default(true).client_manager == true
    assert User.last.user_companies.find_by_default(false).company_id == company_ids[1]
    assert User.last.user_companies.find_by_default(false).client_manager == true
  end

  def test_update_contact_with_other_companies
    sample_user = get_user_with_default_company
    company_id = (Company.all.map(&:id) - [sample_user.company_id]).sample
    other_companies = [{company_id: company_id, view_all_tickets: false}]
    put :update, construct_params({ id: sample_user.id }, other_companies: other_companies)
    sample_user.reload
    assert sample_user.user_companies.find_by_default(false).company_id == company_id
    assert sample_user.user_companies.find_by_default(false).client_manager == false
  end

  def test_update_delete_other_companies
    sample_user = get_user_with_multiple_companies
    put :update, construct_params({ id: sample_user.id }, other_companies: [])
    sample_user.reload
    assert sample_user.companies.count == 1
  end

  def test_create_with_other_companies_max_count_validation
    other_companies = []
    (User::MAX_USER_COMPANIES).times do
      other_companies << { company_id: Company.last.id, view_all_tickets: true }
    end
    params_hash = {
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: Company.last.id,
      view_all_tickets: true, other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      'other_companies', :too_long, element_type: :elements,
      max_count: "#{ContactConstants::MAX_OTHER_COMPANIES_COUNT}", current_count: User::MAX_USER_COMPANIES)]
    )
  end

  def test_create_with_other_companies_with_duplication
    company_ids = [create_company, create_company].map(&:id)
    other_companies = []
    2.times do
      other_companies << { company_id: company_ids[1], view_all_tickets: true }
    end
    params_hash = {
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: company_ids[0],
      view_all_tickets: true, other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('other_companies', :duplicate_companies )])
  end

  def test_create_with_other_companies_with_nil
    other_companies = [nil]
    params_hash = {
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: Company.last.id,
      view_all_tickets: true, other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      'other_companies', :array_datatype_mismatch,
      expected_data_type: 'key/value pair')]
    )
  end

  def test_create_with_other_companies_without_company_id
    other_companies = [{view_all_tickets: true}]
    params_hash = {
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: Company.last.id,
      view_all_tickets: true, other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      code: :missing_field, expected_data_type: 'Positive Integer')]
    )
  end

  def test_create_with_other_companies_without_any_keys
    other_companies = [{}]
    params_hash = {
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: Company.last.id,
      view_all_tickets: true, other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      code: :missing_field, expected_data_type: 'Positive Integer')]
    )
  end

  # Modify test
  def test_create_with_other_companies_with_invalid_key
    other_companies = [{id: Company.first.id}]
    params_hash = {
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: Company.last.id,
      view_all_tickets: true, other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('id', :invalid_field )])
  end

  def test_create_with_other_companies_with_unavailable_companies
    other_companies = [{company_id: 1000}]
    params_hash = {
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: Company.last.id,
      view_all_tickets: true, other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('other_companies', :invalid_list, list: [1000])])
  end

  def test_create_with_other_companies_without_default_company
    other_companies = [{company_id: Company.last.id}]
    params_hash = {
      name: Faker::Lorem.characters(10),
      email: Faker::Internet.email,
      other_companies: other_companies
    }
    post :create, construct_params({},  params_hash)
    assert_response 400
    match_json([bad_request_error_pattern(
      'company_id',  :conditional_not_blank, child: 'other_companies')]
    )
  end

  def test_error_in_create_with_more_than_max_companies
      company_ids = (1..User::MAX_USER_COMPANIES + 1).to_a
      other_companies_param = construct_other_companies_hash(company_ids)
      post :create, construct_params({}, name: Faker::Lorem.characters(10),
                                         email: Faker::Internet.email,
                                         company_id: company_ids[0],
                                         view_all_tickets: true,
                                         other_companies: other_companies_param)
      assert_response 400
      match_json([{ field: 'other_companies',
                    message: "Has #{User::MAX_USER_COMPANIES} elements, it can have maximum of #{ContactConstants::MAX_OTHER_COMPANIES_COUNT} elements",
                    code: :invalid_value }])
    end

  def test_error_in_create_with_more_than_max_extended_companies
    set_max_extended_companies
    company_ids = (1..user_companies_limit + 1).to_a
    other_companies_param = construct_other_companies_hash(company_ids)
    post :create, construct_params({}, name: Faker::Lorem.characters(10),
                                       email: Faker::Internet.email,
                                       company_id: company_ids[0],
                                       view_all_tickets: true,
                                       other_companies: other_companies_param)
    assert_response 400
    match_json([{ field: 'other_companies',
                  message: "Has #{user_companies_limit} elements, it can have maximum of #{user_companies_limit - 1} elements",
                  code: :invalid_value }])
  ensure
    reset_max_extended_companies
  end

  def test_update_contact_with_company_and_other_companies
    sample_user = get_user_with_default_company
    sample_user.update_attributes({:deleted => false, :blocked => false})
    company_ids = [create_company, create_company].map(&:id)
    other_companies = [{company_id: company_ids[1], view_all_tickets: false}]
    put :update, construct_params({ id: sample_user.id },
      company_id: company_ids[0], view_all_tickets: true,
      other_companies: other_companies
    )
    assert_response 200
    sample_user.reload
    assert sample_user.user_companies.find_by_default(true).company_id == company_ids[0]
    assert sample_user.user_companies.find_by_default(true).client_manager == true
    assert sample_user.user_companies.find_by_default(false).company_id == company_ids[1]
    assert sample_user.user_companies.find_by_default(false).client_manager == false
  end

  def test_update_contact_with_other_companies_without_default_company
    sample_user = add_new_user(@account)
    sample_user.companies = []
    sample_user.save
    other_companies = [{company_id: Company.first.id, view_all_tickets: false}]
    put :update, construct_params({ id: sample_user.id },
      other_companies: other_companies
    )
    assert_response 400
    match_json([bad_request_error_pattern(
      'company_id',  :conditional_not_blank, child: 'other_companies')]
    )
  end

  def test_update_contact_with_default_and_other_companies_with_new_set
    sample_user = get_user_with_multiple_companies
    sample_user.update_attributes({:deleted => false, :blocked => false})
    company_ids = [create_company, create_company].map(&:id)
    other_companies = [{company_id: company_ids[1], view_all_tickets: true}]
    put :update, construct_params({ id: sample_user.id },
      company_id: company_ids[0], view_all_tickets: true,
      other_companies: other_companies
    )
    assert_response 200
    sample_user.reload
    assert sample_user.user_companies.find_by_default(true).company_id == company_ids[0]
    assert sample_user.user_companies.find_by_default(true).client_manager == true
    assert sample_user.user_companies.find_by_default(false).company_id == company_ids[1]
    assert sample_user.user_companies.find_by_default(false).client_manager == true
  end

  def test_update_contact_with_new_other_companies
    sample_user = get_user_with_default_company
    company_ids = [create_company, create_company].map(&:id) - sample_user.company_ids
    put :update, construct_params({ id: sample_user.id },
      other_companies: [{company_id: company_ids[0], view_all_tickets: false}]
    )
    assert_response 200
    sample_user.reload
    assert sample_user.user_companies.find_by_default(false).company_id == company_ids[0]
    assert sample_user.user_companies.find_by_default(false).client_manager == false
  end

  # Existing { a, [b,c] }     Update { b, [c] }       Result  { b, [c] }
  def test_update_contact_with_new_default_company_from_other_companies_case_1
    sample_user = get_user_with_default_company
    company_ids = Company.all.map(&:id) - sample_user.company_ids
    sample_user.user_companies.build(company_id: company_ids.first, client_manager: true)
    sample_user.user_companies.build(company_id: company_ids.last, client_manager: true)
    sample_user.save
    params_hash = { company_id: company_ids.first, other_companies: [{ company_id: company_ids.last, view_all_tickets: true }]}
    put :update, construct_params({id: sample_user.id}, params_hash)
    sample_user.reload
    assert_response 200
    assert sample_user.user_companies.find_by_default(true).company_id == company_ids.first
    assert sample_user.user_companies.find_by_default(true).client_manager == false
    assert sample_user.user_companies.find_by_default(false).company_id == company_ids.last
    assert sample_user.user_companies.find_by_default(false).client_manager == true
  end

  # Existing { a, [b] }       Update { b, [] }        Result  { b, [] }
  def test_update_contact_with_new_default_company_from_other_companies_case_2
    sample_user = get_user_with_default_company
    company_ids = Company.all.map(&:id) - sample_user.company_ids
    sample_user.user_companies.build(company_id: company_ids.first, client_manager: true)
    sample_user.save
    params_hash = { company_id: company_ids.first, other_companies: [] }
    put :update, construct_params({id: sample_user.id}, params_hash)
    sample_user.reload
    assert_response 200
    assert sample_user.user_companies.find_by_default(true).company_id == company_ids.first
    assert sample_user.user_companies.find_by_default(true).client_manager == false
    assert sample_user.user_companies.where(default: false).count == 0
  end

  def test_update_contact_with_other_companies_having_default_company_as_an_element
    sample_user = get_user_with_multiple_companies
    sample_user.update_attributes({:deleted => false, :blocked => false})
    default_company = sample_user.company.id
    other_companies = [{company_id: default_company, view_all_tickets: true}]
    put :update, construct_params({ id: sample_user.id }, other_companies: other_companies)
    assert_response 400
    match_json([bad_request_error_pattern(
      'other_companies', :cant_add_primary_resource_to_others,
      resource: default_company, attribute: 'other_companies',
      status: 'default company' )]
    )
  end

  def test_update_contact_with_other_companies_without_multiple_user_companies_feature
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(false)
    sample_user = get_user_with_default_company
    other_companies = [{company_id: Company.last.id, view_all_tickets: true}]
    put :update, construct_params({ id: sample_user.id },
      company_id: Company.first.id, view_all_tickets: true,
      other_companies: other_companies
    )
    assert_response 400
    match_json([bad_request_error_pattern(
      'other_companies', :require_feature_for_attribute, {
        code: :inaccessible_field,
        feature: :multiple_user_companies,
        attribute: "other_companies" })]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_contact_with_other_companies_without_multiple_user_companies_feature
    Account.any_instance.stubs(:multiple_user_companies_enabled?).returns(false)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: Company.first.id,
                                        view_all_tickets: true,
                                        other_companies: [{
                                          company_id: Company.last.id,
                                          view_all_tickets: true}]
                                        )
    assert_response 400
    match_json([bad_request_error_pattern(
      'other_companies', :require_feature_for_attribute, {
        code: :inaccessible_field, feature: :multiple_user_companies,
        attribute: "other_companies" })]
    )
  ensure
    Account.any_instance.unstub(:multiple_user_companies_enabled?)
  end

  def test_create_contact_with_other_companies_invalid_company_id
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            {
                                              company_id: "aaaa",
                                              view_all_tickets: true
                                            }
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      expected_data_type: 'Positive Integer' )]
    )
  end

  def test_create_contact_with_other_companies_company_id_nil
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            {company_id: nil, view_all_tickets: true}
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      expected_data_type: 'Positive Integer' )]
    )
  end

  def test_create_contact_with_other_companies_invalid_view_all_tickets
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            {company_id: 1, view_all_tickets: "true"}
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'view_all_tickets', :datatype_mismatch,
      expected_data_type: 'Boolean' )]
    )
  end

  def test_create_contact_with_company_id_string
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            { company_id: "2", view_all_tickets: true }
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      expected_data_type: 'Positive Integer' )]
    )
  end


  def test_create_contact_with_company_id_boolean
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            { company_id: true,
                                              view_all_tickets: true
                                            }
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      expected_data_type: 'Positive Integer' )]
    )
  end

  def test_create_contact_with_company_id_and_client_manager_string
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            { company_id: "2", view_all_tickets: "2" }
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      expected_data_type: 'Positive Integer' )]
    )
  end

  def test_create_contact_with_company_id_nil
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            { company_id: nil }
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'company_id', :datatype_mismatch,
      expected_data_type: 'Positive Integer' )]
    )
  end

  def test_create_contact_with_client_manager_nil
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            {
                                              company_id: company_ids[1],
                                              view_all_tickets: nil
                                            }
                                          ])
    assert_response 201
  end

  def test_create_contact_with_client_manager_integer
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            { company_id: company_ids[1],
                                              view_all_tickets: 23
                                            }
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'view_all_tickets',
      :datatype_mismatch, expected_data_type: 'Boolean' )]
    )
  end

  def test_create_contact_with_client_manager_string
    company_ids = [create_company, create_company].map(&:id)
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email,
                                        company_id: company_ids[0],
                                        view_all_tickets: true,
                                        other_companies: [
                                            { company_id: company_ids[1],
                                              view_all_tickets: 'test'
                                            }
                                          ])
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(
      'other_companies', 'view_all_tickets',
      :datatype_mismatch, expected_data_type: 'Boolean' )]
    )
  end

  def test_restore_extra_params
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, true)
    put :restore, construct_params({ id: sample_user.id }, test: 1)
    assert_response 400
    match_json(request_error_pattern('no_content_required'))
  end

  def test_restore_load_object_not_present
    put :restore, construct_params(id: 9999)
    assert_response :missing
    assert_equal ' ', @response.body
  end

  def test_restore_without_privilege
    User.any_instance.stubs(:privilege?).with(:delete_contact).returns(false).at_most_once
    put :restore, construct_params(id: User.first.id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
  end

  def test_restore_with_permission
    sample_user = add_new_user(@account)
    sample_user.update_column(:deleted, true)
    put :restore, construct_params({ id: sample_user.id })
    assert_response 204
    refute sample_user.reload.deleted
  end

  def test_restore_with_merged_source_contact
    sample_user = add_new_user(@account)
    sample_user.deleted = true
    sample_user.parent_id = 999
    sample_user.save
    put :restore, construct_params({ id: sample_user.id })
    assert_response 404
    sample_user.parent_id = nil
  end

  def test_unique_external_id_update_without_feature
    post :create, construct_params({},  unique_external_id: Faker::Lorem.characters(10), name: Faker::Lorem.characters(10))
    assert_response 400
  end

  def test_unique_external_id_update_with_feature_with_name
    @account.add_feature(:unique_contact_identifier)
    post :create, construct_params({},  unique_external_id: Faker::Lorem.characters(10), name: Faker::Lorem.characters(10))
    assert_response 201
    match_json(deleted_contact_pattern(User.last))
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_unique_external_id_update_with_feature_without_name
    @account.add_feature(:unique_contact_identifier)
    post :create, construct_params({},  unique_external_id: Faker::Lorem.characters(10))
    match_json([bad_request_error_pattern('name', :missing_field)])
    assert_response 400
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_create_length_invalid_for_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    post :create, construct_params({}, name: Faker::Lorem.characters(10), unique_external_id: Faker::Lorem.characters(300))
    match_json([bad_request_error_pattern('unique_external_id', :'Has 300 characters, it can have maximum of 255 characters')])
    assert_response 400
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end


  def test_create_length_valid_with_trailing_spaces_for_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    params = { unique_external_id: Faker::Lorem.characters(20) + white_space, name: Faker::Lorem.characters(20) + white_space}
    post :create, construct_params({}, params)

    match_json(deleted_contact_pattern(User.last))
    assert_response 201
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_create_contact_without_any_contact_detail_with_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    post :create, construct_params({},  name: Faker::Lorem.characters(10))
    match_json([bad_request_error_pattern('email', :fill_a_mandatory_field, field_names: 'email, mobile, phone, twitter_id, unique_external_id')])
    assert_response 400
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_create_contact_with_quick_create_fields
    post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                        email: Faker::Internet.email,
                                        company_name: Faker::Lorem.characters(10))
    match_json([bad_request_error_pattern('company_name', :invalid_field)])
    assert_response 400
  end

  # Skip mandatory custom field validation on update
  def test_update_contact_without_required_custom_fields_with_enforce_mandatory_as_false
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 200, result
    assert_equal result['address'], 'testing'
  ensure
    cf.delete
  end

  def test_update_contact_without_required_custom_fields_with_enforce_mandatory_as_true
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )

    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_contact_without_required_custom_fields_default_enforce_mandatory_true
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']

    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing'
    )
    result = JSON.parse(updated_contact.body)

    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_true_existing_custom_field_empty_new_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_true_existing_custom_field_empty_new_not_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: 'testing' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 200, result
    assert_equal result['address'], 'testing'
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_true_existing_custom_field_not_empty_new_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: 'existing' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_true_existing_custom_field_not_empty_new_not_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: 'existing' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: 'testing' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 200, result
    assert_equal result['address'], 'testing'
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_false_existing_custom_field_empty_new_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_false_existing_custom_field_empty_new_not_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: 'testing' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 200, result
    assert_equal result['address'], 'testing'
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_false_existing_custom_field_not_empty_new_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: 'existing' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_update_contact_with_enforce_mandatory_false_existing_custom_field_not_empty_new_not_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: 'existing' }
    )
    created_contact_id = JSON.parse(created_contact.body)['id']
    updated_contact = put :update, construct_params(
      { id: created_contact_id },
      address: 'testing',
      custom_fields: { code: 'testing' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(updated_contact.body)
    assert_response 200, result
    assert_equal result['address'], 'testing'
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_true_not_passing_custom_field
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :missing_field,
        message: 'It should be a/an String'
      }]
    )
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_true_custom_field_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: '' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_true_passing_custom_field
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: 'test' },
      query_params: { enforce_mandatory: 'true' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 201, result
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_false_not_passing_custom_field
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 201, result
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_false_custom_field_empty
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: '' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'custom_fields.code',
        code: :invalid_value,
        message: 'It should not be blank as this is a mandatory field'
      }]
    )
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_false_passing_custom_field
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: 'test' },
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 201, result
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_as_garbage_value
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      custom_fields: { code: 'test' },
      query_params: { enforce_mandatory: 'test' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 400, result
    match_json(
      [{
        field: 'enforce_mandatory',
        code: :invalid_value,
        message: "It should be either 'true' or 'false'"
      }]
    )
  ensure
    cf.delete
  end

  def test_create_contact_with_enforce_mandatory_false_not_passing_custom_dropdown_value
    cf = create_contact_field(cf_params(
                                type: 'dropdown',
                                field_type: 'custom_dropdown',
                                label: 'code',
                                editable_in_signup: 'true',
                                required_for_agent: 'true',
                                custom_field_choices_attributes: [
                                  {
                                    value: 'First Choice',
                                    position: 1,
                                    _destroy: 0,
                                    name: 'First Choice'
                                  },
                                  {
                                    value: 'Second Choice',
                                    position: 2,
                                    _destroy: 0,
                                    name: 'Second Choice'
                                  }
                                ]
    ))
    @account.reload
    created_contact = post :create, construct_params(
      {},
      name: Faker::Lorem.characters(15),
      email: Faker::Internet.email,
      query_params: { enforce_mandatory: 'false' }
    )

    result = JSON.parse(created_contact.body)
    assert_response 201, result
  ensure
    cf.delete
  end

  def test_show_a_contact_with_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    sample_user = get_user
    get :show, construct_params(id: sample_user.id)
    match_json(unique_external_id_contact_pattern(sample_user.reload))
    assert_response 200
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_contact_index_with_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    get :index, controller_params()
    assert_response 200
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false && x.blocked == false }
    pattern = users.map { |user| index_contact_pattern_with_unique_external_id(user) }
    match_json(pattern.ordered!)
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_contact_filter_email_for_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    @account.all_contacts.update_all(email: nil)
    unique_external_id =  Faker::Lorem.characters(10)
    @account.all_contacts.first.update_column(:unique_external_id, unique_external_id)
    get :index, controller_params(unique_external_id: unique_external_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
    users = @account.all_contacts.order('users.name').select { |x|  x.unique_external_id == unique_external_id }
    pattern = users.map { |user| index_contact_pattern_with_unique_external_id(user) }
    match_json(pattern.ordered!)
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_contact_combined_filter_for_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    email = Faker::Internet.email
    unique_external_id =  Faker::Lorem.characters(40)
    comp = get_company
    last_contact = @account.all_contacts.last
    first_contact = @account.all_contacts.first
    first_contact.company_id = comp.id
    first_contact.save!
    first_contact.user_emails.create(email: email)
    last_contact.company_id = comp.id
    last_contact.unique_external_id = unique_external_id
    last_contact.save!
    get :index, controller_params(company_id: "#{comp.id}", unique_external_id: unique_external_id)
    assert_response 200
    response = parse_response @response.body
    assert_equal 1, response.size
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_update_length_invalid_for_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    sample_user = get_user
    put :update, construct_params({ id: sample_user.id }, unique_external_id: Faker::Lorem.characters(300))
    match_json([bad_request_error_pattern('unique_external_id', :'Has 300 characters, it can have maximum of 255 characters')])
    assert_response 400
  ensure
    @account.revoke_feature(:unique_contact_identifier)
  end

  def default_fields_required_invalid_with_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    default_non_required_fiels = ContactField.where(required_for_agent: false,  column_name: 'default')
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    sample_user = get_user
    put :update, construct_params({ id: sample_user.id },  unique_external_id: sample_user.unique_external_id
                                 )
    assert_response 400
    match_json([bad_request_error_pattern('unique_external_id', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null')])
  ensure
    default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_update_user_with_valid_params_with_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    unique_external_id = Faker::Lorem.characters(10)
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'city', editable_in_signup: 'true'))
    tags = [Faker::Name.name, Faker::Name.name, 'tag_sample_test_4']
    cf = { 'city' => 'Chennai' }

    sample_user = User.where(helpdesk_agent: false).last
    params_hash = { language: 'cs',
                    time_zone: 'Tokyo',
                    job_title: 'emp',
                    custom_fields: cf,
                    unique_external_id: unique_external_id,
                    tags: tags }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert sample_user.reload.language == 'cs'
    assert sample_user.reload.time_zone == 'Tokyo'
    assert sample_user.reload.job_title == 'emp'
    assert sample_user.reload.tag_names.split(', ').sort == tags.sort
    assert sample_user.reload.custom_field['cf_city'] == 'Chennai'
    assert sample_user.reload.unique_external_id == unique_external_id
    match_json(deleted_contact_pattern(sample_user.reload))
    assert_response 200
  ensure
    sample_user.update_column(:unique_external_id, nil)
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_update_length_valid_with_trailing_space_for_unique_external_id
    @account.add_feature(:unique_contact_identifier)
    sample_user = get_user
    unique_external_id = Faker::Lorem.characters(10)
    sample_user.update_attribute(:unique_external_id, nil)
    params = { name: Faker::Lorem.characters(20) + white_space, unique_external_id: unique_external_id + white_space }
    put :update, construct_params({ id: sample_user.id }, params)
    match_json(deleted_contact_pattern(sample_user.reload))
    assert_response 200
  ensure
    sample_user.update_column(:unique_external_id, nil)
    @account.revoke_feature(:unique_contact_identifier)
  end

  # Though index action is run on slave, the update query should go to master when we update failed_login_count 
  def test_index_with_invalid_password
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.email, 'wrongpassword')
    params = ActionController::Parameters.new('format' => 'json')
    controller.params = params
    @controller.request.env['HTTP_AUTHORIZATION'] = auth
    QueryCounter.queries = []
    get :index, controller_params
    assert_response 401
    # Two update queries will be fired for failed_login_count update
    write_query_count = QueryCounter.queries.select{ |q| q.include?('UPDATE ') or q.include?('INSERT INTO') }.count
    assert write_query_count == 2
  end

  def test_twitter_api_compliance_create_contact
    set_others_redis_key(TWITTER_API_COMPLIANCE_ENABLED, true)
    Account.current.launch(:twitter_api_compliance)
    CustomRequestStore.store[:api_v2_request] = true
    user_email = Faker::Internet.email
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: user_email)
    assert_response 201
    created_user = User.find_by_email(user_email)
    match_json(deleted_contact_pattern(created_user))
  ensure
    created_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    remove_others_redis_key TWITTER_API_COMPLIANCE_ENABLED
    Account.current.rollback(:twitter_api_compliance)
  end

  def test_populate_twitter_requester_handle_id_while_create_contact_with_twitter_id
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    user_email = Faker::Internet.email
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: user_email,
                                        twitter_id: Faker::Lorem.word)
    assert_response 201
    created_user = User.find_by_email(user_email)
    assert_equal twitter_requester_handle_id, created_user.twitter_requester_handle_id
    match_json(deleted_contact_pattern(created_user))
  ensure
    created_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_do_not_populate_twitter_requester_handle_id_while_create_contact_without_twitter_id
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    user_email = Faker::Internet.email
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: user_email)
    assert_response 201
    created_user = User.find_by_email(user_email)
    assert_nil created_user.twitter_requester_handle_id
    match_json(deleted_contact_pattern(created_user))
  ensure
    created_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_error_in_populate_twitter_requester_handle_id_while_create_contact_with_suspended_twitter_user
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error::Forbidden, 'User has been suspended.')
    create_twitter_handle
    user_email = Faker::Internet.email
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: user_email,
                                        twitter_id: Faker::Lorem.word)
    assert_response 201
    created_user = User.find_by_email(user_email)
    assert_nil created_user.twitter_requester_handle_id
    match_json(deleted_contact_pattern(created_user))
  ensure
    created_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_do_not_populate_twitter_requester_handle_id_while_create_contact_with_twitter_id_without_feature
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    user_email = Faker::Internet.email
    post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                        email: user_email,
                                        twitter_id: Faker::Lorem.word)
    assert_response 201
    created_user = User.find_by_email(user_email)
    assert_nil created_user.twitter_requester_handle_id
    match_json(deleted_contact_pattern(created_user))
  ensure
    created_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
  end

  def test_twitter_api_compliance_update_contact
    set_others_redis_key(TWITTER_API_COMPLIANCE_ENABLED, true)
    Account.current.launch(:twitter_api_compliance)
    CustomRequestStore.store[:api_v2_request] = true
    comp = get_company
    sample_user = add_new_user(@account)
    params_hash = { company_id: comp.id, view_all_tickets: true }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    match_json(deleted_contact_pattern(sample_user.reload))
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    remove_others_redis_key TWITTER_API_COMPLIANCE_ENABLED
    Account.current.rollback(:twitter_api_compliance)
  end

  def test_populate_twitter_requester_handle_id_while_contact_update_with_twitter_id_value_set
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    sample_user = add_new_user(@account)
    assert_nil sample_user.twitter_requester_handle_id

    params_hash = { twitter_id: Faker::Lorem.word }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert_equal twitter_requester_handle_id, sample_user.reload.twitter_requester_handle_id
    match_json(deleted_contact_pattern(sample_user))
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_update_twitter_requester_handle_id_while_contact_update_with_twitter_id_value_changed
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    old_twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(old_twitter_requester_handle_id))
    create_twitter_handle
    sample_user = add_new_user_with_twitter_id(@account)
    assert_equal old_twitter_requester_handle_id, sample_user.reload.twitter_requester_handle_id

    new_twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(new_twitter_requester_handle_id))
    params_hash = { twitter_id: Faker::Lorem.word }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert_equal new_twitter_requester_handle_id, sample_user.reload.twitter_requester_handle_id
    match_json(deleted_contact_pattern(sample_user))
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_update_twitter_requester_handle_id_while_contact_update_with_twitter_id_value_unset
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    sample_user = add_new_user_with_twitter_id(@account)
    assert_equal twitter_requester_handle_id, sample_user.twitter_requester_handle_id

    params_hash = { twitter_id: nil }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert_nil sample_user.reload.twitter_requester_handle_id
    match_json(deleted_contact_pattern(sample_user))
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_do_not_populate_twitter_requester_handle_id_while_contact_update_without_twitter_id
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    comp = get_company
    sample_user = add_new_user(@account)
    assert_nil sample_user.twitter_requester_handle_id

    params_hash = { company_id: comp.id, view_all_tickets: true }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert_nil sample_user.reload.twitter_requester_handle_id
    match_json(deleted_contact_pattern(sample_user))
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_error_in_update_twitter_requester_handle_id_while_update_contact_with_suspended_twitter_user
    Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    sample_user = add_new_user_with_twitter_id(@account)
    assert_equal twitter_requester_handle_id, sample_user.reload.twitter_requester_handle_id

    Twitter::REST::Client.any_instance.stubs(:user).raises(Twitter::Error::Forbidden, 'User has been suspended.')
    params_hash = { twitter_id: Faker::Lorem.word }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert_nil sample_user.reload.twitter_requester_handle_id
    match_json(deleted_contact_pattern(sample_user))
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
    Account.any_instance.unstub(:twitter_api_compliance_enabled?)
  end

  def test_do_not_populate_twitter_requester_handle_id_while_contact_update_with_twitter_id_without_feature
    CustomRequestStore.store[:api_v2_request] = true
    twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
    Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
    create_twitter_handle
    sample_user = add_new_user(@account)
    assert_nil sample_user.twitter_requester_handle_id

    params_hash = { twitter_id: Faker::Lorem.word }
    put :update, construct_params({ id: sample_user.id }, params_hash)
    assert_response 200
    assert_nil sample_user.reload.twitter_requester_handle_id
    match_json(deleted_contact_pattern(sample_user))
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    Twitter::REST::Client.any_instance.unstub(:user)
  end

  def test_contact_index_twitter_api_compliance
    set_others_redis_key(TWITTER_API_COMPLIANCE_ENABLED, true)
    Account.current.launch(:twitter_api_compliance)
    CustomRequestStore.store[:api_v2_request] = true
    get :index, controller_params()
    assert_response 200
    users = @account.all_contacts.order('users.name').select { |x| x.deleted == false && x.blocked == false }
    pattern = users.map { |user| index_contact_pattern(user) }
    match_json(pattern.ordered!)
  ensure
    CustomRequestStore.store[:api_v2_request] = false
    remove_others_redis_key TWITTER_API_COMPLIANCE_ENABLED
    Account.current.rollback(:twitter_api_compliance)
  end

  def test_twitter_api_compliance_show_contact
    set_others_redis_key(TWITTER_API_COMPLIANCE_ENABLED, true)
    Account.current.launch(:twitter_api_compliance)
    CustomRequestStore.store[:api_v2_request] = true
    sample_user = add_new_user(@account)
    get :show, construct_params(id: sample_user.id)
    ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
    match_json(contact_pattern(sample_user.reload).except(*ignore_keys))
    assert_response 200
  ensure
    sample_user.destroy
    CustomRequestStore.store[:api_v2_request] = false
    remove_others_redis_key TWITTER_API_COMPLIANCE_ENABLED
    Account.current.rollback(:twitter_api_compliance)
  end
end
