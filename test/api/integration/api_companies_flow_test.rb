require_relative '../test_helper'

class ApiCompaniesFlowTest < ActionDispatch::IntegrationTest
  include Helpers::CompaniesHelper
  JSON_ROUTES = Rails.application.routes.routes.select { |r| 
                        r.path.spec.to_s.starts_with("/api/companies/") && 
                        ['post', 'put'].include?(r.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase)
                      }.collect { |x| 
                          [ 
                            x.path.spec.to_s.gsub("(.:format)", ''),  
                            x.send(:verb).inspect.gsub(/[^0-9A-Za-z]/, '').downcase 
                          ]
                      }.to_h

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

      put "/api/companies/#{company.id}", {domains: nil}.to_json, @write_headers  
      match_json([bad_request_error_pattern('domains', 'data_type_mismatch', data_type: 'Array')])

      put "/api/companies/#{company.id}", {domains: []}.to_json, @write_headers
      assert_response 200
      assert company.reload.domains.split(',').count == 0
    end
  end
end