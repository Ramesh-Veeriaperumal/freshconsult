class Va::Handlers::TextArray < Va::RuleHandler

  #Downcase not used on evaluate_on_value, knowing that for now it will be used only
  #for tags and tags are stored in lower case.

  private
    def is(evaluate_on_value)
      evaluate_on_value.include?(value.downcase)
    end

    def is_not(evaluate_on_value)
      !is(evaluate_on_value)
    end

    def contains(evaluate_on_value)
      #evaluate_on_value && evaluate_on_value.downcase.include?(value.downcase)
      evaluate_on_value.each do |ev|
        return true if ev.include?(value.downcase)
      end
    end

    def does_not_contain(evaluate_on_value)
      !contains(evaluate_on_value)
    end

    def starts_with(evaluate_on_value)
      evaluate_on_value.each do |ev|
        return true if ev.starts_with?(value.downcase)
      end
    end

    def ends_with(evaluate_on_value)
      evaluate_on_value.each do |ev|
        return true if ev.ends_with?(value.downcase)
      end
    end
end
