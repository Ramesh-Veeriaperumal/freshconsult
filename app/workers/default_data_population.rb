class DefaultDataPopulation
  include Sidekiq::Worker
  sidekiq_options :queue => :default_data_population, :retry => 0, :failures => :exhausted

  def perform(args = {})
    args.symbolize_keys!
    Account.current.account_managers.first.make_current
    industry = args[:industry]
    Fixtures::IndustryBasedDefaultData.new.populate(industry)
    Account.current.mark_sample_data_setup_and_save
  end
end