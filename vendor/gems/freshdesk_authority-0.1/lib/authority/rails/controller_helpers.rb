module Authority::Rails
  module ControllerHelpers

    def self.included(base)
      base.send :before_filter, :check_privilege
      base.send :helper_method, :privilege?
    end
  
    def check_privilege
      access_denied and return if(current_user.nil? || current_user.customer? || !allowed_to_access?)
    end

    def privilege?(privilege, object = nil)
      current_user && (current_user.privilege?(privilege) || current_user.owns_object?(object))
    end
           
    private
    
      def allowed_to_access?
        return false unless ABILITIES.key?(resource)

        ABILITIES[resource].each do |privilege|
          if [:all, action].include? privilege.action
            return true if current_user.privilege?(privilege.name) or 
              current_user.owns_object?(privilege.load_object(current_account, params))            
          end
        end

        false
      end

      def resource
        @resource ||= params[:controller].singularize.to_sym
      end

      def action
        @action ||= params[:action].to_sym
      end
  end
end