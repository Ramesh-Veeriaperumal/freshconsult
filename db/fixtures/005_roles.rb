include Helpdesk::Roles

account = Account.current

Admin::Role.seed_many(:account_id, :name, [
    ["Administrator", ADMINISTRATOR, "Administrator"],
    ["Agent", AGENT, "Agent"]
  ].map do |role|
    {
      :name => role[0],
      :privileges => role[1],
      :description => role[2],
      :default => true,
      :account_id => account.id
    }
  end
)

unless User.current #In bootstrap, it is being called twice.
  Account.create_admin(account)
end