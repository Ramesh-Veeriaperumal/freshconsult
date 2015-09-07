require_relative '../test_helper'

class ApiCompaniesIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::CompaniesHelper
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      api_create: 8,
      api_show: 1,
      api_index: 2,
      api_update: 8,
      api_destroy: 10,

      create: 22,
      show: 15,
      index: 15,
      update: 22,
      destroy: 20
    }

    # create
    v1[:create] = count_queries { post('/companies.json', company_payload, @write_headers) }
    v2[:create], v2[:api_create] = count_api_queries do
      post('/api/v2/companies', v2_company_payload, @write_headers)
      assert_response :created
    end

    id1 = Company.order('id desc').first.id
    id2 = Company.order('id desc').offset(1).first.id
    # show
    v1[:show] = count_queries { get("/companies/#{id2}.json", nil, @headers) }
    v2[:show], v2[:api_show] = count_api_queries do
      get("/api/v2/companies/#{id1}", nil, @headers)
      assert_response :success
    end

    # V2 index
    v2[:index], v2[:api_index] = count_api_queries do
      get('/api/v2/companies.json', nil, @headers)
      assert_response :success
    end

    # update
    v1[:update] = count_queries { put("/companies/#{id2}.json", company_payload, @write_headers) }
    v2[:update], v2[:api_update] = count_api_queries do
      put("/api/v2/companies/#{id1}", v2_company_payload, @write_headers)
      assert_response :success
    end

    # destroy
    v1[:destroy] = count_queries { delete("/companies/#{id2}.json", nil, @headers) }
    v2[:destroy], v2[:api_destroy] = count_api_queries do
      delete("/api/v2/companies/#{id1}", nil, @headers)
      assert_response :no_content
    end

    v1[:create] += 2 # 2 extra queries caused due to companies_validation_helper which is needed to get the list of custom_fields for restricting invalid custom_fields on create or update
    v1[:update] += 1 # Extra query due to the same companies_validation_helper

    p v1
    p v2

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      assert v2[key] <= v1[key]
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
