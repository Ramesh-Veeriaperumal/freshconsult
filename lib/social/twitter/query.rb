class Social::Twitter::Query

  include Social::Twitter::Constants

  def initialize(keywords, excludes, exclude_handles, rt_string = TWITTER_RULE_OPERATOR[:ignore_rt])
    @includes         = filter_params(keywords)
    @excludes         = filter_params(excludes)
    @exclude_handles  = filter_params(exclude_handles)
    @rt_string        = rt_string
  end

  def query_string
    "(#{includes_string} #{excludes_string} #{exclude_handles_string}) #{@rt_string}".squeeze(" ")
  end

  private
  def includes_string
    includes = @includes.map { |q| q.split(" ").length > 1 ? "(#{q.strip})" : q.strip }
    includes.join("#{TWITTER_RULE_OPERATOR[:or]}").strip
  end

  def exclude_handles_string
    @exclude_handles.map { |handle| "#{TWITTER_RULE_OPERATOR[:neg]}#{TWITTER_RULE_OPERATOR[:from]}#{handle.strip}"}.join(" ")
  end

  def excludes_string
    @excludes.map{ |keyword| "#{TWITTER_RULE_OPERATOR[:neg]}#{keyword.strip}"}.join(" ").strip
  end

  def filter_params(params)
    (params || []).delete_if { |param| param.eql?("")}.sort!
  end

end
