require_relative '../test_helper'

class ApiCompaniesFlowTest < ActionDispatch::IntegrationTest
  include Helpers::CompaniesTestHelper
  include CompanyHelper
  include ContactFieldsHelper

  JSON_ROUTES = Rails.application.routes.routes.select do |r|
    r.path.spec.to_s.starts_with('/api/companies/') &&
    ['post', 'put'].include?(r.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase)
  end.collect do |x|
    [
      x.path.spec.to_s.gsub('(.:format)', ''),
      x.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase
    ]
  end.to_h

  JSON_ROUTES.each do |path, verb|
    define_method("test_#{path}_#{verb}_with_multipart") do
      headers, params = encode_multipart(api_company_params)
      skip_bullet do
        send(verb.to_sym, path, params, @write_headers.merge(headers))
      end
      assert_response 415
      response.body.must_match_json_expression(un_supported_media_type_error_pattern)
    end
  end

  def test_empty_domains
    skip_bullet do
      params = api_company_params.merge(domains: [Faker::Name.name])
      post '/api/companies', params.to_json, @write_headers
      assert_response 201
      company = Company.find_by_name(params[:name])
      assert company.domains.split(',').count == 1

      put "/api/companies/#{company.id}", { domains: nil }.to_json, @write_headers
      match_json([bad_request_error_pattern('domains', :data_type_mismatch, data_type: 'Array')])
      assert_response 400

      put "/api/companies/#{company.id}", { domains: [] }.to_json, @write_headers
      assert_response 200
      assert company.reload.domains.split(',').count == 0
    end
  end

  def test_caching_after_updating_custom_fields
    create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Linetext1'))
    create_company_field(company_params(type: 'paragraph', field_type: 'custom_paragraph', label: 'Testimony1'))
    company = create_company
    enable_cache do
      Account.stubs(:current).returns(@account)
      get "/api/v2/companies/#{company.id}", nil, @write_headers
      company.update_attributes(custom_field: { 'cf_linetext1' => 'test', 'cf_testimony1' => 'test testimony' })
      custom_field = company.custom_field.map { |k, v| [CustomFieldDecorator.display_name(k), v] }.to_h
      get "/api/v2/companies/#{company.id}", nil, @write_headers
      assert_response 200
      match_json(company_pattern({ custom_field: custom_field }, company))
    end
  ensure
    Account.unstub(:current)
  end
end
