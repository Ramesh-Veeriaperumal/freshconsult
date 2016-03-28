class Import::CompanyWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :company_import, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    Import::Customers::Company.new(args).import
  end
end
