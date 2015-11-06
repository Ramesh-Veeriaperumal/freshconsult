class Auth::Result
  attr_accessor :user, :redirect_url

  attr_accessor :failed,
                :failed_reason

  def initialize
    @failed = false
  end

  def failed?
    !!@failed
  end

end
