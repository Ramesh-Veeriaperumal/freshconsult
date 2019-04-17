module AutomationRulesTestHelper
  FIELD_OPERATOR_MAPPING = {
    email:           { operators: ['is', 'is_not', 'contains', 'does_not_contain'], 
                       fields:    ['from_email', 'to_email', 'ticlet_cc']},
    text:            { operators: ['is', 'is_not', 'contains', 'does_not_contain', 
                                   'starts_with', 'ends_with'], 
                       fields:    ['subject', 'description', 'subject_or_description']},
    choicelist:      { operators: ['in', 'not_in'], 
                       fields:    ['priority', 'ticket_type', 'status', 'source', 'product_id']},
    date_time:       { operators: ['during'], 
                       fields:    ['created_at']},
    object_id:       { operators: ['in', 'not_in'], 
                       fields:    ['responder_id', 'group_id', 'internal_agent_id', 'internal_group_id']},
    object_id_array: { operators: ['in', 'and', 'not_in'], 
                       fields:    ['tag_ids']},
    checkbox:        { operators: ['selected', 'not_selected'],
                       fields:    ['checkbox']},
    number:          { operators: ['is', 'is_not', 'greater_than', 'less_than'],
                       fields:    ['number']},
    decimal:         { operators: ['is', 'is_not', 'greater_than', 'less_than'],
                       fields:    ['decimal']},
    date:            { operators: ['is' , 'is_not', 'greater_than', 'less_than'],
                       fields:    ['date']}
  }

  CF_OPERATOR_TYPES = {
    'custom_dropdown' => 'choicelist',
    'custom_checkbox' => 'checkbox',
    'custom_number'   => 'number',
    'custom_decimal'  => 'decimal',
    'nested_field'    => 'nestedlist',
    'custom_date'     => 'date'
  }
end
