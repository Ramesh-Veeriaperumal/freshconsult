class Freshfone::CallMetric < ActiveRecord::Base
	self.table_name = :freshfone_call_metrics
	self.primary_key = :id

	belongs_to_account
	belongs_to :freshfone_call, :foreign_key => 'call_id', :class_name => "Freshfone::Call"

	before_save :recalculate_metrics, :if => :hold_duration_changed?

  attr_accessor :params, :call, :call_changes

  def process(call)
    self.call = call
    self.call_changes = call.changes

    update_ivr_time        if ivr_time.blank? && ivr_complete?
    update_ringing_at      if ringing_at.blank? && ringing_started?
    update_answered_at     if answered_at.blank? && call_accepted?
    update_hangup_metrics  if call_disconnected?
    update_hold_duration   if hold_complete?
    update_queue_duration  if dequeued?
    update_answering_speed if answering_speed.blank? && call_answered?
    
    self.save!
  end

  def update_ringing_at
    self.ringing_at = Time.zone.now
  end

  def update_answered_at
    self.answered_at = Time.zone.now
  end

  def update_hold_duration
    self.hold_duration = call_changes[:hold_duration].last
  end

  def update_ivr_time
    self.ivr_time = (Time.zone.now - created_at).to_i.abs if call.is_root?
  end

  def update_queue_duration
    self.queue_wait_time = call_changes[:queue_duration].last
  end

  def update_answering_speed
    return rr_answering_speed if round_robin_routing? && call.is_root?
    regular_answering_speed
  end

  def regular_answering_speed
    return if call.outgoing? && call.is_root? #Outgoing parent calls does not have answering speed as there is no ringing time
    self.answering_speed =  self.total_ringing_time
  end

  def rr_answering_speed
    ringing_time = call.meta.pinged_agent_ringing_time call.user_id, answered_at
    self.answering_speed =  ringing_time
  end

  def update_acw_duration
    self.call_work_time = (Time.zone.now - hangup_at).to_i.abs if (call_work_time == 0 && hangup_at.present?)
    self.handle_time = calculate_handle_time
    save!
  end

  def update_hangup_metrics
    self.hangup_at = Time.zone.now if hangup_at.blank?
    self.talk_time = ((self.hangup_at - self.answered_at).to_i.abs - self.hold_duration) if 
          talk_time.blank? && hangup_at && answered_at
    self.ringing_at = created_at if call.ancestry.present?
    self.total_ringing_time = calculate_total_ring_time if total_ringing_time.blank?
    self.handle_time = calculate_handle_time
  end

  [:hold_duration, :call_work_time, :handle_time].each do |metric|
    define_method("empty_#{metric}?") do
      (self|| {})[metric] == 0
    end
  end

  private
    def ivr_complete?
      return if call.outgoing?
      if call_changes[:conference_sid]
        #Temporarily checking conference sid changes to identify it is ringing call. Should be changed to changes based on call status
        call_changes[:conference_sid].first.blank? && call_changes[:conference_sid].last.present?
      elsif call_changes[:call_status] 
        #IVR to queued
        call_changes[:call_status].first == Freshfone::Call::CALL_STATUS_HASH[:default] &&
        call_changes[:call_status].last == Freshfone::Call::CALL_STATUS_HASH[:queued]
      elsif call_changes[:abandon_state]
        #call abandoned in IVR
        call_changes[:abandon_state].first.blank? && 
          call_changes[:abandon_state].last == Freshfone::Call::CALL_ABANDON_TYPE_HASH[:ivr_abandon]
      end
    end

    def ringing_started?
      return if call_changes[:conference_sid].blank?
      call_changes[:conference_sid].first.blank? && call_changes[:conference_sid].last.present?
    end

    def hold_complete?
      call_changes[:hold_duration].present?
    end

    def dequeued?
      call_changes[:queue_duration].present?
    end

    def call_answered?
      return if call_changes[:call_status].blank?
      call_changes[:call_status].last == Freshfone::Call::CALL_STATUS_HASH[:completed]
    end

    def call_accepted?
      #Old status should not be hold. Makes it easier to not check for multiple status like ringing, queued, connecting
      return if call_changes[:call_status].blank? 
      call_changes[:call_status].first != Freshfone::Call::CALL_STATUS_HASH[:'on-hold'] &&
      call_changes[:call_status].last == Freshfone::Call::CALL_STATUS_HASH[:'in-progress']
    end

    def call_disconnected?
      return if call_changes[:call_status].blank?
      call_statuses = Freshfone::Call::CALL_STATUS_HASH
      [ call_statuses[:completed], call_statuses[:busy], 
        call_statuses[:'no-answer'], call_statuses[:voicemail] ].include? call_changes[:call_status].last
    end

    def round_robin_routing?
      self.freshfone_call.round_robin_call?
    end

    def calculate_total_ring_time
      disconnected_at = answered_at || hangup_at
      return (disconnected_at - self.ringing_at).to_i.abs if ringing_at.present?
    end

    def calculate_handle_time
      return if self.talk_time.blank?
      self.talk_time + self.hold_duration + self.call_work_time
    end

    def recalculate_metrics
      self.talk_time = self.talk_time - (self.hold_duration - self.hold_duration_was)
      calculate_handle_time
    end

    def hold_duration_changed?
      (self.changes.key?(:hold_duration) && self.talk_time.present?)
    end
end