class Users::RemoveSecondaryCompanies < BaseWorker

  sidekiq_options :queue => :remove_secondary_companies, 
  :retry => 0, 
  :backtrace => true, 
  :failures => :exhausted

  def perform
    Account.current.user_companies.find_each do |user_company|
      user_company.destroy unless user_company.default
    end
  end
end
