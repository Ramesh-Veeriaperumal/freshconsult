module Email::AntiSpam

  def self.scan signup_params,account_id,account_name,account_domain
    Email::Antispam::EmailServiceEmailVerifier.scan(signup_params,account_id,account_name,account_domain) 
  end

end