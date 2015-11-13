module IntegrationServices::Services
  module Github
    class GithubRepoResource < GithubResource

      def list_repos
        @repos ||= begin
          options = @service.payload ? @service.payload[:options] || {} : {}
          get_all_pages "#{@service.server_url}/user/repos", options
        end
      end

      def list_milestones
        @milestones ||= begin
          get_all_pages "#{@service.server_url}/repos/#{@service.payload[:repository]}/milestones"
        end
      end

    end
  end
end
