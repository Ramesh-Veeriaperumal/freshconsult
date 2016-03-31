# Constraint class for routing to V2 paths
class Search::V1Path

  PATHS_TO_CHECK = ['/search', '/support/search', '/contact_merge/search']

  def matches?(request)
    if ((PATHS_TO_CHECK.find { |path| request.path.starts_with?(path) }.present?) && 
        !request.user_agent.to_s[/#{AppConfig['app_name']}_Native/].present?)
      account_id = ShardMapping.lookup_with_domain(request.host).try(:account_id).to_i
      LaunchParty.new.launched?(feature: :es_v2_reads, account: account_id) rescue false
    end
  end
end