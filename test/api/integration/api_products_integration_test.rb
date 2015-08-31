require_relative '../test_helper'

class ApiProductsIntegrationTest < ActionDispatch::IntegrationTest
  def test_query_count
    v2 = {}
    v2_expected = {
      api_show: 1,
      api_index: 1,

      show: 12,
      index: 12
    }

    product = create_product
    id = product.id
    # show
    v2[:show], v2[:api_show] = count_api_queries { get("/api/v2/products/#{id}", nil, @headers) }

    # index
    v2[:index], v2[:api_index] = count_api_queries { get('/api/v2/products', nil, @headers) }
    
    p v2
    
    v2.keys.each do |key|
      api_key = "api_#{key}".to_sym
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
