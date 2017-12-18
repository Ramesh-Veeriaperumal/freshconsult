module Freshquery
  class Utils
    def self.error_response(terms, key, message)
      errors = ActiveModel::Errors.new(Object.new)
      errors.messages[key.to_sym] = [message]
      response = Freshquery::Response.new(false, terms, nil)
      response.errors = errors
      response
    end
  end
end
