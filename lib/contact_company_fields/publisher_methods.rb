module ContactCompanyFields::PublisherMethods
  def construct_model_changes
    @model_changes = self.changes.clone.to_hash
    @model_changes = discardable_change? ? {} : modify_model_changes
  end

  private

    # discard if it has only updated_at or created and updated_at
    def touched?
      @model_changes.keys == ['updated_at'] || @model_changes.keys == ['created_at', 'updated_at']
    end

    def convert_to_utc
      @model_changes['updated_at'][0] = Time.at(@model_changes['updated_at'][0].to_i).utc
      @model_changes['updated_at'][1] = Time.at(@model_changes['updated_at'][1].to_i).utc
    end

    def discardable_change?
      return true if touched?

      @model_changes['position'].present? && @model_changes['position'].include?(nil) # discard if it has dummy position change
    end

    # ignoring created_at and also updated_at changes with same old and new value
    def modify_model_changes
      @model_changes.delete('created_at') if @model_changes['created_at'].present?
      if @model_changes['updated_at'].present?
        @model_changes['updated_at'][0] == @model_changes['updated_at'][1] ? @model_changes.delete('updated_at') : convert_to_utc
      end
      @model_changes
    end
end
