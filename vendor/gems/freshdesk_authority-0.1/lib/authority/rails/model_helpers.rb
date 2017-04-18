module Authority::FreshdeskRails
  module ModelHelpers
    
    def privilege?(privilege)
      return false if PRIVILEGES[privilege].nil?
      !(self[:privileges].to_i & 2**PRIVILEGES[privilege]).zero?
    end
    
    def owns_object?(object)
      # TODO: add support for other scopes
      if object.respond_to?(:user_id)
        return object.user_id == id
      elsif object.respond_to?(:requester_id)
        return object.requester_id == id
      end
    end
    
    def abilities
      PRIVILEGES_BY_NAME.select { |privilege| privilege?(privilege) }
    end

    def union_privileges roles
      roles.map { |r| r.privileges.to_i }.inject(0, :|)
    end
  end
end