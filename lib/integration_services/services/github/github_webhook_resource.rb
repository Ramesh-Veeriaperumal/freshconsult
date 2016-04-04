module IntegrationServices::Services
  module Github
    class GithubWebhookResource < GithubResource

      def create_webhook(repo, name, config, options = {})
        config[:content_type] ||= 'json'
        config[:secret] = @service.configs["secret"]
        options = {:name => name, :config => config, :active => true}.merge(options)
        response = http_post "#{@service.server_url}/repos/#{repo}/hooks", options.to_json
        process_response(response, 201) do |hook|
          return hook
        end
      end

      def delete_webhook(repo, id, options = {})
        response = http_delete "#{@service.server_url}/repos/#{repo}/hooks/#{id}"
        process_response(response, 204, 404) do |res|
        end
      end

    end
  end
end
