class Dkim::DomainAlreadyConfiguredError < Exception
  def initialize(msg = 'Already configured and verified domain')
    super(msg)
  end
end