account = Account.current

category = ForumCategory.seed(:account_id, :name) do |s|
  s.account_id = account.id
  s.name = "#{account.helpdesk_name} Forums"
  s.description = 'Default forum category, feel free to edit or delete it.'
end

Forum.seed_many(:account_id, :forum_category_id, :name, [
    ['Announcements', 'General helpdesk announcements to the customers.', :howto],
    ['Feature Requests', 'Customers can voice their ideas here.', :ideas],
    ['Tips and Tricks', 'Helpful Tips and Tricks.', :howto],
    ['Help from the Community', 'No description...', :howto]
  ].map do |f|
    {
      :account_id => account.id,
      :forum_category_id => category.id,
      :name => f[0],
      :description => f[1],
      :forum_type => Forum::TYPE_KEYS_BY_TOKEN[f[2]]
    }
  end
)
