ForumModerator.seed(:account_id) do |m|
	m.account_id = Account.current.id
	m.moderator_id = User.current.id
end