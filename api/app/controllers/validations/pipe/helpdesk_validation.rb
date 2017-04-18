module Pipe
	class HelpdeskValidation < ApiValidation
	  attr_accessor :disabled
	  validates :disabled, data_type:{rules: "Boolean"}
	end
end