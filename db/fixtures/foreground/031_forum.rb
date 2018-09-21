account = Account.current

category = ForumCategory.seed(:account_id, :name) do |s|
  s.account_id = account.id
  s.name = "#{account.portal_name} Forums"
  s.description = 'Default forum category, feel free to edit or delete it.'
end

Forum.seed_many(:account_id, :forum_category_id, :name, [
    ['Announcements', 'General announcement on updates and new features', :announce],
    ['Feature Requests', 'Ideas and suggestions from customers.', :ideas],
    ['Tips and Tricks', 'Helpful tips and tricks.', :howto],
    ['Report a problem', 'Issues or bugs reported by customers.', :problem],
    ['Sales and offers', 'All offers and discounts.', :announce]
  ].map do |f|
    {
      :account_id => account.id,
      :forum_category_id => category.id,
      :name => f[0],
      :description => f[1],
      :forum_type => Forum::TYPE_KEYS_BY_TOKEN[f[2]],
      :forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]
    }
  end
)
