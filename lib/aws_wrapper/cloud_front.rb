module AwsWrapper
  class CloudFront
    class << self
      CF_RESPONSE_HEADERS = [:response_content_type, :response_content_disposition].freeze
      CF_REQUEST_URL = 'https://%{host}/%{path}'.freeze

      def url_for(path, options)
        uri = cf_uri(path, options)
        cf_signer.signed_url(uri, expires: fetch_expiry(options[:expires]))
      end

      def cf_signer
        Aws::CloudFront::UrlSigner.new(signer_params)
      end

      def cf_uri(path, options)
        host = CLOUD_FRONT_CONFIG[:host]
        path = AWS::Core::UriEscape.escape_path(path)
        uri = format(CF_REQUEST_URL, host: host, path: path)

        query_string = fetch_query_string(options)
        uri << "?#{query_string}" if query_string
        uri
      end

      def fetch_expiry(expiry)
        expiry.is_a?(Integer) ? expiry.to_i.seconds.from_now : expiry
      end

      def fetch_query_string(options)
        input = options.slice(*CF_RESPONSE_HEADERS)
        query_hash = {}
        query_hash['response-content-disposition'] = input[:response_content_disposition] if input[:response_content_disposition]
        query_hash['response-content-type'] = input[:response_content_type] if input[:response_content_type]
        query_hash.present? ? query_hash.to_query : nil
      end

      def signer_params
        {
          key_pair_id: CLOUD_FRONT_CONFIG[:key_pair_id],
          private_key: CLOUD_FRONT_CONFIG[:private_key]
        }
      end
    end
  end
end
