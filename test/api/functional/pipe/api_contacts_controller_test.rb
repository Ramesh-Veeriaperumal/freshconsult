require_relative '../../test_helper'
module Pipe
  class ApiContactsControllerTest < ActionController::TestCase
    include UsersTestHelper
    include CustomFieldsTestHelper

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      @account.reload
      return if @@initial_setup_run
      @account.features.multiple_user_companies.create
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
      { api_contact: params }
    end

    def get_company
      company = Company.first
      return company if company
      company = Company.create(name: Faker::Name.name, account_id: @account.id)
      company.save
      company
    end

    # Create User

    def test_create_contact
      post :create, construct_params({},  name: Faker::Lorem.characters(10),
                                          email: Faker::Internet.email)
      assert_response 201
      match_json(deleted_contact_pattern(User.last))
    end

    def test_create_contact_without_name
      post :create, construct_params({}, email: Faker::Internet.email)
      match_json([bad_request_error_pattern('name', :missing_field)])
      assert_response 400
    end

    def test_create_contact_tags_with_comma
      post :create, construct_params({}, email: Faker::Internet.email, name: Faker::Lorem.characters(10), tags: ['test,,,,comma', 'test'])
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
      add_new_user(@account, name: Faker::Lorem.characters(15), email: email)
      post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                          email: email)
      additional_info = parse_response(@response.body)['errors'][0]['additional_info']
      match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'Email has already been taken')])
      assert_response 409
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
      assert User.last.user_companies.select { |x| x.company_id == comp.id }.first.client_manager == true
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
      post :create, construct_params({}, params)
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
      post :create, construct_params({}, params)
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
      post :create, construct_params({}, params)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      match_json([bad_request_error_pattern('avatar', :invalid_size, max_size: '5 MB', current_size: '19.1 MB')])
      assert_response 400
    end

    def test_create_contact_with_invalid_field_in_custom_fields
      comp = get_company
      params = {  name: Faker::Lorem.characters(15),
                  email: Faker::Internet.email,
                  view_all_tickets: true,
                  company_id: comp.id,
                  language: 'en',
                  custom_fields: { dummyfield: Faker::Lorem.characters(20) } }
      post :create, construct_params({}, params)
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
      DataTypeValidator.any_instance.stubs(:valid_type?)
      match_json(deleted_contact_pattern(User.last))
      assert User.last.avatar.content_content_type == 'image/jpeg'
      assert_response 201
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
      cf.update_attribute(:required_for_agent, false)
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
      params[:tags] = %w[newtag existingtag TestCapsTag]
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
                                          active: 'mystring')
      assert_response 400
    end

    def test_create_user_active_false
      post :create, construct_params({},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          active: false)
      match_json([bad_request_error_pattern('active', 'Active field can only be set to true')])
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

    # Update User

    def test_update_user_with_blank_name
      params_hash = { name: '' }
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
      assert sample_user.reload.user_companies.select(&:default).first.client_manager == true
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
        code: :invalid_value, expected_data_type: 'Positive Integer'
      )])
    end

    def test_update_client_manager_with_invalid_company_id
      sample_user = add_new_user(@account)
      sample_user.user_companies.each(&:destroy)
      sample_user.reload
      comp = get_company
      params_hash = { company_id: comp.id, view_all_tickets: true, phone: '1234567890' }
      sample_user.update_attributes(params_hash)
      sample_user.reload
      params_hash = { company_id: nil }
      put :update, construct_params({ id: sample_user.id }, params_hash)
      assert_response 200
      match_json(deleted_contact_pattern(params_hash, sample_user.reload))
      assert sample_user.reload.company_id.nil?
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

    def test_update_the_email_of_a_contact_with_user_email
      user1 = add_new_user(@account)
      user2 = add_new_user_without_email(@account)
      email = user1.email
      put :update, construct_params({ id: user2.id }, email: email)
      assert_response 409
      additional_info = parse_response(@response.body)['errors'][0]['additional_info']
      match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'Email has already been taken')])
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
      match_json([bad_request_error_pattern('active', 'Active field can only be set to true')])
      assert_response 400
    end

    def test_update_user_active_string
      sample_user = add_new_user(@account)
      email = Faker::Internet.email
      params_hash = { name: 'New Name', email: email }
      sample_user.update_attributes(params_hash)

      put :update, construct_params({ id: sample_user.id }, active: 'mystring')
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
      params_hash = { name: 'New Name', email: email }
      sample_user.update_attributes(params_hash)
      sample_user.update_column(:blocked, true)
      put :update, construct_params({ id: sample_user.id }, active: true)
      assert_response 405
    end
  end
end
