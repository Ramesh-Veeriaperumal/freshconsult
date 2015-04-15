class Workers::Import::Company
  extend Resque::AroundPerform

  @queue = "company_import"

  def self.perform(args)
    Import::Customers::Company.new(args).import
  end  
  
end