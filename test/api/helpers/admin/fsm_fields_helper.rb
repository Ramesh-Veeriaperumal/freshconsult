module Admin::FsmFieldsHelper
  def add_fsm_feature
    @account.add_feature :field_service_management
    section = setup_fsm_fields
    yield
  ensure
    @account.revoke_feature :field_service_management
  end

  def fsm_field_update_params(id)
    {
      "section_mappings": [
        {
          "section_id": id,
          "position": 1
        }
      ]
    }
  end

  def fsm_field_invalid_update_params
    {
      "label": 'invalid'
    }
  end

  def fsm_field_invalid_update_section_params
    {
      "section_mappings": [
        {
          "section_id": 20,
          "position": 5
        }
      ]
    }
  end

  def fsm_validation_message
    {
      "description": 'Validation failed',
      "errors": [
        {
          "field": 'label',
          "message": 'Field service management fields cannot be created/updated',
          "code": 'incompatible_field'
        }
      ]
    }
  end

  def fsm_section_validation_message
    {
      "description": 'Validation failed',
      "errors": [
        {
          "field": 'update_fsm',
          "message": 'Field Service management fields cannot be moved to another sections',
          "code": 'invalid_value'
        }
      ]
    }
  end

  def fsm_delete_validation_message
    {
      "description": 'Validation failed',
      "errors": [
        {
          "field": 'field_service_management',
          "message": 'Field service management feature should be disabled, for delete',
          "code": 'invalid_value'
        }
      ]
    }
  end
end
