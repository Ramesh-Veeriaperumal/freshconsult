require_relative '../unit_test_helper'
class InstalledApplicationValidationTest < ActionView::TestCase
  def test_value_valid
    installed_app = InstalledApplicationValidation.new({ name: 'harvest' }, nil)
    assert installed_app.valid?
  end

  def test_value_invalid
    installed_app = InstalledApplicationValidation.new({ name: nil }, nil)
    assert installed_app.valid?
  end
end
