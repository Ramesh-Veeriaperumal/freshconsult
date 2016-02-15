class ConsecutiveFailedLoginError < StandardError
  attr_reader :failed_login_count

  def initialize(failed_login_count)
    @failed_login_count = failed_login_count
  end

end