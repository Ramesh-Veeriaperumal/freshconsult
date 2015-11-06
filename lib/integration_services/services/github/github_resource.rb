module IntegrationServices::Services
  module Github
    class GithubResource < IntegrationServices::GenericResource

      def self.default_http_options
        super
        @@default_http_options[:ssl] = {:verify => true, :verify_depth => 5}
        @@default_http_options
      end

      def faraday_builder(b)
        super
        b.headers["Authorization"] = "token #{@service.configs["oauth_token"]}"
        b.use FaradayMiddleware::FollowRedirects, limit: 3
      end

      def parse_rel_links(headers)
        links = ( headers["Link"] || "" ).split(', ').map do |link|
          href, name = link.match(/<(.*?)>; rel="(\w+)"/).captures
          [name.to_sym, href]
        end

        Hash[*links.flatten]
      end

      def get_all_pages(url, options = {}, previous_response = [])
        options[:per_page] ||= 100
        response = http_get(url, options)
        process_response(response, 200) do |parsed_response|
          next_link = parse_rel_links(response.headers)[:next]
          if next_link.present?
            github_all_pages(next_link, options, previous_response + parsed_response)
          else
            previous_response + parsed_response
          end
        end
      end

      def process_response(response, *success_codes, &block)
        if success_codes.include?(response.status)
          yield parse(response.body)
        elsif response.status.between?(400, 499)
          error = parse(response.body)
          raise RemoteError.new(error['message'], response.status.to_s)
        else
          raise RemoteError.new("Unhandled error: STATUS=#{response.status} BODY=#{response.body}", response.status.to_s)
        end
      end

    end
  end
end
