require_relative '../../test_helper'
require Rails.root.join('spec', 'support', 'social_tickets_creation_helper.rb')

module Channel
  class ApiContactsControllerTest < ActionController::TestCase
    include UsersTestHelper
    include CustomFieldsTestHelper
    include JweTestHelper
    include ::SocialTicketsCreationHelper

    SUPPORT_BOT = 'frankbot'.freeze

    def setup
      super
      @account.reload
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

    def test_create_contact_with_invalid_company_id
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'},
      name: Faker::Lorem.characters(10), email: Faker::Internet.email,
      company_id: 999999999)
      assert_response 400
      match_json([bad_request_error_pattern('company_id', :absent_in_db,
        resource: :company, attribute: :company_id)])
    end

    def test_create_contact
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'},
      name: Faker::Lorem.characters(10), email: Faker::Internet.email)
      assert_response 201
      match_json(deleted_contact_pattern(User.last))
    end

    def test_create_contact_without_any_contact_detail
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'},  name: Faker::Lorem.characters(10))
      match_json([bad_request_error_pattern('email', :missing_contact_detail)])
      assert_response 400
    end

    def test_create_contact_with_existing_email
      set_jwt_auth_header('zapier')
      email = Faker::Internet.email
      add_new_user(@account, name: Faker::Lorem.characters(15), email: email)
      post :create, construct_params({version: 'channel'},  name: Faker::Lorem.characters(15),
                                        email: email)
      additional_info = parse_response(@response.body)['errors'][0]['additional_info']
      match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'Email has already been taken')])
      assert_response 409
    end

    def test_create_contact_with_invalid_custom_fields
      set_jwt_auth_header('zapier')
      comp = get_company
      create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Check Me', editable_in_signup: 'true'))
      create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'DOJ', editable_in_signup: 'true'))
      post :create, construct_params({version: 'channel'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          view_all_tickets: true,
                                          company_id: comp.id,
                                          language: 'en',
                                          custom_fields: { 'check_me' => 'aaa', 'doj' => 2010 })
      assert_response 400
      match_json([bad_request_error_pattern(custom_field_error_label('check_me'), :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                bad_request_error_pattern(custom_field_error_label('doj'), :invalid_date, accepted: 'yyyy-mm-dd')])
    end

    def test_create_contact_without_required_custom_fields
      cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'another_city', editable_in_signup: 'true', required_for_agent: 'true'))

      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email)

      assert_response 201
      match_json(deleted_contact_pattern(User.last))
      ensure
        cf.update_attribute(:required_for_agent, false)
    end

    def test_create_contact_with_custom_fields
      set_jwt_auth_header('zapier')
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
      @account.reload

      post :create, construct_params({version: 'channel'},  name: Faker::Lorem.characters(15),
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

    def test_create_contact_without_jwt_header
      post :create, construct_params({version: 'channel'},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email)
      assert_response 401
    end

    def test_show_a_contact
      set_jwe_auth_header(SUPPORT_BOT)
      sample_user = add_new_user(@account)
      get :show, controller_params(version: 'channel', id: sample_user.id)
      ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
      match_json(contact_pattern(sample_user.reload).except(*ignore_keys))
      assert_response 200
    end

    def test_show_a_contact_with_avatar
      set_jwe_auth_header(SUPPORT_BOT)
      file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      sample_user = add_new_user(@account)
      sample_user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
      get :show, controller_params(version: 'channel', id: sample_user.id)
      ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
      match_json(contact_pattern(sample_user.reload).except(*ignore_keys))
      assert_response 200
    end

    def test_show_a_non_existing_contact
      set_jwe_auth_header(SUPPORT_BOT)
      sample_user = add_new_user(@account)
      get :show, controller_params(version: 'channel', id: 0)
      assert_response 404
    end

    def test_show_a_deleted_contact
      set_jwe_auth_header(SUPPORT_BOT)
      sample_user = add_new_user(@account)
      sample_user.update_column(:deleted, true)
      get :show, controller_params(version: 'channel', id: sample_user.id)
      match_json(deleted_contact_pattern(sample_user.reload))
      assert_response 200
    end

    def test_show_a_contact_with_unique_external_id
      set_jwe_auth_header(SUPPORT_BOT)
      @account.add_feature(:unique_contact_identifier)
      sample_user = add_new_user(@account)
      get :show, controller_params(version: 'channel', id: sample_user.id)
      match_json(unique_external_id_contact_pattern(sample_user.reload))
      assert_response 200
    ensure
      @account.revoke_feature(:unique_contact_identifier)
    end

    def test_create_contact_freshmover_skipping_validation
      CustomRequestStore.store[:channel_api_request] = true
      cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'another_city', editable_in_signup: 'true', required_for_agent: 'true'))
      set_jwt_auth_header('freshmover')
      payload = channel_contact_create_payload
      post :create, construct_params({ version: 'channel' }, payload)
      assert_response 201
      ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
      match_json(channel_contact_pattern(User.last.reload).except(*ignore_keys))
    ensure
      CustomRequestStore.store[:channel_api_request] = false
      cf.update_attribute(:required_for_agent, false)
    end

    def test_create_contact_validation_failure
      Account.any_instance.stubs(:multi_timezone_enabled?).returns(false)
      Account.any_instance.stubs(:features?).with(:multi_language).returns(false)
      Account.any_instance.stubs(:features?).with(:multiple_user_companies).returns(false)
      set_jwt_auth_header('freshmover')
      payload = channel_contact_create_payload
      payload[:whitelisted] = '123'
      post :create, construct_params({ version: 'channel' }, payload)
      assert_response 400
      match_json([bad_request_error_pattern('language', :require_feature_for_attribute, code: :inaccessible_field,
                                                                                        attribute: 'language', feature: :multi_language),
                  bad_request_error_pattern('time_zone', :require_feature_for_attribute, code: :inaccessible_field,
                                                                                         attribute: 'time_zone', feature: :multi_timezone),
                  bad_request_error_pattern('whitelisted', :datatype_mismatch,
                                            expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
    end

    def test_create_contact_without_authentication_header
      post :create, construct_params({ version: 'channel' },
                                     name: Faker::Lorem.characters(10),
                                     email: Faker::Internet.email)
      assert_response 401
      match_json(request_error_pattern(:invalid_credentials))
    end

    def test_show_a_contact_with_avatar_freshmover
      CustomRequestStore.store[:channel_api_request] = true
      set_jwt_auth_header('freshmover')
      file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      sample_user = add_new_user(@account)
      sample_user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
      get :show, controller_params(version: 'channel', id: sample_user.id)
      ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
      match_json(channel_contact_pattern(sample_user.reload).except(*ignore_keys))
      assert_response 200
    ensure
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_show_a_contact_without_authentication_header
      sample_user = add_new_user(@account)
      get :show, controller_params(version: 'channel', id: sample_user.id)
      assert_response 401
      match_json(request_error_pattern(:invalid_credentials))
    end

    def test_create_a_twitter_contact
      set_jwt_auth_header('twitter')
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10),
                                                             twitter_id: Faker::Internet.email) # for now using email as twitter_id.
      assert_response 201
      match_json(deleted_contact_pattern(User.last))
    end

    def test_create_a_twitter_contact_with_valid_requester_fields
      CustomRequestStore.store[:channel_api_request] = true
      set_jwt_auth_header('twitter')
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10),
                                                             twitter_id: Faker::Internet.email,
                                                             twitter_profile_status: true,
                                                             twitter_followers_count: 1000)
      assert_response 201
      match_json(deleted_contact_pattern(User.last))
    ensure
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_create_a_twitter_contact_with_invalid_requester_fields
      CustomRequestStore.store[:channel_api_request] = true
      set_jwt_auth_header('twitter')
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10),
                                                             twitter_id: Faker::Internet.email,
                                                             twitter_profile_status: 'true',
                                                             twitter_followers_count: 'abc')
      assert_response 400
      match_json([bad_request_error_pattern('twitter_profile_status', :datatype_mismatch,
                                            expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String),
                  bad_request_error_pattern('twitter_followers_count', :not_a_number, code: :invalid_value)])
    ensure
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_create_a_twitter_contact_with_valid_requester_handle_id
      Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
      CustomRequestStore.store[:channel_api_request] = true
      set_jwt_auth_header('twitter')
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10),
                                                             twitter_id: Faker::Internet.email,
                                                             twitter_requester_handle_id: '1234567890')
      assert_response 201
      assert User.last.twitter_requester_handle_id?
      assert_equal '1234567890', User.last.twitter_requester_handle_id
      match_json(deleted_contact_pattern(User.last))
    ensure
      CustomRequestStore.store[:channel_api_request] = false
      Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    end

    def test_create_a_twitter_contact_with_invalid_requester_handle_id
      Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
      CustomRequestStore.store[:channel_api_request] = true
      set_jwt_auth_header('twitter')
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10),
                                                             twitter_id: Faker::Internet.email,
                                                             twitter_requester_handle_id: 1_234_567_890)
      assert_response 400
      match_json([bad_request_error_pattern('twitter_requester_handle_id', :datatype_mismatch,
                                            expected_data_type: 'String', prepend_msg: :input_received, given_data_type: Integer)])
    ensure
      CustomRequestStore.store[:channel_api_request] = false
      Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    end

    def test_create_a_twitter_contact_with_valid_requester_handle_id_without_feature
      CustomRequestStore.store[:channel_api_request] = true
      set_jwt_auth_header('twitter')
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10),
                                                             twitter_id: Faker::Internet.email,
                                                             twitter_requester_handle_id: '1234567890')
      assert_response 400
      match_json([bad_request_error_pattern('twitter_requester_handle_id', :require_feature_for_attribute, code: :inaccessible_field,
                                                                                                           attribute: 'twitter_requester_handle_id', feature: :twitter_api_compliance)])
    ensure
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_create_contact_without_twitter_id
      set_jwt_auth_header('twitter')
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10))
      match_json([bad_request_error_pattern('email', :missing_contact_detail)])
      assert_response 400
    end

    def test_create_a_twitter_contact_without_auth
      post :create, construct_params({ version: 'channel' }, name: Faker::Lorem.characters(10),
                                                             twitter_id: Faker::Internet.email)
      assert_response 401
    end

    def test_list_contacts_for_proactive
        set_jwt_auth_header('proactive')
        get :index, controller_params( version: 'channel', email: 'emily@freshdesk.com')
        assert_response 200
    end

    def test_get_a_twitter_contact_by_twitter_id
      set_jwt_auth_header('twitter')
      twitter_contact = @account.users.where('twitter_id is not null').limit(1).first
      get :index, controller_params(version: 'channel', twitter_id: twitter_contact.twitter_id)

      users = @account.all_contacts.order('users.name').select { |x|  x.twitter_id == twitter_contact.twitter_id }
      pattern = users.map { |user| index_contact_pattern(user) }
      match_json(pattern.ordered!)
      assert_response 200
    end

    def test_get_a_fb_contact_by_facebook_id
      fb_user = create_fb_user(name: Faker::Lorem.characters(10), id: rand(100).to_s)
      User.reset_current_user
      set_jwt_auth_header('facebook')
      get :index, controller_params(version: 'channel', facebook_id: fb_user.fb_profile_id)

      users = @account.all_contacts.select { |x|  x.fb_profile_id == fb_user.fb_profile_id }
      pattern = users.map { |user| index_contact_pattern(user) }
      match_json(pattern.ordered!)
      assert_response 200
    end

    def test_index_with_invalid_source_in_jwt
      fb_user = create_fb_user(name: Faker::Lorem.characters(10), id: rand(100).to_s)
      payload = { enc_payload: { account_id: @account.id, timestamp: Time.now.iso8601 } }
      @request.env['X-Channel-Auth'] = JWT.encode payload, CHANNEL_API_CONFIG[:facebook][:jwt_secret], 'HS256',
                                                  source: Faker::Lorem.characters(5)
      @controller.instance_variable_set('@current_user', nil)
      get :index, controller_params(version: 'channel', facebook_id: fb_user.fb_profile_id)
      assert_response 401
    end

    def test_list_contacts_for_freshmover
      set_jwt_auth_header('freshmover')
      get :index, controller_params(version: 'channel')
      users = @account.all_contacts.where(deleted: false)
      user_size = users.size < 30 ? users.size : 30
      assert_response 200
      response = parse_response @response.body
      assert_equal response.size, user_size
    end

    def test_list_contact_without_auth
      get :index, controller_params(version: 'channel')
      assert_response 401
    end

    def test_fetch_contact_by_email
      sample_user = add_new_user(@account)
      sample_user.company = get_company
      User.any_instance.stubs(:company).returns(get_company)
      set_jwt_auth_header('proactive')
      get :fetch_contact_by_email, controller_params(version: 'channel', email: sample_user.email)
      ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
      assert_response 200
    end

    def test_fetch_contact_by_email_not_found
      set_jwt_auth_header('proactive')
      get :fetch_contact_by_email, controller_params(version: 'channel', email: 'emily@freshdesk.com')
      assert_response 404
    end

    def test_fetch_contact_by_email_no_header
      get :fetch_contact_by_email, controller_params(version: 'channel', email: 'emily@freshdesk.com')
      assert_response 403
    end

    def test_update_contact
      set_jwt_auth_header('freshmover')
      user = add_new_user(@account)
      name = Faker::Lorem.characters(15)
      put :update, construct_params({ version: 'channel', id: user.id }, name: name, import_id: user.id)
      assert_response 200
      user = user.reload
      assert_equal user.name, name
      assert_equal user.import_id, user.id
    end

    def test_update_contact_without_auth
      user = add_new_user(@account)
      name = Faker::Lorem.characters(15)
      put :update, construct_params({ version: 'channel', id: user.id }, name: name)
      assert_response 401
    end

    def test_update_contact_validation_failure
      set_jwt_auth_header('freshmover')
      user = add_new_user(@account)
      current_time = '2020-05-10 08:08:08'
      put :update, construct_params({ version: 'channel', id: user.id }, created_at: current_time, updated_at: current_time)
      assert_response 400
      match_json([
                   bad_request_error_pattern('created_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('updated_at', :invalid_date, accepted: 'combined date and time ISO8601')
                 ])
    end

    def test_update_contact_with_timestamps
      set_jwt_auth_header('freshmover')
      user = add_new_user(@account)
      created_at = updated_at = Time.current - 10.days
      put :update, construct_params({ version: 'channel', id: user.id }, created_at: created_at, updated_at: updated_at)
      assert_response 200
      user = user.reload
      assert (user.created_at - created_at).to_i.zero?
      assert (user.updated_at - updated_at).to_i.zero?
    end
  end
end
