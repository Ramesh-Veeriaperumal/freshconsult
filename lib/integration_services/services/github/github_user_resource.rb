module IntegrationServices::Services
  module Github
    class GithubUserResource < GithubResource

      def get_user(user_name)
        response = http_get "#{github_users_path}/#{user_name}"
        process_response(response, 200) do |user|
          return user
        end
      end

      private
      def github_users_path
        "#{ @service.server_url }/users"
      end
    end
  end
end
