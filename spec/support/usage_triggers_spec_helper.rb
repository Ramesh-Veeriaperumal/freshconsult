module UsageTriggersSpecHelper
  def create_ut(type, trigger_value = 100)
    @usage_trigger = Freshfone::UsageTrigger.create(
      :account => @account,
      :freshfone_account => @account.freshfone_account,
      :sid => "UT#{type.to_s}",
      :trigger_type => type,
      :start_value => 15,
      :idempotency_token => "DummyToken",
      :trigger_value => trigger_value)
  end

  def credit_overdraft_params
    {"AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "DateFired"=>"Mon, 21 Apr 2014 09:14:35 +0000", 
      "UsageTriggerSid"=>"UTcredit_overdraft", "CurrentValue"=>"50", 
      "IdempotencyToken"=>"AC626dc6e5b03904e6270f353f4a2f068f-FIRES-UTcredit_overdraft-2014-04-21", 
      "TriggerBy"=>"quantity", "TriggerValue"=>"1000", "UsageCategory"=>"totalprice", 
      "UsageRecordUri"=>"/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Usage/Records/Daily?Category=totalprice", 
      "Recurring"=>"" }
  end

  def daily_credit_threshold_params
     {"AccountSid"=>"AC626dc6e5b03904e6270f353f4a2f068f", "DateFired"=>"Mon, 21 Apr 2014 09:14:35 +0000", 
      "UsageTriggerSid"=>"UTdaily_credit_threshold", "CurrentValue"=>"12", 
      "IdempotencyToken"=>"AC626dc6e5b03904e6270f353f4a2f068f-FIRES-UTdaily_credit_threshold-2014-04-21", 
      "TriggerBy"=>"quantity", "TriggerValue"=>"5", "UsageCategory"=>"totalprice", 
      "UsageRecordUri"=>"/2010-04-01/Accounts/AC626dc6e5b03904e6270f353f4a2f068f/Usage/Records/Daily?Category=totalprice", 
      "Recurring"=>"daily"}
  end
end