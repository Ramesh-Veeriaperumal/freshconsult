class Freshfone::Jobs::AutoRecharge
  extend Resque::AroundPerform
  @queue = "freshfone_default_queue"
  def self.perform(args)
    freshfone_credit = Freshfone::Credit.find_by_id(args[:id])
    freshfone_credit.perform_auto_recharge
  end
end