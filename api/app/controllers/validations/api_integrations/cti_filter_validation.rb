module ApiIntegrations
  class CtiFilterValidation < FilterValidation
    attr_accessor :call_reference_id
    validates :call_reference_id, data_type: { rules: String, required: true }
  end
end
