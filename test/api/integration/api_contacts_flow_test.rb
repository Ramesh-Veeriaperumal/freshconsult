require_relative '../test_helper'

class ApiContactsFlowTest < ActionDispatch::IntegrationTest
  include ContactFieldsHelper
  include Helpers::UsersHelper

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
      match_json([bad_request_error_pattern('company_id', 'company_id_required')])

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
end
