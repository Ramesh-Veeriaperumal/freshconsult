class Va::Handlers::Text < Va::RuleHandler

  private
    def is(evaluate_on_value, field_value=nil)
      if field_value.nil?
        evaluate_on_value && evaluate_on_value.casecmp(value) == 0
      else
        evaluate_on_value && evaluate_on_value.casecmp(field_value.to_s) == 0
      end
    end

    def is_not(evaluate_on_value, field_value=nil)
      !is(evaluate_on_value, field_value)
    end

    def contains_value(evaluate_on_value)
      evaluate_on_value && evaluate_on_value.downcase.include?(value.downcase)
    end

    def does_not_contain(evaluate_on_value)
      !contains(evaluate_on_value)
    end

    def starts_with(evaluate_on_value)
      evaluate_on_value && evaluate_on_value.downcase.starts_with?(value.downcase)
    end

    def ends_with(evaluate_on_value)
      evaluate_on_value && evaluate_on_value.downcase.ends_with?(value.downcase)
    end
    
    def filter_query_is(field_key=nil,field_value=nil)
      if field_key.nil?
        [ "#{condition.db_column} = ?", value ]
      else
        "flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} = #{field_value.to_s}"
      end
    end
    
    def filter_query_is_not(field_key=nil,field_values=nil)
      if field_key.nil?
        [ "#{condition.db_column} != ?", value ]
      else
        "flexifields.#{FlexifieldDefEntry.ticket_db_column field_key} != #{field_value.to_s}"
      end
    end
    
    def filter_query_contains
      [ "#{condition.db_column} like ?", "%#{value}%" ]
    end
    
    def filter_query_does_not_contain
      [ "#{condition.db_column} not like ?", "%#{value}%" ]
    end
    
    def filter_query_starts_with
      [ "#{condition.db_column} like ?", "#{value}%" ]
    end
    
    def filter_query_ends_with
      [ "#{condition.db_column} like ?", "%#{value}" ]
    end
end
