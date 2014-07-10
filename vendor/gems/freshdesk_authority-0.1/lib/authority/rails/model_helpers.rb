module Authority::Rails
  module ModelHelpers
    
    def privilege?(privilege)
      return false if PRIVILEGES[privilege].nil?
      !(self[:privileges].to_i & 2**PRIVILEGES[privilege]).zero?
    end
    
    def owns_object?(object)
      # TODO: add support for other scopes
      object.respond_to?(:user_id) && object.user_id == id
    end
    
    def abilities
      PRIVILEGES_BY_NAME.select { |privilege| privilege?(privilege) }
    end

    def union_privileges roles
      roles.map { |r| r.privileges.to_i }.inject(0, :|)
    end
  end
end