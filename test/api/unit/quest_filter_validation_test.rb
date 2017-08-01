require_relative '../unit_test_helper'
class QuestFilterValidationTest < ActionView::TestCase
  def test_value_valid
    quest = QuestFilterValidation.new({ filter: 'unachieved' }, nil)
    assert_equal quest.valid?, true
  end

  def test_value_invalid
    quest = QuestFilterValidation.new({ filter: nil }, nil)
    assert_equal quest.valid?, false
  end
end
