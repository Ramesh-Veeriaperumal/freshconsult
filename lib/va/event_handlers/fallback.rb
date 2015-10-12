class Va::EventHandlers::Fallback < Va::EventHandler

  def matches? *args
    false
  end

end
