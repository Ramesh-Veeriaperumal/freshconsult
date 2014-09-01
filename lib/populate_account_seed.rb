module PopulateAccountSeed
  def self.populate_for(account)
    account.make_current
    SeedFu::PopulateSeed.populate
  end
end
