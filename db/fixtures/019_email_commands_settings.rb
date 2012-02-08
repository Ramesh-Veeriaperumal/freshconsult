account = Account.current

EmailCommandsSetting.seed() do |s|
  s.account_id = account.id
  s.email_cmds_delimeter = "@Simonsays"
end
