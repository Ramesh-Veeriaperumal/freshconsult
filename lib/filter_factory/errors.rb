module FilterFactory
  module Errors
    class UnknownQuerySourceException < StandardError
    end

    class FQLFormatException < StandardError
    end

    class FQLValidationException < StandardError
    end
  end
end
