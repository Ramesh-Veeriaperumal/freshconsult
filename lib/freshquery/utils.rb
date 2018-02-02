module Freshquery
  class Utils
    def self.error_response(terms, key, message)
      errors = ActiveModel::Errors.new(Object.new)
      errors.messages[key.to_sym] = [message]
      response = Freshquery::Response.new(false, terms, nil)
      response.errors = errors
      response
    end

    # replica of search/utils/exact_match? method
    def self.exact_match?(search_term)
    	search_term.present? and (search_term.start_with?('<','"') && search_term.end_with?('>', '"'))
  	end
  end
end
