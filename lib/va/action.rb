class Va::Action
  
  def initialize(act_hash)
    @act_hash = act_hash
  end
  
  def trigger(act_on)
    p "ACT HASH IN TRIGGER IS #{@act_hash}"
  end
end
