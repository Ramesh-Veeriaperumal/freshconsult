class ApiConstraints
  def initialize(options)
    @version = options[:version]
  end

  def matches?(req)
    has_version = req.headers['Accept'].include?("application/vnd.freshdesk.v#{@version}") if req.headers['Accept']
  end
end