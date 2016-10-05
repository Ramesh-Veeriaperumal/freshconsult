require_relative '../../test_helper'
class ApiValidationTest < ActionView::TestCase

  BULK_ACTIONS = [:bulk_spam, :bulk_unspam, :bulk_delete, :bulk_restore, :bulk_send_invite]

  def test_bulk_action_with_no_params
    controller_params = { version: 'private' }
    api_validation = ApiValidation.new(controller_params)
    refute api_validation.valid?(BULK_ACTIONS.sample)
    assert api_validation.errors.full_messages.include?('Ids missing_field')

    controller_params = { version: 'private', ids: [] }
    api_validation = ApiValidation.new(controller_params)
    refute api_validation.valid?(BULK_ACTIONS.sample)
    assert api_validation.errors.full_messages.include?('Ids blank')
  end

  def test_bulk_action_with_incorrect_params
    controller_params = { version: 'private', ids: "Text" }
    api_validation = ApiValidation.new(controller_params)
    refute api_validation.valid?(BULK_ACTIONS.sample)
    assert api_validation.errors.full_messages.include?('Ids datatype_mismatch')
    assert_equal({ ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String } }, api_validation.error_options)

    controller_params = { version: 'private', ids: ["Text"] }
    api_validation = ApiValidation.new(controller_params)
    refute api_validation.valid?(BULK_ACTIONS.sample)
    assert api_validation.errors.full_messages.include?('Ids array_datatype_mismatch')
    assert_equal({ ids: { expected_data_type: :'Positive Integer' } }, api_validation.error_options)
  end

  def test_bulk_action_with_valid_params
    controller_params = { version: 'private', ids: [1, 2, 3] }
    api_validation = ApiValidation.new(controller_params)
    assert api_validation.valid?(BULK_ACTIONS.sample)
  end
end
