require_relative '../../test_helper'
['surveys_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }
['social_tickets_creation_helper.rb', 'twitter_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require 'webmock/minitest'
WebMock.allow_net_connect!

module Ember
  class ContactsControllerTest < ActionController::TestCase
    include SocialTicketsCreationHelper
    include TwitterHelper
    include UsersTestHelper
    include AttachmentsTestHelper
    include ContactFieldsHelper
    include ApiTicketsTestHelper
    include ArchiveTicketTestHelper
    include CustomFieldsTestHelper
    include TimelineTestHelper
    include SurveysTestHelper

    BULK_CONTACT_CREATE_COUNT = 2
    BASE_URL_CONTACT_TIMELINE = 'http://hypertrail-dev.freshworksapi.com/api/v2/activities/account'.freeze

    def setup
      super
      initial_setup
      Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(Faker::Number.between(1, 999_999_999).to_s))
    end

    @@initial_setup_run = false

    def initial_setup
      @private_api = true
      return if @@initial_setup_run

      @account.add_feature(:multiple_user_companies)
      @account.reload
      WebMock.disable_net_connect!

      @@initial_setup_run = true
    end

    def teardown
      super
      WebMock.allow_net_connect!
      Twitter::REST::Client.any_instance.unstub(:user)
    end

    def wrap_cname(params)
      query_params = params[:query_params]
      cparams = params.clone
      cparams.delete(:query_params)
      return query_params.merge(contact: cparams) if query_params

      { contact: cparams }
    end

    def contact_params_hash
      params_hash = {
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email
      }
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

    def create_n_users(count, account, params = {})
      contact_ids = []
      count.times do
        contact_ids << add_new_user(account, params).id
      end
      contact_ids
    end

    def create_n_marked_for_hard_delete_users(count, account, params = {})
      contact_ids = []
      count.times do
        contact_ids << add_marked_for_hard_delete_user(account, params).id
      end
      contact_ids
    end

    def construct_other_companies_hash(company_ids)
      other_companies = []
      (1..company_ids.count - 1).each do |itr|
        company_hash = {}
        company_hash[:id] = company_ids[itr]
        company_hash[:view_all_tickets] = true
        other_companies.push(company_hash)
      end
      other_companies
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

    def test_update_contact_with_existing_email
      user1 = add_new_user(@account)
      user2 = add_new_user_without_email(@account)
      email = user1.email
      put :update, construct_params({ id: user2.id }, email: email)
      additional_info = parse_response(@response.body)['errors'][0]['additional_info']
      assert_response 409
      match_json([bad_request_error_pattern_with_additional_info('email', additional_info, :'Email has already been taken')])
    end

    def test_create_contact_without_name
      name_field = Account.current.contact_form.default_fields.find_by_name('name')
      name_field.required_for_agent = false
      name_field.save!
      Account.current.reload
      params_hash = {
        email: Faker::Internet.email
      }
      post :create, construct_params({ version: 'private' }, params_hash)
      assert_response 201
      contact_name = parse_response(@response.body)['name'].downcase!
      contact_name_from_mail = params_hash[:email].split('@')[0]
      assert_equal contact_name, contact_name_from_mail
    ensure
      name_field.required_for_agent = true
      name_field.save!
      Account.current.reload
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

    def test_create_with_incorrect_avatar_type
      params_hash = contact_params_hash.merge(avatar_id: 'ABC')
      post :create, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern(:avatar_id, :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
      assert_response 400
    end

    def test_create_with_avatar_and_avatar_id
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
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
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
      avatar_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = contact_params_hash.merge(avatar_id: avatar_id)
      User.any_instance.stubs(:save).returns(false)
      post :create, construct_params({ version: 'private' }, params_hash)
      User.any_instance.unstub(:save)
      assert_response 500
    end

    def test_create_with_avatar_id
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
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
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
      @account.revoke_feature(:multiple_user_companies)
      @account.reload
      sample_user = add_new_user(@account)
      company_ids = [create_company, create_company].map(&:id)
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

    def test_create_contact_with_view_all_tickets_as_nil
      company_ids = [create_company, create_company].map(&:id)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: nil
                                                             },
                                                             other_companies: [
                                                               {
                                                                 id: company_ids[1],
                                                                 view_all_tickets: nil
                                                               }
                                                             ])
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      assert User.last.user_companies.find_by_default(true).company_id == company_ids[0]
      assert User.last.user_companies.find_by_default(true).client_manager == false
      assert User.last.user_companies.find_by_default(false).company_id == company_ids[1]
      assert User.last.user_companies.find_by_default(false).client_manager == false
    end

    def test_create_contact_with_other_companies
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
      company_field = Account.current.contact_form.default_contact_fields.find { |cf| cf.name == "company_name" }
      company_field.update_attributes({:required_for_agent => true})
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email)
      assert_response 400
      match_json([bad_request_error_pattern(
        'company', :datatype_mismatch,
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
      company_ids = [create_company, create_company].map(&:id)
      @account.revoke_feature(:multiple_user_companies)
      @account.reload
      sample_user = add_new_user(@account)
      company_ids = [create_company, create_company].map(&:id)
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

    def test_error_in_create_with_more_than_max_companies
      company_ids = (1..User::MAX_USER_COMPANIES + 1).to_a
      other_companies_param = construct_other_companies_hash(company_ids)
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             },
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
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: Faker::Internet.email,
                                                             company: {
                                                               id: company_ids[0],
                                                               view_all_tickets: true
                                                             },
                                                             other_companies: other_companies_param)
      assert_response 400
      match_json([{ field: 'other_companies',
                    message: "Has #{user_companies_limit} elements, it can have maximum of #{user_companies_limit - 1} elements",
                    code: :invalid_value }])
    ensure
      reset_max_extended_companies
    end

    def test_error_in_create_contact_with_other_companies
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
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

    def test_update_contact_with_view_all_tickets_as_nil
      sample_user = add_new_user(@account)
      company_ids = [create_company, create_company].map(&:id)
      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: {
                                      id: company_ids[0],
                                      view_all_tickets: nil
                                    },
                                    other_companies: [
                                      {
                                        id: company_ids[1],
                                        view_all_tickets: nil
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
      company_ids = [create_company, create_company].map(&:id)
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
      company_ids = [create_company, create_company].map(&:id)
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

    def test_update_contact_by_removing_secondary_companies
      company_ids = [create_company, create_company].map(&:id)
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

    def test_update_contact_by_removing_primary_company
      company_ids = [create_company, create_company].map(&:id)
      sample_user = create_contact_with_other_companies(@account, company_ids)

      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: nil,
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
      assert sample_user.user_companies.find_by_default(false).nil?
      assert sample_user.user_companies.find_by_company_id(company_ids[0]).nil?
    end

    def test_update_contact_by_removing_primary_company_without_multiple_companies_feature
      company_id = create_company.id
      @account.revoke_feature(:multiple_user_companies)
      sample_user = add_new_user(@account, customer_id: company_id)

      put :update, construct_params({ version: 'private', id: sample_user.id },
                                    company: nil)
      assert_response 200
      pattern = private_api_contact_pattern(sample_user.reload)
      match_json(pattern)
      assert sample_user.user_companies.find_by_company_id(company_id).nil?
      @account.add_feature(:multiple_user_companies)
      @account.reload
    end

    # Skip mandatory custom field validation on update
    def test_update_contact_without_required_custom_fields_with_enforce_mandatory_as_false
      cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
      @account.reload
      created_contact = post :quick_create, construct_params(
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(15)
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
      created_contact = post :quick_create, construct_params(
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(15)
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
      created_contact = post :quick_create, construct_params(
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(15)
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
      created_contact = post :quick_create, construct_params(
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(15)
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
      created_contact = post :quick_create, construct_params(
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(15)
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        custom_fields: { code: 'existing' }
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        custom_fields: { code: 'existing' }
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
      created_contact = post :quick_create, construct_params(
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(15)
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
      created_contact = post :quick_create, construct_params(
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        company_name: Faker::Lorem.characters(15)
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        custom_fields: { code: 'existing' }
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        custom_fields: { code: 'existing' }
      )
      created_contact_id = JSON.parse(created_contact.body)['id']
      updated_contact = put :update, construct_params(
        { version: 'private', id: created_contact_id },
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
        { version: 'private' },
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
        { version: 'private' },
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
        { version: 'private' },
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
        { version: 'private' },
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
        { version: 'private' },
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
        { version: 'private' },
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

    def test_quick_create_contact_with_company_name
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          company_name: Faker::Lorem.characters(10))
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
    end

    def test_create_contact_with_enforce_mandatory_as_garbage_value
      cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'code', editable_in_signup: 'true', required_for_agent: 'true'))
      @account.reload
      created_contact = post :create, construct_params(
        { version: 'private' },
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
        { version: 'private' },
        name: Faker::Lorem.characters(15),
        email: Faker::Internet.email,
        query_params: { enforce_mandatory: 'false' }
      )

      result = JSON.parse(created_contact.body)
      assert_response 201, result
    ensure
      cf.delete
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
        cf.delete
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
      post :quick_create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10))
      match_json([bad_request_error_pattern('email', :missing_contact_detail)])
      assert_response 400
    end

    def test_quick_create_contact_invalid_email
      Account.stubs(:current).returns(Account.first || create_test_account)
      Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
      post :quick_create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                                   email: 'test.@test.com')
      match_json([bad_request_error_pattern('email', :invalid_format, accepted: 'valid email address')])
      assert_response 400
    ensure
      Account.any_instance.unstub(:new_email_regex_enabled?)
      Account.unstub(:current)
    end

    def test_quick_create_without_company
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(10),
                                          email: Faker::Internet.email)
      assert_response 201
    end

    def test_quick_create_with_default_language
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(10),
                                          email: Faker::Internet.email)
      assert_response 201
      assert_equal User.last.language, @account.language
    end

    def test_quick_create_with_address
      create_test_account unless Account.first.present?
      Account.stubs(:current).returns(Account.first)
      params = { name: Faker::Lorem.characters(10), email: Faker::Internet.email, address: Faker::Address.street_address }
      post :quick_create, construct_params({ version: 'private' }, params)
      assert_response 201
      created_contact = User.where(email: params[:email]).first
      assert_equal true, created_contact.address.present?
      assert_equal true, created_contact.address.eql?(params[:address])
    ensure
      created_contact.destroy
      Account.unstub(:current)
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
      file = fixture_file_upload('files/image33kb.jpg', 'image/jpeg')
      sample_user = add_new_user(@account)
      sample_user.build_avatar(content_content_type: file.content_type, content_file_name: file.original_filename)
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(private_api_contact_pattern(sample_user.reload))
      assert_response 200
    end

    def test_show_a_contact_with_other_companies
      company_ids = [create_company, create_company].map(&:id)
      sample_user = create_contact_with_other_companies(@account, company_ids)
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(private_api_contact_pattern(sample_user.reload))
      assert_response 200
    end

    def test_show_a_contact_with_include_company
      company_ids = [create_company, create_company].map(&:id)
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

    def test_show_a_contact_with_custom_field_date
      contact_field = create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'Requester Date', name: 'cf_requester_date', required_for_agent: true, editable_in_signup: true, field_options: { 'widget_position' => 12 }))
      time_now = Time.zone.now
      @account.reload
      sample_user = add_new_user(@account, { custom_fields: { cf_requester_date: time_now}})
      get :show, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      res = JSON.parse(response.body)
      ticket_date_format = Time.now.in_time_zone(@account.time_zone).strftime('%F')
      contact_field.destroy
      assert_equal ticket_date_format, res['custom_fields']['requester_date']
    end

    def test_show_a_contact_with_encrypted_text_field
      contact_field = create_contact_field(cf_params(type: 'encrypted_text', field_type: 'encrypted_text', label: 'Sensitive info', name: 'cf_enc_sensitive_info'))
      @account.reload
      encryption_key_text = SecureRandom.base64(50)
      Account.any_instance.stubs(:hipaa_encryption_key).returns(encryption_key_text)
      Account.any_instance.stubs(:hipaa_and_encrypted_fields_enabled?).returns(true)
      sensitive_data = 'A positive'
      sample_user = add_new_user(@account, { custom_fields: { cf_enc_sensitive_info: sensitive_data } })
      get :show, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      res = JSON.parse(response.body)
      contact_field.destroy
      assert_equal sensitive_data, res['custom_fields']['enc_sensitive_info']
    end

    def test_show_a_contact_without_csat_rating
      sample_user = create_contact_with_csat_rating(@account, nil)
      get :show, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      res = JSON.parse(response.body)
      assert_nil res['csat_rating']
    end

    def test_show_a_contact_with_csat_rating
      sample_user = create_contact_with_csat_rating(@account, 103)
      get :show, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      res = JSON.parse(response.body)
      assert_equal 103, res['csat_rating']
    end

    def test_show_a_non_existing_contact
      get :show, controller_params(version: 'private', id: 0)
      assert_response :missing
    end

    def test_show_a_contact_with_preferred_source
      sample_user = add_new_user(@account)
      sample_user.merge_preferences = { preferred_source: 2 }
      sample_user.save_without_session_maintenance
      get :show, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      res = JSON.parse(response.body)
      assert_equal Helpdesk::Source.default_ticket_source_token_by_key[2].to_s, res['preferred_source']
    end

    def test_show_a_contact_without_preferred_source
      sample_user = add_new_user(@account)
      get :show, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      res = JSON.parse(response.body)
      assert_nil res['preferred_source']
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

    def test_deletion_of_hard_deleted_contact
      contact_id = add_marked_for_hard_delete_user(@account)
      delete :destroy, controller_params(version: 'private', id: contact_id)
      assert_response 404
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

    def marked_for_delete_restore
      contact = add_marked_for_hard_delete_user(@account)
      put :restore, controller_params(version: 'private', id: contact.id)
      assert_response 404
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

    def test_index_with_tags
      tags = Faker::Lorem.words(3).uniq
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account, tag_names: tags.join(','), tags: tags.join(','))
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

    def test_index_with_stop_count_disabled
      count = Account.current.all_contacts.where("users.deleted = 0 AND users.blocked = 0").count
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      get :index, controller_params(version: 'private')
      assert_response 200
      assert response.api_meta[:count] == count + BULK_CONTACT_CREATE_COUNT
      assert_not_nil response.api_meta[:next_page]
    end

    def test_index_with_stop_count_enabled
      Account.current.enable_setting(:stop_contacts_count_query)
      contact_ids = create_n_users(BULK_CONTACT_CREATE_COUNT, @account)
      get :index, controller_params(version: 'private')
      assert_response 200
      assert response.api_meta[:count].nil?
      assert_not_nil response.api_meta[:next_page]
      ensure
        Account.current.disable_setting(:stop_contacts_count_query)
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

    def bulk_restore_of_marked_for_hard_deleted_contacts
      contact_ids = create_n_marked_for_hard_delete_users(BULK_CONTACT_CREATE_COUNT, @account, deleted: true)
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
      Account.any_instance.stubs(:assume_identity_enabled?).returns(false)
      put :assume_identity, construct_params({ version: 'private', id: assume_contact.id }, nil)
      Account.any_instance.unstub(:assume_identity_enabled?)
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
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
      avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
      contact = add_new_user(@account, avatar: avatar)
      put :update, construct_params({ version: 'private', id: contact.id }, avatar_id: nil)
      assert_response 200
      contact.reload
      match_json(private_api_contact_pattern(contact))
      assert contact.avatar.nil?
    end

    def test_update_change_avatar
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
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
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
      avatar = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id)
      contact = add_new_user(@account)
      put :update, construct_params({ version: 'private', id: contact.id }, avatar_id: avatar.id)
      assert_response 200
      contact.reload
      match_json(private_api_contact_pattern(contact))
      assert contact.avatar.id == avatar.id
    end

    def test_update_avatar_and_contact_update_failure
      file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
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

    def test_contact_activities_without_view_contacts_privilege
      contact = add_new_user(@account, deleted: false, active: true)
      user_tickets = sample_user_tickets(contact)
      User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
      get :activities, construct_params({ version: 'private', id: contact.id, type: 'tickets' }, nil)
      User.any_instance.unstub(:privilege?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    # tests for persisting updated_at when its not a contact profile update

    def test_updated_at_for_profile_update
      updated_at = Time.now.utc - 2.days
      contact = add_new_user(@account, updated_at: updated_at)
      put :update, construct_params({ version: 'private', id: contact.id }, name: Time.now.to_s)
      assert_response 200
      assert contact.reload.updated_at != updated_at
    end

    def test_updated_at_when_tags_are_modified
      updated_at = Time.now.utc - 2.days
      tags = Faker::Lorem.words(3).uniq
      contact = add_new_user(@account, {updated_at: updated_at, 
                                        tag_names: tags.join(',')})
      put :update, construct_params({ version: 'private', id: contact.id }, 
                                      tags: [random_password])
      assert_response 200
      assert contact.reload.updated_at != updated_at
    end

    def test_updated_at_for_password_update
      contact = Account.current.contacts.first
      updated_at = contact.updated_at
      put :update_password, construct_params({ version: 'private', id: contact.id }, 
                                              password: Time.now.to_s)
      assert_response 204
      assert_not_equal contact.reload.updated_at.to_time.to_i, updated_at.to_i
    end

    # Show User jwt auth
    def test_show_a_contact_with_valid_jwt_token
      sample_user = add_new_user(@account)
      user = User.current
      UserSession.any_instance.unstub(:cookie_credentials)
      log_out
      token = get_mobile_jwt_token_of_user(@agent)
      bearer_token = "Bearer #{token}"
      current_header = request.env["HTTP_AUTHORIZATION"]
      request.env["HTTP_USER_AGENT"] = "Freshdesk_Native"
      set_custom_jwt_header(bearer_token)
      get :show, controller_params(version: 'private', id: sample_user.id)
      match_json(private_api_contact_pattern(sample_user.reload))
      assert_response 200
      request.env["HTTP_AUTHORIZATION"] = current_header
      UserSession.any_instance.stubs(:cookie_credentials).returns([user.persistence_token, user.id])
      login_as(user)
      user.make_current
    end

    def test_show_a_contact_with_invalid_jwt_token
      sample_user = add_new_user(@account)
      user = User.current
      UserSession.any_instance.unstub(:cookie_credentials)
      log_out
      bearer_token = "Bearer AAAAAAA"
      current_header = request.env["HTTP_AUTHORIZATION"]
      request.env["HTTP_USER_AGENT"] = "Freshdesk_Native"
      set_custom_jwt_header(bearer_token)
      get :show, controller_params(version: 'private', id: sample_user.id)
      assert_response 401
      request.env["HTTP_AUTHORIZATION"] = current_header
      UserSession.any_instance.stubs(:cookie_credentials).returns([user.persistence_token, user.id])
      login_as(user)
      user.make_current
    end

    #Test post action with jwt token
    def test_quick_create_contact_with_company_name_valid_jwt
      user = User.current
      UserSession.any_instance.unstub(:cookie_credentials)
      log_out
      token = get_mobile_jwt_token_of_user(@agent)
      bearer_token = "Bearer #{token}"
      current_header = request.env["HTTP_AUTHORIZATION"]
      request.env["HTTP_USER_AGENT"] = "Freshdesk_Native"
      set_custom_jwt_header(bearer_token)
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          company_name: Faker::Lorem.characters(10))
      assert_response 201
      match_json(private_api_contact_pattern(User.last))
      request.env["HTTP_AUTHORIZATION"] = current_header
      UserSession.any_instance.stubs(:cookie_credentials).returns([user.persistence_token, user.id])
      login_as(user)
      user.make_current
    end


    def test_quick_create_contact_with_company_name_invalid_jwt
      user = User.current
      UserSession.any_instance.unstub(:cookie_credentials)
      log_out
      bearer_token = "Bearer AAAAAAA"
      current_header = request.env["HTTP_AUTHORIZATION"]
      request.env["HTTP_USER_AGENT"] = "Freshdesk_Native"
      set_custom_jwt_header(bearer_token)
      post :quick_create, construct_params({version: 'private'},  name: Faker::Lorem.characters(15),
                                          email: Faker::Internet.email,
                                          company_name: Faker::Lorem.characters(10))
      assert_response 401
      request.env["HTTP_AUTHORIZATION"] = current_header
      UserSession.any_instance.stubs(:cookie_credentials).returns([user.persistence_token, user.id])
      login_as(user)
      user.make_current
    end

    # Contact timeline testcases

    def test_contact_timeline_without_view_contacts_privilege
      sample_user = add_new_user(@account)
      User.any_instance.stubs(:privilege?).with(:view_contacts).returns(false)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      User.any_instance.unstub(:privilege?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_contact_timeline_with_hypertrail_fail
      sample_user = add_new_user(@account)
      result_data = create_timeline_sample_data(sample_user, 0)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}"
      stub_request(:get, url).to_return(body: result_data[1].to_json, status: 503)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      assert_response 503
    end

    def test_contact_timeline_with_no_activities
      sample_user = add_new_user(@account)
      result_data = create_timeline_sample_data(sample_user, 0)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}"
      stub_request(:get, url).to_return(body: result_data[1].to_json, status: 200)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      match_json([])
    end

    def test_contact_timeline
      sample_user = add_new_user(@account)
      result_data = create_timeline_sample_data(sample_user)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}"
      stub_request(:get, url).to_return(body: result_data[1].to_json, status: 200)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      match_json(timeline_activity_response(sample_user, result_data[0]))
    end

    def test_contact_timeline_with_next_page
      sample_user = add_new_user(@account)
      result_data = create_timeline_sample_data(sample_user, 5, true)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}"
      stub_request(:get, url).to_return(body: result_data[1].to_json, status: 200)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      match_json(timeline_activity_response(sample_user, result_data[0]))
      assert_equal response.api_meta[:next_page], 'start_token=1651334132522601834'
    end

    def test_contact_timeline_with_next_page_attribute
      sample_user = add_new_user(@account)
      result_data = create_timeline_sample_data(sample_user)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}?start_token=1651334132522601834"
      stub_request(:get, url).to_return(body: result_data[1].to_json, status: 200)
      get :timeline, controller_params(version: 'private', id: sample_user.id, after: 'start_token=1651334132522601834')
      assert_response 200
      match_json(timeline_activity_response(sample_user, result_data[0]))
    end

    def test_contact_timeline_with_custom_events
      sample_user = add_new_user(@account)
      result_data = create_custom_timeline_sample_data(sample_user)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}"
      stub_request(:get, url).to_return(body: result_data.to_json, status: 200)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      match_json(custom_timeline_activity_response(result_data))
    end

    def test_contact_timeline_custom_events_without_context
      sample_user = add_new_user(@account)
      result_data = create_custom_timeline_sample_data(sample_user, false)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}"
      stub_request(:get, url).to_return(body: result_data.to_json, status: 200)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      match_json(custom_timeline_activity_response(result_data))
    end

    def test_contact_timeline_returns_csat_activities
      sample_user = add_new_user(@account)
      create_survey(1, true)
      survey = @account.custom_surveys.last
      result_data = create_timeline_sample_data(sample_user, 1, false, survey)
      url = "#{BASE_URL_CONTACT_TIMELINE}/#{@account.id}/contacttimeline/#{sample_user.id}"
      stub_request(:get, url).to_return(body: result_data[1].to_json, status: 200)
      get :timeline, controller_params(version: 'private', id: sample_user.id)
      assert_response 200
      match_json(timeline_activity_response(sample_user, result_data[0]))
    ensure
      survey.destroy
    end

    def test_create_contact_with_facebook_id
      facebook_id = Faker::Lorem.characters(15)
      post :create, construct_params({}, name: Faker::Lorem.characters(15), facebook_id: facebook_id)
      assert_response 201
      assert_equal parse_response(@response.body)['facebook_id'], facebook_id
    end

    def test_length_exceeded_validation_error_with_facebook_id
      facebook_id = Faker::Lorem.characters(300)
      post :create, construct_params({}, name: Faker::Lorem.characters(15), facebook_id: facebook_id)
      match_json([bad_request_error_pattern('facebook_id', :too_long, element_type: :characters, max_count: "#{ApiConstants::MAX_LENGTH_STRING}", current_count: 300)])
      assert_response 400
    end

    def test_mandatory_unique_identifier_field
      Account.any_instance.stubs(:unique_contact_identifier_enabled?).returns(false)
      post :create, construct_params({}, name: Faker::Lorem.characters(15))
      assert_response 400
      match_json(
        [{
          field: 'email',
          code: :missing_field,
          message: 'Please fill at least 1 of email, mobile, phone, twitter_id, facebook_id fields'
        }]
      )
    ensure
      Account.any_instance.unstub(:unique_contact_identifier_enabled?)
    end

    def test_mandatory_unique_identifier_field_with_unique_contact_identifier_enabled
      Account.any_instance.stubs(:unique_contact_identifier_enabled?).returns(true)
      post :create, construct_params({}, name: Faker::Lorem.characters(15))
      assert_response 400
      match_json(
        [{
          field: 'email',
          code: :missing_field,
          message: 'Please fill at least 1 of email, mobile, phone, twitter_id, unique_external_id, facebook_id fields'
        }]
      )
    ensure
      Account.any_instance.unstub(:unique_contact_identifier_enabled?)
    end

    def test_populate_twitter_requester_handle_id_while_create_contact_with_twitter_id
      Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
      twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
      Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
      create_twitter_handle
      user_email = Faker::Internet.email
      post :create, construct_params({ version: 'private' }, name: Faker::Lorem.characters(10),
                                                             email: user_email,
                                                             twitter_id: Faker::Lorem.word)
      assert_response 201
      created_user = User.find_by_email(user_email)
      assert_equal twitter_requester_handle_id, created_user.twitter_requester_handle_id
      match_json(private_api_contact_pattern(created_user))
    ensure
      Twitter::REST::Client.any_instance.unstub(:user)
      Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    end

    def test_populate_twitter_requester_handle_id_while_contact_update_with_twitter_id_value_set
      Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
      twitter_requester_handle_id = Faker::Number.between(1, 999_999_999).to_s
      Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(twitter_requester_handle_id))
      create_twitter_handle
      sample_user = add_new_user(@account)
      assert_nil sample_user.twitter_requester_handle_id

      params_hash = { twitter_id: Faker::Lorem.word }
      put :update, construct_params({ version: 'private', id: sample_user.id }, params_hash)
      assert_response 200
      assert_equal twitter_requester_handle_id, sample_user.reload.twitter_requester_handle_id
      match_json(private_api_contact_pattern(sample_user))
    ensure
      Twitter::REST::Client.any_instance.unstub(:user)
      Account.any_instance.unstub(:twitter_api_compliance_enabled?)
    end
  end
end
