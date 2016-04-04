module IntegrationServices::Services
  module Github
    class GithubIssueResource < GithubResource

      def create(title, body = nil, options = {})
        options[:labels] = case options[:labels]
                           when String
                             options[:labels].split(",").map(&:strip)
                           when Array
                             options[:labels]
                           else
                             []
                           end
        options[:title] = title
        options[:body] = body unless body.nil?
        options.delete(:milestone) if(options[:milestone].blank?)
        response =  http_post github_issues_path, options.to_json
        process_response(response, 201) do |issue|
          return issue
        end
      end

      def issue(number)
        response = http_get "#{github_issues_path}/#{number}"
        process_response(response, 200) do |issue|
          return issue
        end
      end

      def add_comment(issue_number, comment)
        response = http_post github_issues_path + "/#{issue_number}/comments", { :body => comment }.to_json
        process_response(response, 201) do |note|
          return note
        end
      end

      private
      def github_issues_path
        "#{ @service.server_url }/repos/#{@service.payload[:repository]}/issues"
      end
    end
  end
end
