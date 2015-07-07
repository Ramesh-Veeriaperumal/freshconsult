require_relative '../test_helper'
class ApiProductsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_product: params }
  end

  def test_index_products
    get :index, request_params
    assert_equal Product.all, assigns(:items)
    assert_equal Product.all, assigns(:api_products)
  end

  def test_show_product
    product = create_product
    get :show, construct_params(id: product.id)
    assert_response :success
    match_json(product_pattern(Product.find(product.id)))
  end

  def test_handle_show_request_for_missing_product
    get :show, construct_params(id: 2000)
    assert_response :missing
    assert_equal ' ', response.body
  end

  def test_handle_show_request_for_invalid_product_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response :missing
    assert_equal ' ', response.body
  end
end
