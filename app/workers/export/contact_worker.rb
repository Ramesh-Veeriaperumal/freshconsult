class Export::ContactWorker
  include Sidekiq::Worker

  sidekiq_options :queue => :contact_export, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  def perform(args)
    args.symbolize_keys!

    customer_export = Export::Customer.new(args[:csv_hash], args[:portal_url], "contact")
    customer_export.export_data
  end
end