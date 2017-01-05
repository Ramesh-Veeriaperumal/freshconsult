module Email::AntiSpam

  def self.scan signup_params,account_id
    Email::Antispam::EhawkEmailVerifier.scan(signup_params,account_id) 
  end

end