Group.seed_many(:account_id, :name, [
    ['Product Management', 'Product Management group'],
    ['QA', 'Members of the QA team belong to this group'],
    ['Sales', 'People in the Sales team are members of this group']
  ].map do |f|
    {
      :account_id => Account.current.id,
      :name => f[0],
      :description => f[1],
    }
  end
)
