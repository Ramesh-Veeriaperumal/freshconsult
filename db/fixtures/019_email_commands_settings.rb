account = Account.current

EmailCommandsSetting.seed(:account_id) do |s|
  s.account_id = account.id
  s.email_cmds_delimeter = "@Simonsays"
  s.ticket_id_delimiter = "[#ticket_id]"
end
