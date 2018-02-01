class TodoValidation < FilterValidation
  attr_accessor :body, :rememberable_id, :completed, :type

  validates :body, data_type: { 
                    rules: String, 
                    allow_nil: false 
                  }
  validates :body, custom_length: { 
                    maximum: TodoConstants::MAX_LENGTH_OF_TODO_CONTENT 
                  }
  validates :completed, data_type: { 
                          rules: 'Boolean' 
                        }
  validates :rememberable_id, custom_numericality: {
                    only_integer: true,
                    ignore_string: :allow_string_param,
                    required: true
                  }, if: -> { 
                              type.present?
                            }
  validates :type, custom_inclusion: { 
                    in: TodoConstants::TODO_REMEMBERABLES, 
                    ignore_string: :allow_string_param, 
                    detect_type: true, 
                    allow_nil: true 
                  }
end
