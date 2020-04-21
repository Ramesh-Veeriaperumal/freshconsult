class HyperTrail::ActivityObject::TicketActivity < HyperTrail::ActivityObject::FreshdeskActivity
  ACTIVITY_TYPE = 'ticket'.freeze
  UNIQUE_ID = 'display_id'.freeze

  def activity_type
    ACTIVITY_TYPE
  end

  def unique_id
    UNIQUE_ID
  end
end
