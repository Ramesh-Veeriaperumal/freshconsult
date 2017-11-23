require_relative '../unit_test_helper'

class CollabValidationTest < ActionView::TestCase
  def test_required_fields_validation
    collab_validation = CollabValidation.new({})
    refute collab_validation.valid?
    errors = collab_validation.errors.full_messages
    assert errors.include?('Body datatype_mismatch')
    assert errors.include?('Metadata datatype_mismatch')
    assert errors.include?('Mid datatype_mismatch')
    assert errors.include?('Token datatype_mismatch')
  end

  def test_field_value_validation
    collab_validation = CollabValidation.new(body: '', m_ts: '', m_type: '', metadata: '', mid: '', token: '', top_members: '')
    refute collab_validation.valid?
    errors = collab_validation.errors.full_messages
    assert errors.include?('Body blank')
    assert errors.include?('Metadata blank')
    assert errors.include?('Mid blank')
    assert errors.include?('Token blank')
  end

  def test_metadata_format
    collab_validation = CollabValidation.new(body: 'data', m_ts: 'data', m_type: 'data', metadata: 'data', mid: 'data', token: 'data', top_members: 'data')
    refute collab_validation.valid?
    errors = collab_validation.errors.full_messages
    assert errors.include?('Metadata It should be in valid json format.')
  end
end
