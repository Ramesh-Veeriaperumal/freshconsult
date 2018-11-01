require_relative '../../test_helper'

module Channel
  class ApiContactsControllerTest < ActionController::TestCase
    include UsersTestHelper
    include CustomFieldsTestHelper
    include JweTestHelper

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

    def test_create_contact
      set_jwt_auth_header('zapier')
      post :create, construct_params({version: 'channel'},  name: Faker::Lorem.characters(10),
                                        email: Faker::Internet.email)
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
      match_json([bad_request_error_pattern('email', :'Email has already been taken')])
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

    def test_get_a_twitter_contact_by_twitter_id
      set_jwt_auth_header('twitter')
      twitter_contact = @account.users.where('twitter_id is not null').limit(1).first
      get :index, controller_params(version: 'channel', twitter_id: twitter_contact.twitter_id)

      users = @account.all_contacts.order('users.name').select { |x|  x.twitter_id == twitter_contact.twitter_id }
      pattern = users.map { |user| index_contact_pattern(user) }
      match_json(pattern.ordered!)
      assert_response 200
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
  end
end
