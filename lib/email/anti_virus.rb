module Email::AntiVirus
  
  def self.scan args
    Email::Antivirus::Clamav::Connection.scan(args)
  end

end