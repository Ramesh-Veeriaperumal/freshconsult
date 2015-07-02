module LaunchParty::Extenders
  # targetable
  # targetable_for_launch
  # launch_at_this
  # accepts_launches
  def is_a_launch_target
    include AccountInstanceMethods
  end
  
  module AccountInstanceMethods
    def launch(*features)
      features.collect!(&:to_sym).each do |f|
        launch_party.toggle_for_account(f, self, true)
      end
      @all_features = all_features | features
    end
    
    def launched?(*features)
      features.each do |f|
        return false unless all_features.include?(f.to_sym)
      end
      true
    end
    
    def launched_any_of?(*features)
      features.each do |f|
        return true if all_features.include?(f.to_sym)
      end
      false
    end
    
    def takeback(feature)
      launch_party.toggle_for_account(feature.to_sym, self, false)
      @all_features = all_features - [feature.to_sym]
    end
    
    def reload_features
      @all_features = launch_party.launched_for_everyone | launch_party.launched_for_account(self)
    end
    
    def clear_all_features
      launch_party.takeback_everything_for_account(self)
      @all_features = []
    end
    
    def all_features
      @all_features ||= launch_party.launched_for_everyone | launch_party.launched_for_account(self)
    end
    
    def launch_party
      @launch_party ||= LaunchParty.new
    end
  end
end