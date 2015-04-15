class Workers::Import::Contact
  extend Resque::AroundPerform

  @queue = "contact_import"

  def self.perform(args)
    Import::Customers::Contact.new(args).import
  end
  
end