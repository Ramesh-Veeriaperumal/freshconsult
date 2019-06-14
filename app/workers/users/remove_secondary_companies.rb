class Users::RemoveSecondaryCompanies < BaseWorker
  sidekiq_options queue: :remove_secondary_companies,
                  retry: 0,
                  failures: :exhausted

  def perform
    Account.current.remove_secondary_companies
  end
end
