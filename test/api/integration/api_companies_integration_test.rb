require_relative '../test_helper'

class ApiCompaniesIntegrationTest < ActionDispatch::IntegrationTest
  include Helpers::CompaniesTestHelper
  def test_query_count
    skip_bullet do
      v2 = {}
      v1 = {}
      v2_expected = {
        api_create: 7,
        api_show: 1,
        api_index: 2,
        api_update: 8,
        api_destroy: 8,

        create: 20,
        show: 16,
        index: 16,
        update: 21,
        destroy: 20
      }

      # create
      v1[:create] = count_queries do
        post('/companies.json', company_payload, @write_headers)
        assert_response 201
      end
      v2[:create], v2[:api_create], v2[:create_queries] = count_api_queries do
        post('/api/v2/companies', v2_company_payload, @write_headers)
        assert_response 201
      end

      id1 = Company.order('id desc').first.id
      id2 = Company.order('id desc').offset(1).first.id
      # show
      v1[:show] = count_queries do
        get("/companies/#{id2}.json", nil, @headers)
        assert_response 200
      end
      v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
        get("/api/v2/companies/#{id1}", nil, @headers)
        assert_response 200
      end
      v1[:show] += 1 # trusted_ip

      # V2 index
      v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
        get('/api/v2/companies.json', nil, @headers)
        assert_response 200
      end

      # update
      v1[:update] = count_queries do
        put("/companies/#{id2}.json", company_payload, @write_headers)
        assert_response 200
      end
      v2[:update], v2[:api_update], v2[:update_queries] = count_api_queries do
        put("/api/v2/companies/#{id1}", v2_company_payload, @write_headers)
        assert_response 200
      end

      # destroy
      v1[:destroy] = count_queries do
        delete("/companies/#{id2}.json", nil, @headers)
        assert_response 200
      end
      v2[:destroy], v2[:api_destroy], v2[:destroy_queries] = count_api_queries do
        delete("/api/v2/companies/#{id1}", nil, @headers)
        assert_response 204
      end

      v1[:create] += 2 # 2 extra queries caused due to companies_validation_helper which is needed to get the list of custom_fields for restricting invalid custom_fields on create or update
      v1[:update] += 1 # Extra query due to the same companies_validation_helper

      write_to_file(v1, v2)

      v1.keys.each do |key|
        api_key = "api_#{key}".to_sym
        assert v2[key] <= v1[key]
        assert_equal v2_expected[api_key], v2[api_key]
        assert_equal v2_expected[key], v2[key]
      end
    end
  end
end
