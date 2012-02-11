account = Account.current

DayPassConfig.seed(:account_id) do |s|
  s.account_id = account.id
  s.available_passes = 3
  s.auto_recharge = false
  s.recharge_quantity = 10
end
