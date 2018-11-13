require_relative '../test_helper'

class ProductTest < ActiveSupport::TestCase
	include ProductTestHelper

  def test_central_publish_payload
    product = create_product(@account)
    payload = product.central_publish_payload.to_json
    msg = JSON.parse(payload)
    product_push_timestamp = msg["product_push_timestamp"]
    payload.must_match_json_expression(central_publish_product_pattern(product, product_push_timestamp))
    assoc_payload = product.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_publish_product_association_pattern(product))
  end
end
