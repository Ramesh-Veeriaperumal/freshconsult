require_relative '../unit_test_helper'

class FileSizeValidatorTest < ActionView::TestCase
  class FileValidation
    include ActiveModel::Validations

    attr_accessor :attribute1, :item_size, :attribute2, :error_options, :multi_error
    validates :multi_error, data_type: { rules: String, allow_nil: true }
    validates :attribute1, :multi_error, file_size:  {
      min: 0, max: 100,
      base_size: proc { |x| x.item_size }
    }
    validates :attribute2, file_size:  {
      min: 1, max: 100
    }
  end

  def test_base_size_proc_valid
    test = FileValidation.new
    test.attribute1 = [[1]]
    test.item_size = 10
    assert test.valid?
    assert test.errors.empty?
  end

  def test_attribute_with_error
    test = FileValidation.new
    test.multi_error = [[2]] * 101
    test.item_size = 0
    refute test.valid?
    assert test.errors.count == 1
    assert_equal({ multi_error: :data_type_mismatch }, test.errors.to_h)
  end

  def test_base_size_proc_invalid
    test = FileValidation.new
    test.attribute1 = [[1]]
    test.item_size = 100
    refute test.valid?
    assert_equal(test.errors.to_h, attribute1: :invalid_size)
  end

  def test_base_size_absent
    test = FileValidation.new
    test.attribute2 = [1] * 101
    refute test.valid?
    assert_equal(test.errors.to_h, attribute2: :invalid_size)
  end

  def test_min_size_invalid
    test = FileValidation.new
    test.attribute2 = []
    refute test.valid?
    assert_equal(test.errors.to_h, attribute2: :invalid_size)
  end

  def test_single_attachment_valid
    test = FileValidation.new
    test.attribute2 = 'aaa'
    assert test.valid?
    assert test.errors.empty?
  end

  def test_single_attachment_invalid
    test = FileValidation.new
    test.attribute2 = 'aaaaaaaaaa' * 11
    refute test.valid?
    assert_equal(test.errors.to_h, attribute2: :invalid_size)
  end
end
