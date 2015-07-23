require_relative '../test_helper'

class ApiCompaniesIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v1 = {}
    v2_expected = {
      create: 2,
      show: 1,
      index: 2,
      update: 3,
      destroy: 9
    }

    # create
    v1[:create] = count_queries { post('/companies.json', company_payload, @write_headers) }
    v2[:create], v2[:api_create] = count_api_queries { post('/api/v2/companies', v2_company_payload, @write_headers) }

    id1 = Company.last(2).first.id
    id2 = Company.last.id
    # show
    v1[:show] = count_queries { get("/companies/#{id2}.json", nil, @headers) }
    v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/companies/#{id1}", nil, @headers) }

    # V2 index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/companies.json', nil, @headers) }

    # update
    v1[:update] = count_queries { put("/companies/#{id2}.json", company_payload, @write_headers) }
    v2[:update], v2[:api_update] = count_api_queries { put("/api/v2/companies/#{id1}", v2_company_payload, @write_headers) }

    # destroy
    v1[:destroy] = count_queries { delete("/companies/#{id2}.json", nil, @headers) }
    v2[:destroy], v2[:api_destroy] = count_api_queries { delete("/api/v2/companies/#{id1}", nil, @headers) }

    v1[:create] += 2 # 2 extra queries caused due to companies_validation_helper which is needed to get the list of custom_fields for restricting invalid custom_fields on create or update
    v1[:update] += 1 # Extra query due to the same companies_validation_helper

    v1.keys.each do |key|
      api_key = "api_#{key}".to_sym
      Rails.logger.debug "key : #{api_key}, v1: #{v1[key]}, v2 : #{v2[key]}, v2_api: #{v2[api_key]}, v2_expected: #{v2_expected[key]}"
      assert v2[key] <= v1[key]
      assert_equal v2_expected[key], v2[api_key]
    end
  end
end
