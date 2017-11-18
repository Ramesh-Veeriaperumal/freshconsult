module Freshquery
  class Response
    attr_accessor :terms, :errors, :error_options

    def initialize(valid, terms, obj = nil)
      @valid = valid
      @terms = terms
      if obj
        @errors = obj.errors
        @error_options = obj.error_options
      end
    end

    def valid?
      @valid
    end

    def error_options
      @error_options || {}
    end
  end
end
