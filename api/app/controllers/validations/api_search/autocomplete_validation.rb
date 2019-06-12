module ApiSearch
  class AutocompleteValidation < ApiValidation
    attr_accessor :name
    validates :name, data_type: { rules: String, allow_nil: false, required: true }
  end
end
