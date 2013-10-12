class Workers::PopulateSecondarySeed

  extend Resque::AroundPerform
  @queue = "secondary_seed_worker"

  def self.perform args
    begin
      user = User.find_by_account_id_and_id(args[:account_id], args[:user_id])
      user.make_current
      SeedFu::PopulateSeed.populate("db/secondary_fixtures")
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    end
  end
end