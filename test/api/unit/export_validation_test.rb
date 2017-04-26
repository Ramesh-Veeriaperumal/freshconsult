require_relative '../unit_test_helper'
require_relative '../helpers/export_test_helper'

class ExportValidationTest < ActionView::TestCase
  include ExportTestHelper

  def test_valid
    VALID_DATE_FORMATS.each do |date|
      new_export = ExportValidation.new({:action => "ticket_activities", :created_at => date})
      assert_equal new_export.valid?, true
    end
  end

  def test_nil
    new_export = ExportValidation.new({:action => "ticket_activities", :created_at => nil})
    assert_equal new_export.valid?, true
  end

  def test_incorrect_format
    INVALID_DATE_FORMATS.each do |date|
      new_export = ExportValidation.new({:action => "ticket_activities", :created_at => date})
      assert_equal new_export.valid?, false
    end
  end
end
