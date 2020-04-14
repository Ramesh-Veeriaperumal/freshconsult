module AutomationRulesTestHelper
  FIELD_OPERATOR_MAPPING = {
    email:           { operators: ['is', 'is_not', 'contains', 'does_not_contain'], 
                       fields:    ['from_email', 'to_email', 'ticlet_cc'],
                       actions:   ['priority', 'ticket_type', 'status', 'responder_id', 'product_id', 'group_id']},
    text:            { operators: ['is', 'is_not', 'contains', 'does_not_contain', 
                                   'starts_with', 'ends_with'], 
                       fields:    ['subject', 'description', 'subject_or_description'],
                       actions:   ['group_id']},
    choicelist:      { operators: ['in', 'not_in'], 
                       fields:    ['priority', 'ticket_type', 'status', 'source', 'product_id'],
                       actions:   ['group_id']},
    date_time:       { operators: ['during'], 
                       fields:    ['created_during'],
                       actions:   ['group_id']},
    object_id:       { operators: ['in', 'not_in'], 
                       fields:    ['responder_id', 'group_id', 'internal_agent_id', 'internal_group_id'],
                       actions:   ['group_id']},
    object_id_array: { operators: ['in', 'and', 'not_in'], 
                       fields:    ['tag_ids'],
                       actions:   ['group_id']},
    checkbox:        { operators: ['selected', 'not_selected'],
                       fields:    ['checkbox'],
                       actions:   ['group_id']},
    number:          { operators: ['is', 'is_not', 'greater_than', 'less_than'],
                       fields:    ['number'],
                       actions:   ['group_id']},
    decimal:         { operators: ['is', 'is_not', 'greater_than', 'less_than'],
                       fields:    ['decimal'],
                       actions:   ['group_id']},
    date:            { operators: ['is' , 'is_not', 'greater_than', 'less_than'],
                       fields:    ['date'],
                       actions:   ['group_id']}
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