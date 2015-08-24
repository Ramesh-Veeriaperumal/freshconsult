class Freshfone::Initiator::Record

  def self.match?(params)
    params[:record].present?
  end

  attr_accessor :params, :current_account, :current_number, :telephony

  def initialize(params, current_account, current_number)
    self.params          = params
    self.current_account = current_account
    self.current_number  = current_number
    self.telephony       = Freshfone::Telephony.new(params, current_account, current_number)
  end

  def process
    telephony.initiate_recording
  end
end