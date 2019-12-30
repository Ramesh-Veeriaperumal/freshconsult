service_group_type = GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME)

Group.seed_many(:account_id, :name, :group_type, [
  ['Brooklyn technicians'],
  ['Queens technicians'],
  ['Manhattan technicians']
].map do |f|
  {
    account_id: Account.current.id,
    name: f[0],
    group_type: service_group_type
  }
end)
