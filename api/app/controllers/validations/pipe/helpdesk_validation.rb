module Pipe
	class HelpdeskValidation < ApiValidation
	  attr_accessor :disabled, :limit
	  validates :disabled, data_type:{rules: "Boolean"}
	  validates :limit, custom_numericality: { only_integer: true }, allow_nil: true
	end
end