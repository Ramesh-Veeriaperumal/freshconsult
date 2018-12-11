account = Account.current
GroupType.populate_default_group_types(account) unless account.group_types.length > 0