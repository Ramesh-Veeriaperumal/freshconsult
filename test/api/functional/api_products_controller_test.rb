require_relative '../test_helper'
class ApiProductsControllerTest < ActionController::TestCase
  include Helpers::ProductsTestHelper
  def wrap_cname(params)
    { api_product: params }
  end

  def test_index
    get :index, request_params
    pattern = []
    Account.current.products_from_cache.each do |product|
      pattern << product_pattern(product)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_product
    product = create_product
    get :show, construct_params(id: product.id)
    assert_response 200
    match_json(product_pattern(Product.find(product.id)))
  end

  def test_handle_show_request_for_missing_product
    get :show, construct_params(id: 2000)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_show_product_with_feature_disabled
    product = create_product
    @account.class.any_instance.stubs(:features_included?).returns(false)
    get :show, construct_params(id: product.id)
    @account.class.any_instance.unstub(:features_included?)
    assert_response 403
  end

  def test_handle_show_request_for_invalid_product_id
    get :show, construct_params(id: Faker::Name.name)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_index_without_privilege
    product = create_product
    User.any_instance.stubs(:privilege?).returns(false).once
    get :show, construct_params(id: product.id)
    assert_response 403
    match_json(request_error_pattern('access_denied'))
  end

  def test_index_with_link_header
    3.times do
      create_product
    end
    per_page =  Account.current.products_from_cache.count - 1
    get :index, construct_params(per_page: per_page)
    assert_response 200
    assert JSON.parse(response.body).count == per_page
    assert_equal "<http://#{@request.host}/api/v2/products?per_page=#{per_page}&page=2>; rel=\"next\"", response.headers['Link']

    get :index, construct_params(per_page: per_page, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count == 1
    assert_nil response.headers['Link']
  end
end
