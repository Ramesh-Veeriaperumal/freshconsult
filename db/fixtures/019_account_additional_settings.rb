account = Account.current

AccountAdditionalSettings.seed(:account_id) do |a|
  a.account_id = account.id
  a.email_cmds_delimeter = "@Simonsays"
  a.ticket_id_delimiter = "#"
end
