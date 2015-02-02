class Workers::ExportCompany
  extend Resque::AroundPerform 
  @queue = "export_company"

  def self.perform(args)
    user = Account.current.users.find(args[:user])
    user.make_current

    customer_export = Export::Customer.new(args[:csv_hash],args[:portal_url], "company")
    customer_export.export_data
  end
end