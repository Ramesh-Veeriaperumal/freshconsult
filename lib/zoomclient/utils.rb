module Zoomclient
  module Utils

    def argument_error(name)
      name ? ArgumentError.new("You must provide #{name}") : ArgumentError.new
    end

    def parse_response(http_response)
      response = http_response.parsed_response
      # Mocked response returns a string
      response.kind_of?(Hash) ? response : JSON.parse(response)
    end

    def require_params(params, options)
      params = [params] unless params.is_a? Array
      params.each do |param|
        unless options[param]
          raise argument_error(param.to_s)
          break
        end
      end
    end

    def extract_options!(array)
      array.last.is_a?(::Hash) ? array.pop : {}
    end

    def process_datetime_params!(params, options)
      params = [params] unless params.is_a? Array
      params.each do |param|
        if options[param] && options[param].kind_of?(Time)
          options[param] = options[param].strftime("%FT%TZ")
        end
      end
      options
    end
  end
end
