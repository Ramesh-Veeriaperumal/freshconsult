module PopulateAccountSeed
  def self.populate_for(account)
    ENV["FIXTURE_PATH"] = "db/fixtures"
    account.make_current
    SeedFu::PopulateSeed.populate
  end
end
