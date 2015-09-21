require_relative '../test_helper'

class ApiProductsIntegrationTest < ActionDispatch::IntegrationTest
  include ProductsHelper
  def test_query_count
    v2 = {}
    v2_expected = {
      api_show: 1,
      api_index: 1,

      show: 11,
      index: 11
    }

    product = create_product
    id = product.id
    # show
    v2[:show], v2[:api_show], v2[:show_queries] = count_api_queries do
      get("/api/v2/products/#{id}", nil, @headers)
      assert_response 200
    end

    # index
    v2[:index], v2[:api_index], v2[:index_queries] = count_api_queries do
      get('/api/v2/products', nil, @headers)
      assert_response 200
    end

    write_to_file(nil, v2)

    v2_expected.keys.in_groups(2).last.each do |key|
      api_key = "api_#{key}".to_sym
      assert_equal v2_expected[api_key], v2[api_key]
      assert_equal v2_expected[key], v2[key]
    end
  end
end
