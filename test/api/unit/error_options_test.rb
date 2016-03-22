require_relative '../unit_test_helper'

class ErrorOption
  include ErrorOptions
end

class ErrorOptionsTest < ActionView::TestCase
  def test_infer_data_type
    assert_equal 'key/value pair', ErrorOption.new.infer_data_type(ActionController::Parameters.new)
    assert_equal Array, ErrorOption.new.infer_data_type([])
    assert_equal String, ErrorOption.new.infer_data_type(ActiveSupport::JSON::Variable.new)
    assert_equal Float, ErrorOption.new.infer_data_type(2.3)
    assert_equal 'Boolean', ErrorOption.new.infer_data_type(true)
    assert_equal 'valid file format', ErrorOption.new.infer_data_type(ActionDispatch::Http::UploadedFile.new(tempfile: 1))
    assert_equal Integer, ErrorOption.new.infer_data_type(2)
    assert_equal 'Null', ErrorOption.new.infer_data_type(nil)
    assert_equal 'Unidentified Type', ErrorOption.new.infer_data_type(BigDecimal.new(2, 2))
  end
end
