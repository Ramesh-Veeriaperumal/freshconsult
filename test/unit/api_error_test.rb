require_relative '../test_helper'

class ApiErrorTest < ActionView::TestCase
  def test_base_error
    base_error = BaseError.new(ApiConstants::API_ERROR_CODES.first[1][0])
    assert_equal I18n.t("api.error_messages.#{ApiConstants::API_ERROR_CODES.first[1][0]}"), base_error.message
  end

  def test_bad_request
    base_error = BadRequestError.new("name", ApiConstants::API_ERROR_CODES.first[1][0])
    code = ApiConstants::API_ERROR_CODES.first[0]
    assert_equal code, base_error.code
    assert_equal I18n.t("api.error_messages.#{ApiConstants::API_ERROR_CODES.first[1][0]}"), base_error.message
    assert_equal ApiConstants::API_HTTP_ERROR_STATUS_BY_CODE[code], base_error.http_code
    assert_equal "name", base_error.field
  end

  def test_request_error_without_params
    base_error = RequestError.new("access_denied")
    assert_equal I18n.t("api.error_messages.access_denied"), base_error.message
    assert_equal "access_denied", base_error.code
  end

  def test_request_error_with_params
    base_error = RequestError.new("require_feature", {:feature => "Forums"}) 
    assert_equal I18n.t("api.error_messages.require_feature", {:feature => "Forums"}), base_error.message
    assert_equal "require_feature", base_error.code
  end
end