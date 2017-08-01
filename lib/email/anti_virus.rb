module Email::AntiVirus
  
  def self.scan args
    Email::Antivirus::Clamav::ConnectionHandler.new().scan_for_virus(args)
  end

end