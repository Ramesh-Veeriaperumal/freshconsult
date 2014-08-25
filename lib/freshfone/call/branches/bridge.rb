module Freshfone::Call::Branches::Bridge
  include Freshfone::Queue

  def check_for_bridged_calls
    bridge_queued_call(params[:agent]) if answered_on_mobile?
  end

  private
    def answered_on_mobile?
      call_forwarded? and params[:direct_dial_number].blank?
    end

end