class Workers::ExportContact
  extend Resque::AroundPerform 
  @queue = "export_contact"

  def self.perform(args)
    user = Account.current.users.find(args[:user])
    user.make_current
    
    customer_export = Export::Customer.new(args[:csv_hash],args[:portal_url], "contact")
    customer_export.export_data
  end
end