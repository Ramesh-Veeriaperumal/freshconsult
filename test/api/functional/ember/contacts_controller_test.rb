require_relative '../../test_helper'

module Ember
  class ContactsControllerTest < ActionController::TestCase
    include UsersTestHelper
    include AttachmentsTestHelper
    include ContactFieldsHelper
    include TicketsTestHelper
    include ArchiveTicketTestHelper
    include CustomFieldsTestHelper

    BULK_CONTACT_CREATE_COUNT = 2

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      @private_api = true
      return if @@initial_setup_run

      @account.add_feature(:multiple_user_companies)
      @account.reload

      @@initial_setup_run = true
    end

    def wrap_cname(params)
      { contact: params }
    end

    def contact_params_hash
      params_hash = {
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email
      }
    end

    def create_n_users(count, account, params={})
      contact_ids = []
      count.times do
        contact_ids << add_new_user(account, params).id
      end
      contact_ids
    end

    def test_create_with_incorrect_avatar_type
      params_hash = contact_params_hash.merge(avatar_id: 'ABC')
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern(:avatar_id, :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
      assert_response 400
    end

    def test_create_with_avatar_and_avatar_id
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      params_hash = contact_params_hash.merge(avatar_id: attachment_id, avatar: file)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :create, construct_params({ version: 'private' }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      match_json([bad_request_error_pattern(:avatar_id, :only_avatar_or_avatar_id)])
      assert_response 400
    end

    def test_create_with_invalid_avatar_id
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_id = attachment_id + 10
      params_hash = contact_params_hash.merge(avatar_id: invalid_id)
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern(:avatar_id, :invalid_list, list: invalid_id.to_s)])
      assert_response 400
    end

    def test_create_with_invalid_avatar_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge(avatar_id: attachment_id)
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(20_000_000)
      post :create, construct_params({ version: 'private' }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:avatar_id, :invalid_size, max_size: '5 MB', current_size: '19.1 MB')])
      assert_response 400
    end

    def test_create_with_invalid_avatar_extension
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge(avatar_id: attachment_id)
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern(:avatar_id, :upload_jpg_or_png_file, current_extension: '.txt')])
      assert_response 400
    end

    def test_create_with_errors
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge(avatar_id: avatar_id)
      User.any_instance.stubs(:save).returns(false)
      post :create, construct_params({ version: 'private' }, params_hash)
      User.any_instance.unstub(:save)
      assert_response 500
    end

    def test_create_with_avatar_id
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge(avatar_id: avatar_id)
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      match_json(private_api_contact_pattern(User.last))
      assert User.last.avatar.id == avatar_id
    end

    # Tests for Multiple User companies feature

    def test_create_contact_with_default_company
      company_ids = Company.first(2).map(&:id)
      @account.revoke_feature(:multiple_user_companies)
      @account.reload
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             })
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      assert User.last.user_companies.find_by_default(true).company_id == company_ids[0]
      assert User.last.user_companies.find_by_default(true).client_manager == true
      assert User.last.user_companies.where(default: false) == []
      @account.add_feature(:multiple_user_companies)
      @account.reload
    end

    def test_update_contact_with_default_company
      company_ids = Company.first(2).map(&:id)
      @account.revoke_feature(:multiple_user_companies)
      @account.reload
      sample_user = add_new_user(@account)
      company_ids = Company.first(2).map(&:id)
      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      id: company_ids[0],
                                      view_all_tickets: true
                                    })
      assert_response 200
      pattern = private_api_contact_pattern(User.last)
      pattern.delete(:other_companies)
      match_json(pattern)
      assert User.last.user_companies.find_by_default(true).company_id == company_ids[0]
      assert User.last.user_companies.find_by_default(true).client_manager == true
      assert User.last.user_companies.where(default: false) == []
      @account.add_feature(:multiple_user_companies)
      @account.reload
    end

    def test_create_contact_with_other_companies
      company_ids = Company.first(2).map(&:id)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             },
                                                             other_companies: [
                                                               {
                                                                 id: company_ids[1],
                                                                 view_all_tickets: true
                                                               }
                                                             ])
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      assert User.last.user_companies.find_by_default(true).company_id == company_ids[0]
      assert User.last.user_companies.find_by_default(true).client_manager == true
      assert User.last.user_companies.find_by_default(false).company_id == company_ids[1]
      assert User.last.user_companies.find_by_default(false).client_manager == true
    end

    def test_create_contact_with_mandatory_company_field
      company_ids = Company.first(2).map(&:id)
      company_field = Account.current.contact_form.default_contact_fields.find { |cf| cf.name == "company_name" }
      company_field.update_attributes({:required_for_agent => true})
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             })
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      assert User.last.user_companies.find_by_default(true).company_id == company_ids[0]
      assert User.last.user_companies.find_by_default(true).client_manager == true
      company_field.update_attributes({:required_for_agent => false})
    end

    def test_error_in_create_contact_with_mandatory_company
      company_ids = Company.first(2).map(&:id)
      company_field = Account.current.contact_form.default_contact_fields.find { |cf| cf.name == "company_name" }
      company_field.update_attributes({:required_for_agent => true})
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email)
      assert_response 400
      match_json([bad_request_error_pattern(
        'company_id', :datatype_mismatch,
        expected_data_type: 'key/value pair')]
      )
      company_field.update_attributes({:required_for_agent => false})
    end

    def test_create_contact_with_other_companies_name
      comp_name1 = Faker::Lorem.characters(10)
      comp_name2 = Faker::Lorem.characters(10)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               name: comp_name1,
                                                               view_all_tickets: true
                                                             },
                                                             other_companies: [
                                                               {
                                                                 name: comp_name2,
                                                                 view_all_tickets: true
                                                               }
                                                             ])

      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      company_1 = Company.find_by_name(comp_name1)
      company_2 = Company.find_by_name(comp_name2)
      refute company_1.nil?
      refute company_2.nil?
      assert User.last.user_companies.find_by_default(true).company_id == company_1.id
      assert User.last.user_companies.find_by_default(true).client_manager == true
      assert User.last.user_companies.find_by_default(false).company_id == company_2.id
      assert User.last.user_companies.find_by_default(false).client_manager == true
    end

    def test_error_in_create_contact_without_feature
      company_ids = Company.first(2).map(&:id)
      @account.revoke_feature(:multiple_user_companies)
      @account.reload
      sample_user = add_new_user(@account)
      company_ids = Company.first(2).map(&:id)
      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      id: company_ids[0],
                                      view_all_tickets: true
                                    },
                                    other_companies: [
                                      {
                                        id: company_ids[1],
                                        view_all_tickets: true
                                      }
                                    ])
      assert_response 400
      match_json([bad_request_error_pattern(:other_companies,
                                            :require_feature_for_attribute,
                                            code: :inaccessible_field,
                                            attribute: 'other_companies',
                                            feature: :multiple_user_companies)])
      @account.add_feature(:multiple_user_companies)
      @account.reload
    end

    def test_error_in_create_contact_with_other_companies
      company_ids = Company.first(2).map(&:id)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             },
                                                             other_companies: [
                                                               {
                                                                 id: company_ids[0],
                                                                 view_all_tickets: true
                                                               }
                                                             ])
      assert_response 400
      match_json([bad_request_error_pattern(
        'other_companies',
        :cant_add_primary_resource_to_others,
        resource: (company_ids[0]).to_s,
        status: 'default company',
        attribute: 'other_companies'
      )])
    end

    def test_error_in_create_contact_with_other_companies_format
      company_ids = Company.first(2).map(&:id)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             },
                                                             other_companies: [
                                                               {
                                                                 company_id: company_ids[0],
                                                                 view_all_tickets: true
                                                               }
                                                             ])
      assert_response 400
      match_json([{ field: 'company_id',
                    message: 'Unexpected/invalid field in request',
                    code: :invalid_value }])
    end

    def test_error_in_create_contact_with_other_companies_duplicates
      company_ids = Company.first(2).map(&:id)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             },
                                                             other_companies: [
                                                               {
                                                                 id: company_ids[1],
                                                                 view_all_tickets: true
                                                               },
                                                               {
                                                                 id: company_ids[1],
                                                                 view_all_tickets: true
                                                               }
                                                             ])
      assert_response 400
      match_json([bad_request_error_pattern('other_companies', :duplicate_companies)])
    end

    def test_create_contact_without_default_company
      company_ids = Company.first(2).map(&:id)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             other_companies: [
                                                               {
                                                                 id: company_ids[1],
                                                                 view_all_tickets: true
                                                               }
                                                             ])
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      assert User.last.user_companies.find_by_default(true).company_id == company_ids[1]
      assert User.last.user_companies.find_by_default(true).client_manager == true
    end

    def test_update_contact_without_default_company
      sample_user = add_new_user(@account)
      company_ids = Company.first(2).map(&:id)
      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    other_companies: [
                                      {
                                        id: company_ids[1],
                                        view_all_tickets: true
                                      }
                                    ])
      assert_response 200
      pattern = private_api_contact_pattern(sample_user.reload)
      pattern.delete(:other_companies)
      match_json(pattern)
      assert sample_user.user_companies.find_by_default(true).company_id == company_ids[1]
      assert sample_user.user_companies.find_by_default(true).client_manager == true
    end

    def test_update_contact_with_default_company_2
      sample_user = add_new_user(@account)
      company_ids = Company.first(2).map(&:id)
      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      id: company_ids[0],
                                      view_all_tickets: true
                                    },
                                    other_companies: [
                                      {
                                        id: company_ids[1],
                                        view_all_tickets: true
                                      }
                                    ])
      assert_response 200
      pattern = private_api_contact_pattern(sample_user.reload)
      pattern.delete(:other_companies)
      match_json(pattern)
      assert sample_user.user_companies.find_by_default(true).company_id == company_ids[0]
      assert sample_user.user_companies.find_by_default(true).client_manager == true
      assert sample_user.user_companies.find_by_default(false).company_id == company_ids[1]
      assert sample_user.user_companies.find_by_default(false).client_manager == true
    end

    def test_update_contact_with_other_companies_name
      sample_user = add_new_user(@account)
      comp_name1 = Faker::Lorem.characters(10)
      comp_name2 = Faker::Lorem.characters(10)
      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      name: comp_name1,
                                      view_all_tickets: true
                                    },
                                    other_companies: [
                                      {
                                        name: comp_name2,
                                        view_all_tickets: true
                                      }
                                    ])
      assert_response 200
      pattern = private_api_contact_pattern(sample_user.reload)
      pattern.delete(:other_companies)
      match_json(pattern)
      company_1 = Company.find_by_name(comp_name1)
      company_2 = Company.find_by_name(comp_name2)
      refute company_1.nil?
      refute company_2.nil?
      assert sample_user.user_companies.find_by_default(true).company_id == company_1.id
      assert sample_user.user_companies.find_by_default(true).client_manager == true
      assert sample_user.user_companies.find_by_default(false).company_id == company_2.id
      assert sample_user.user_companies.find_by_default(false).client_manager == true
    end

    def test_update_contact_with_default_company_and_client_manager
      sample_user = add_new_user(@account)
      company_ids = Company.first(2).map(&:id)
      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      id: company_ids[0],
                                      view_all_tickets: false
                                    },
                                    other_companies: [
                                      {
                                        id: company_ids[1],
                                        view_all_tickets: false
                                      }
                                    ])
      assert_response 200
      pattern = private_api_contact_pattern(sample_user.reload)
      pattern.delete(:other_companies)
      match_json(pattern)
      assert sample_user.user_companies.find_by_default(true).company_id == company_ids[0]
      assert sample_user.user_companies.find_by_default(true).client_manager == false
      assert sample_user.user_companies.find_by_default(false).company_id == company_ids[1]
      assert sample_user.user_companies.find_by_default(false).client_manager == false
    end

    def test_create_and_update_contact_with_default_company_and_client_manager
      company_ids = Company.first(2).map(&:id)
      sample_user = create_contact_with_other_companies(@account, company_ids)

      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      id: company_ids[0],
                                      view_all_tickets: false
                                    },
                                    other_companies: [
                                      {
                                        id: company_ids[1],
                                        view_all_tickets: false
                                      }
                                    ])
      assert_response 200
      pattern = private_api_contact_pattern(sample_user.reload)
      pattern.delete(:other_companies)
      match_json(pattern)
      assert sample_user.user_companies.find_by_default(true).company_id == company_ids[0]
      assert sample_user.user_companies.find_by_default(true).client_manager == false
      assert sample_user.user_companies.find_by_default(false).company_id == company_ids[1]
      assert sample_user.user_companies.find_by_default(false).client_manager == false
    end

    def test_update_contact_by_removing_companies
      company_ids = Company.first(2).map(&:id)
      sample_user = create_contact_with_other_companies(@account, company_ids)

      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      id: company_ids[0],
                                      view_all_tickets: false
                                    },
                                    other_companies: [])
      assert_response 200
      pattern = private_api_contact_pattern(sample_user.reload)
      pattern.delete(:other_companies)
      match_json(pattern)
      assert sample_user.user_companies.find_by_default(true).company_id == company_ids[0]
      assert sample_user.user_companies.find_by_default(true).client_manager == false
      assert sample_user.user_companies.find_by_default(false).nil?
      assert sample_user.user_companies.find_by_company_id(company_ids[1]).nil?
    end

    def test_quick_create_contact_with_company_name
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          company_name: Faker::Lorem.characters(10))
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
    end

    def test_quick_create_length_invalid_company_name
      post :quick_create, construct_params({version: 'private'},
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(300)
      )
      match_json([bad_request_error_pattern('company_name', :too_long, element_type: :characters, max_count: "#{ApiConstants::MAX_LENGTH_STRING}", current_count: 300)])
      assert_response 400
    end

    # Skip validation tests
    def test_quick_create_contact_without_required_custom_fields
      cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))

      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          company_name: Faker::Lorem.characters(15))

      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      ensure
        cf.update_attribute(:required_for_agent, false)
    end

    def test_quick_create_with_all_default_fields_required_valid
      default_non_required_fiels = ContactField.where(required_for_agent: false,  column_name: 'default')
      default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          company_name: Faker::Lorem.characters(15)
                                    )
      assert_response 201
    ensure
      default_non_required_fiels.map { |x| x.toggle!(:required_for_agent) }
    end

    def test_quick_create_contact_without_any_contact_detail
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(10))
      match_json([bad_request_error_pattern('email', :missing_contact_detail)])
      assert_response 400
    end

    def test_quick_create_without_company
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(10),
                                          email: Faker::Internet.email)
      assert_response 201
    end

    # Show User
    def test_show_a_contact
      sample_user = add_new_user(@account)
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(private_api_contact_pattern(sample_user.reload))
      assert_response 200
    end

    # Show deleted agent(comes from contact show endpoint)
    def test_show_a_deleted_agent
      sample_user = Account.current.all_users.where(deleted: true, helpdesk_agent: true).first
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(deleted_agent_pattern(sample_user.reload))
      assert_response 200
    end

    def test_show_a_contact_with_avatar
      file = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      sample_user = add_new_user(@account)
      sample_user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(private_api_contact_pattern(sample_user.reload))
      assert_response 200
    end

    def test_show_a_contact_with_other_companies
      company_ids = Company.first(2).map(&:id)
      sample_user = create_contact_with_other_companies(@account, company_ids)
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(private_api_contact_pattern(sample_user.reload))
      assert_response 200
    end

    def test_show_a_contact_with_include_company
      company_ids = Company.first(2).map(&:id)
      sample_user = create_contact_with_other_companies(@account, company_ids)
      get :show, controller_params(version: 'private', id: sample_user.id, include: 'company')
      match_json(private_api_contact_pattern({ include: 'company' }, true, sample_user.reload))
      assert_response 200
    end

    def test_show_a_contact_with_include_company_other_companies
      sample_user = add_new_user(@account)
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(private_api_contact_pattern(sample_user.reload))
      assert_response 200
    end

    def test_show_a_non_existing_contact
      get :show, controller_params(version: 'private', id: 0)
      assert_response :missing
    end

    def test_deletion
      contact_id = add_new_user(@account).id
      delete :destroy, controller_params(version: 'private', id: contact_id)
      assert_response 204
    end

    def test_deletion_of_non_existing_contact
      contact_id = add_new_user(@account).id + 10
      delete :destroy, controller_params(version: 'private', id: contact_id)
      assert_response 404
    end

    def test_deletion_of_deleted_contact
      contact = add_new_user(@account, deleted: true)
      delete :destroy, controller_params(version: 'private', id: contact.id)
      assert_response 405
    end

    def test_deletion_with_errors
      contact = add_new_user(@account)
      User.any_instance.stubs(:save).returns(false)
      User.any_instance.stubs(:errors).returns(name: 'cannot be nil')
      delete :destroy, controller_params(version: 'private', id: contact.id)
      User.any_instance.unstub(:save)
      User.any_instance.unstub(:errors)
      assert_response 400
    end

    def test_restore
      contact = add_new_user(@account, deleted: true)
      put :restore, controller_params(version: 'private', id: contact.id)
      assert_response 204
    end

    def test_restoring_non_existing_contact
      contact_id = add_new_user(@account).id + 10
      put :restore, controller_params(version: 'private', id: contact_id)
      assert_response 404
    end

    def test_restoring_active_contact
      contact_id = add_new_user(@account).id
      put :restore, controller_params(version: 'private', id: contact_id)
      assert_response 404
    end

    def test_send_invite
      contact = add_new_user(@account, active: false)
      put :send_invite, controller_params(version: 'private', id: contact.id)
      assert_response 204
    end

    def test_send_invite_to_active_contact
      contact = add_new_user(@account, active: true)
      put :send_invite, controller_params(version: 'private', id: contact.id)
      match_json([bad_request_error_pattern('id', :unable_to_perform)])
      assert_response 400
    end

    def test_send_invite_to_deleted_contact
      contact = add_new_user(@account, deleted: true, active: false)
      put :send_invite, controller_params(version: 'private', id: contact.id)
      match_json([bad_request_error_pattern('id', :unable_to_perform)])
      assert_response 400
    end

    def test_index_with_tags
      tags = Faker::Lorem.words(3).uniq
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account, tags: tags)
      get :index, controller_params(version: 'private', tag: tags[0])
      assert_response 200
      assert response.api_meta[:count] == contact_ids.size
    end

    def test_index_with_invalid_tags
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      get :index, controller_params(version: 'private', tag: Faker::Lorem.word)
      assert_response 200
      assert response.api_meta[:count] == 0
    end

    def test_index_with_contacts_having_avatar
      BULK_CONTACT_CREATE_COUNT.times do
        contact = add_new_user(@account)
        add_avatar_to_user(contact)
      end
      get :index, controller_params(version: 'private')
      assert_response 200
      match_json(private_api_index_contact_pattern)
    end

    def test_bulk_delete_with_no_params
      put :bulk_delete, construct_params({ version: 'private' }, {})
      assert_response 400
      match_json([bad_request_error_pattern('ids', :missing_field)])
    end

    def test_bulk_delete_with_invalid_ids
      contact_ids = create_n_users(1, @account)
      invalid_ids = [contact_ids.last + 20, contact_ids.last + 30]
      ids_to_delete = [*contact_ids, *invalid_ids]
      put :bulk_delete, construct_params({ version: 'private' }, ids: ids_to_delete)
      failures = {}
      invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
      match_json(partial_success_response_pattern(contact_ids, failures))
      assert_response 202
    end

    def test_bulk_delete_with_errors_in_deletion
      ids_to_delete = create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      User.any_instance.stubs(:save).returns(false)
      put :bulk_delete, construct_params({ version: 'private' }, ids: ids_to_delete)
      failures = {}
      ids_to_delete.each { |id| failures[id] = { id: :unable_to_perform } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_delete_with_valid_ids
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      put :bulk_delete, construct_params({ version: 'private' }, ids: contact_ids)
      assert_response 204
    end

    def bulk_restore
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account, deleted: true)
      put :bulk_restore, construct_params({ version: 'private' }, ids: contact_ids)
      assert_response 204
    end

    def test_bulk_restore_of_active_contacts
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      put :bulk_restore, construct_params({ version: 'private' }, ids: contact_ids)
      failures = {}
      contact_ids.each { |id| failures[id] = { id: :unable_to_perform } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_send_invite
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account, active: false)
      put :bulk_send_invite, construct_params({ version: 'private' }, ids: contact_ids)
      assert_response 204
    end

    def test_bulk_send_invite_to_deleted_contacts
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account, deleted: true)
      valid_contact = add_new_user(@account, active: false)
      put :bulk_send_invite, construct_params({ version: 'private' }, ids: [*contact_ids, valid_contact.id])
      failures = {}
      contact_ids.each { |id| failures[id] = { id: :unable_to_perform } }
      match_json(partial_success_response_pattern([valid_contact.id], failures))
      assert_response 202
    end

    # Whitelist user
    def test_whitelist_contact
      sample_user = create_blocked_contact(@account)
      put :whitelist, construct_params({ version: 'private' }, false).merge(id: sample_user.id)
      assert_response 204
      confirm_user_whitelisting([sample_user.id])
    end

    def test_whitelist_an_invalid_contact
      put :whitelist, construct_params({ version: 'private' }, false).merge(id: 0)
      assert_response 404
    end

    def test_whitelist_an_unblocked_contact
      sample_user = add_new_user(@account)
      put :whitelist, construct_params({ version: 'private' }, false).merge(id: sample_user.id)
      assert_response 400
      match_json([bad_request_error_pattern(:blocked, 'is false. You can whitelist only blocked users.')])
    end

    # bulk whitelist users
    def test_bulk_whitelist_with_no_params
      put :bulk_whitelist, construct_params({ version: 'private' }, {})
      assert_response 400
      match_json([bad_request_error_pattern('ids', :missing_field)])
    end

    def test_bulk_whitelist_with_invalid_ids
      contact_ids = create_n_users(1, @account, blocked: true, blocked_at: Time.zone.now)
      last_id = contact_ids.max
      invalid_ids = [last_id + 50, last_id + 100]
      ids_to_whitelist = [*contact_ids, *invalid_ids]
      put :bulk_whitelist, construct_params({ version: 'private' }, ids: ids_to_whitelist)
      failures = {}
      invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
      match_json(partial_success_response_pattern(contact_ids, failures))
      assert_response 202
      confirm_user_whitelisting(contact_ids)
    end

    def test_bulk_whitelist_with_errors_in_whitelisting
      ids_to_whitelist = create_n_users(BULK_CONTACT_CREATE_COUNT, @account, blocked: true, blocked_at: Time.zone.now)
      User.any_instance.stubs(:save).returns(false)
      put :bulk_whitelist, construct_params({ version: 'private' }, ids: ids_to_whitelist)
      failures = {}
      ids_to_whitelist.each { |id| failures[id] = { id: :unable_to_perform } }
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_whitelist_with_valid_ids
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account, blocked: true, blocked_at: Time.zone.now)
      put :bulk_whitelist, construct_params({ version: 'private' }, ids: contact_ids)
      assert_response 204
      confirm_user_whitelisting(contact_ids)
    end

    # tests for password change
    # 1. cannot change passowrd for a spam contact
    # 2. cannot change passowrd for a deleted contact
    # 3. cannot change passowrd for a agent contact
    # 4. cannot change passowrd for a contact without email
    # 5. cannot change passowrd for a blocked contact
    # 6. update with empty params
    # 7. update with password with nil value
    # 8. update with few characters to check basic password policy error
    # 9. update with proper password

    def test_update_password_for_spam_contact
      contact = add_new_user(@account, deleted: true)
      contact.deleted_at = Time.now
      contact.save
      put :update_password, construct_params({ version: 'private', id: contact.id }, password: random_password)
      assert_response 400
      match_json(password_change_error_pattern(:not_allowed))
    end

    def test_update_password_for_deleted_contact
      contact = add_new_user(@account, deleted: true)
      put :update_password, construct_params({ version: 'private', id: contact.id }, password: random_password)
      assert_response 400
      match_json(password_change_error_pattern(:not_allowed))
    end

    def test_update_password_for_agent
      agent = add_agent_to_account(@account, name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1)
      put :update_password, construct_params({ version: 'private', id: agent.user.id }, password: random_password)
      assert_response 404
    end

    def test_update_password_for_blocked_contact
      contact = create_blocked_contact(@account)
      put :update_password, construct_params({ version: 'private', id: contact.id }, password: random_password)
      assert_response 400
      match_json(password_change_error_pattern(:not_allowed))
    end

    def test_update_password_for_contact_without_email
      contact = create_tweet_user
      put :update_password, construct_params({ version: 'private', id: contact.id }, password: random_password)
      assert_response 400
      match_json(password_change_error_pattern(:not_allowed))
    end

    def test_update_password_with_empty_params
      contact = add_new_user(@account, deleted: false, active: true)
      put :update_password, construct_params({ version: 'private', id: contact.id }, {})
      assert_response 400
      match_json(password_change_error_pattern(:missing_field))
    end

    def test_update_password_with_nil_value
      contact = add_new_user(@account, deleted: false, active: true)
      put :update_password, construct_params({ version: 'private', id: contact.id }, password: nil)
      assert_response 400
      match_json(password_change_error_pattern(:datatype_mismatch))
    end

    def test_update_password_for_password_policy_check
      contact = add_new_user(@account, deleted: false, active: true)
      put :update_password, construct_params({ version: 'private', id: contact.id }, password: random_password[0])
      assert_response 400
    end

    def test_update_password_with_proper_password
      contact = add_new_user(@account, deleted: false, active: true)
      put :update_password, construct_params({ version: 'private', id: contact.id }, password: random_password)
      assert_response 204
    end

    # Tests for assume identity

    # 1. assume identity with valid id
    # 2. assume identity with invalid id
    # 3. assume identity without feature
    # 4. assume identity without manage_users privilege

    def test_assume_identity_with_valid_id
      contact = add_new_user(@account, deleted: false, active: true)
      assume_contact = add_new_user(@account, deleted: false, active: true)
      put :assume_identity, construct_params({ version: 'private', id: assume_contact.id }, nil)
      assert_response 204
      assert session['assumed_user'] == assume_contact.id
    end

    def test_assume_identity_with_invalid_id
      assume_contact = add_new_user(@account, deleted: false, active: true)
      put :assume_identity, construct_params({ version: 'private', id: assume_contact.id + 10 }, nil)
      assert_response 404
    end

    def test_assume_identity_without_feature
      contact = add_new_user(@account, deleted: false, active: true)
      assume_contact = add_new_user(@account, deleted: false, active: true)
      Account.any_instance.stubs(:has_feature?).with(:assume_identity).returns(false)
      Account.any_instance.stubs(:has_feature?).with(:falcon).returns(true)
      put :assume_identity, construct_params({ version: 'private', id: assume_contact.id }, nil)
      Account.any_instance.unstub(:has_feature?)
      assert_response 400
      match_json(assume_identity_error_pattern)
    end

    def test_assume_identity_without_manage_users_privilege
      contact = add_new_user(@account, deleted: false, active: true)
      assume_contact = add_new_user(@account, deleted: false, active: true)
      User.any_instance.stubs(:privilege?).with(:manage_users).returns(false)
      put :assume_identity, construct_params({ version: 'private', id: assume_contact.id }, nil)
      User.any_instance.unstub(:privilege?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_update_remove_avatar
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
      contact = add_new_user(@account, avatar: avatar)
      put :update, construct_params({ version: 'private', id: contact.id }, avatar_id: nil)
      assert_response 200
      contact.reload
      match_json(private_api_contact_pattern(contact))
      assert contact.avatar.nil?
    end

    def test_update_change_avatar
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
      contact = add_new_user(@account, avatar: avatar)
      new_avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
      put :update, construct_params({ version: 'private', id: contact.id }, avatar_id: new_avatar.id)
      assert_response 200
      contact.reload
      match_json(private_api_contact_pattern(contact))
      assert contact.avatar.id == new_avatar.id
    end

    def test_update_add_avatar
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
      contact = add_new_user(@account)
      put :update, construct_params({ version: 'private', id: contact.id }, avatar_id: avatar.id)
      assert_response 200
      contact.reload
      match_json(private_api_contact_pattern(contact))
      assert contact.avatar.id == avatar.id
    end

    def test_update_avatar_and_contact_update_failure
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
      avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
      contact = add_new_user(@account)
      other_contact = add_new_user(@account)
      put :update, construct_params({ version: 'private', id: contact.id }, avatar_id: avatar.id, email: other_contact.email)
      assert_response 409
      contact.reload
      assert contact.avatar.nil?
    end

    # tests for contact activities

    # 1. contact with no activity
    # 2. contact with forum activity
    # 3. contact with ticket activity
    # 4. contact with archived ticket activity
    # 5. contact with combined activities

    def test_contact_without_activity
      contact = add_new_user(@account, deleted: false, active: true)
      get :activities, construct_params({ version: 'private', id: contact.id }, nil)
      assert_response 200
      match_json({})
    end

    def test_contact_with_forum_activity
      contact = add_new_user(@account, deleted: false, active: true)
      sample_user_topics(contact)
      get :activities, construct_params({ version: 'private', id: contact.id, type: 'forums' }, nil)
      assert_response 200
      match_json(user_activity_response(contact.recent_posts))
    end

    def test_contact_with_ticket_activity
      contact = add_new_user(@account, deleted: false, active: true)
      user_tickets = sample_user_tickets(contact)
      get :activities, construct_params({ version: 'private', id: contact.id, type: 'tickets' }, nil)
      assert_response 200
      match_json(user_activity_response(user_tickets))
    end

    def test_contact_with_archived_ticket_activity
      enable_archive_tickets do
        contact = add_new_user(@account, deleted: false, active: true)
        stub_archive_assoc(account_id: @account.id) do
          user_archived_tickets = sample_user_archived_tickets(contact)
          get :activities, construct_params({ version: 'private', id: contact.id, type: 'archived_tickets' }, nil)
          assert_response 200
          match_json(user_activity_response(user_archived_tickets))
        end
      end
    end

    def test_contact_with_combined_activity
      contact = add_new_user(@account, deleted: false, active: true)
      objects = user_combined_activities(contact)
      get :activities, construct_params({ version: 'private', id: contact.id }, nil)
      assert_response 200
      match_json(user_activity_response(objects))
    end

    def test_export_csv_with_no_params
      create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      contact_form = @account.contact_form
      post :export_csv, construct_params({ version: 'private' }, {})
      assert_response 400
      match_json([bad_request_error_pattern(:request, :select_a_field)])
    end

    def test_export_csv_with_invalid_params
      create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      contact_form = @account.contact_form
      params_hash = { default_fields: [Faker::Lorem.word], custom_fields: [Faker::Lorem.word] }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:default_fields, :not_included, list: (contact_form.default_contact_fields.map(&:name)-["tag_names"]).join(',')),
                  bad_request_error_pattern(:custom_fields, :not_included, list: (contact_form.custom_contact_fields.map(&:name).collect { |x| x[3..-1] }).join(','))])
    end

    def test_export_csv
      create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Area', editable_in_signup: 'true'))
      create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Metropolitian City', editable_in_signup: 'true'))
      create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'Joining date', editable_in_signup: 'true'))

      create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      default_fields = @account.contact_form.default_contact_fields
      custom_fields = @account.contact_form.custom_contact_fields
      Export::ContactWorker.jobs.clear
      params_hash = { default_fields: default_fields.map(&:name) - ['tag_names'], custom_fields: custom_fields.map(&:name).collect { |x| x[3..-1] } }
      post :export_csv, construct_params({ version: 'private' }, params_hash)
      assert_response 204
      sidekiq_jobs = Export::ContactWorker.jobs
      assert_equal 1, sidekiq_jobs.size
      csv_hash = (default_fields | custom_fields).collect { |x| { x.label => x.name } }.inject(&:merge).except('Tags')
      assert_equal csv_hash, sidekiq_jobs.first['args'][0]['csv_hash']
      assert_equal User.current.id, sidekiq_jobs.first['args'][0]['user']
      Export::ContactWorker.jobs.clear
    end

    def test_create_with_invalid_email_and_custom_field_email
      create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'email', editable_in_signup: 'true'))
      params = contact_params_hash.merge(custom_fields: { email: 0 })
      params[:email] = Faker::Name.name
      byebug
      post :create, construct_params({ version: 'private' }, params)
      match_json([
        bad_request_error_pattern(:email, :invalid_format, accepted: 'valid email address'), 
        bad_request_error_pattern(custom_field_error_label('email'), :datatype_mismatch, expected_data_type: 'String', given_data_type: 'Integer', prepend_msg: :input_received)
      ])
      assert_response 400
    end

  end
end
