module Freshfone::CallHuntOptions

  HUNT_TYPE = {
    :twiml_response => :twiml,
    :call_agent => :User,
    :call_group => :Group,
    :call_number => :Number
  }

  HUNT_TYPE.each do |k, v|
    define_method("#{k}?") do
      params[:hunt_type].present? &&
        params[:hunt_type].to_sym == v
    end
  end

  def set_hunt_options(type, performer)
    self.hunt_options = {
      :type => type,
      :performer => performer.to_s
    }
  end
end