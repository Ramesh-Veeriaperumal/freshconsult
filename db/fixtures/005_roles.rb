include Helpdesk::Roles

account = Account.current

Role.seed_many(:account_id, :name, [
    ["Account Administrator", ACCOUNT_ADMINISTRATOR, "Account Administrator"],
    ["Administrator",         ADMINISTRATOR,         "Administrator"],
    ["Supervisor",            SUPERVISOR,            "Supervisor"],
    ["Agent",                 AGENT,                 "Agent"]
  ].map do |role|
    {
      :name => role[0],
      :privilege_list => role[1],
      :description => role[2],
      :default_role => true,
      :account_id => account.id
    }
  end
)

unless User.current #In bootstrap, it is being called twice.
  Account.create_admin(account)
end