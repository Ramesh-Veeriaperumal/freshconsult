require_relative '../test_helper'

class ApiContactsFlowTest < ActionDispatch::IntegrationTest
  include ContactFieldsHelper
  include Helpers::UsersTestHelper

  def get_user
    @account.all_contacts.where(deleted: false).first
  end

  def get_company
    company = Company.first || create_company
    company
  end

  def stub_current_account(&_block)
    old_value = Account.current
    @account.make_current
    yield
  ensure
    old_value.make_current unless old_value.nil?
  end

  JSON_ROUTES = { '/api/contacts/1/restore' => 'put' }

  JSON_ROUTES.each do |path, verb|
    define_method("test_#{path}_#{verb}_with_multipart") do
      headers, params = encode_multipart(v2_contact_params)
      skip_bullet do
        send(verb.to_sym, path, params, @write_headers.merge(headers))
      end
      assert_response 415
      response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    end
  end

  def test_create_contact_as_in_quick_create_and_update_the_details
    skip_bullet do
      create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'city', editable_in_signup: 'true'))
      tags = [Faker::Name.name, Faker::Name.name, 'tag_sample_test_3']
      cf = { 'cf_city' => 'Chennai' }
      comp = get_company

      params = {  name: Faker::Lorem.characters(15),
                  email: Faker::Internet.email }

      assert_difference 'User.count', 1 do
        post '/api/v2/contacts', params.to_json, @write_headers
        assert_response 201
      end

      sample_user = User.last
      params = {  language: 'cs',
                  time_zone: 'Tokyo',
                  job_title: 'emp',
                  custom_fields: cf,
                  tags: tags }

      put "/api/v2/contacts/#{sample_user.id}", params.to_json, @write_headers
      assert_response 200

      stub_current_account do
        assert sample_user.reload.language == 'cs'
        assert sample_user.reload.time_zone == 'Tokyo'
        assert sample_user.reload.job_title == 'emp'
        assert sample_user.reload.tag_names.split(', ').sort == tags.sort
        assert sample_user.reload.custom_field['cf_city'] == 'Chennai'
      end
      match_json(deleted_contact_pattern(sample_user.reload))
    end
  end

  def test_create_contact_then_convert_to_client_manager
    skip_bullet do
      params = {  name: Faker::Lorem.characters(15),
                  email: Faker::Internet.email }

      assert_difference 'User.count', 1 do
        post '/api/v2/contacts', params.to_json, @write_headers
        assert_response 201
      end

      sample_user = User.last
      params = { client_manager: true }
      put "/api/v2/contacts/#{sample_user.id}", params.to_json, @write_headers
      match_json([bad_request_error_pattern('company_id', :company_id_required)])

      company = get_company
      params = { client_manager: true, company_id: company.id }
      put "/api/v2/contacts/#{sample_user.id}", params.to_json, @write_headers
      assert_response 200

      assert sample_user.reload.client_manager == true
    end
  end

  def test_create_contact_without_email_and_convert_to_agent
    skip_bullet do
      params = {  name: Faker::Lorem.characters(15),
                  twitter_id: Faker::Internet.email }

      assert_difference 'User.count', 1 do
        post '/api/v2/contacts', params.to_json, @write_headers
        assert_response 201
      end

      sample_user = User.last
      put "/api/v2/contacts/#{sample_user.id}/make_agent", nil, @write_headers
      match_json(request_error_pattern('inconsistent_state'))

      params = { email: Faker::Internet.email }
      put "/api/v2/contacts/#{sample_user.id}", params.to_json, @write_headers
      assert_response 200

      put "/api/v2/contacts/#{sample_user.id}/make_agent", nil, @write_headers
      assert_response 200
    end
  end

  def test_multipart_create_with_all_params
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Department', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Sample check box', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'number', field_type: 'custom_number', label: 'sample_number', editable_in_signup: 'true'))
    tags = [Faker::Name.name, Faker::Name.name]
    comp = Company.first || create_company
    params_hash = { name: Faker::Lorem.characters(15), email: Faker::Internet.email, client_manager: true,
                    company_id: comp.id, language: 'en', tags: tags, custom_fields: { 'cf_department' => 'Sample Dept', 'cf_sample_check_box' => true, 'cf_sample_number' => 7878 } }
    headers, params = encode_multipart(params_hash, 'avatar', File.join(Rails.root, 'test/api/fixtures/files/image33kb.jpg'), 'image/jpg', true)
    skip_bullet do
      post '/api/contacts', params, @headers.merge(headers)
    end
    assert_response 201
    stub_current_account do
      match_json(deleted_contact_pattern(params_hash, User.last))
      match_json(deleted_contact_pattern({}, User.last))
    end
  end

  def test_empty_tags
    skip_bullet do
      params = v2_contact_params.merge(tags: [Faker::Name.name])
      post '/api/contacts', params.to_json, @write_headers
      contact = User.find_by_email(params[:email])
      assert_response 201
      assert contact.tag_names.split(',').count == 1

      put "/api/contacts/#{contact.id}", { tags: nil }.to_json, @write_headers
      match_json([bad_request_error_pattern('tags', :data_type_mismatch, data_type: 'Array')])
      assert_response 400

      put "/api/contacts/#{contact.id}", { tags: [] }.to_json, @write_headers
      assert_response 200
      assert contact.reload.tag_names.split(',').count == 0
    end
  end

  def test_caching_after_updating_custom_fields
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Linetext', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'paragraph', field_type: 'custom_paragraph', label: 'Testimony', editable_in_signup: 'true'))
    sample_user = get_user
    turn_on_caching
    Account.stubs(:current).returns(@account)
    get "/api/v2/contacts/#{sample_user.id}", nil, @write_headers
    sample_user.update_attributes(custom_field: { 'cf_linetext' => 'test', 'cf_testimony' => 'test testimony' })
    custom_field = sample_user.custom_field
    get "/api/v2/contacts/#{sample_user.id}", nil, @write_headers
    turn_off_caching
    assert_response 200
    match_json(contact_pattern({ custom_field: custom_field }, sample_user))
  ensure
    Account.unstub(:current)
  end
end
