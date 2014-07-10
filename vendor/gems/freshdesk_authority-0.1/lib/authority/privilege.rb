module Authority
  class Privilege
    attr_reader :resource, :name, :action, :owned_by

    def initialize(resource, privilege_name, *args)
      options = args.extract_options!
      @resource = resource
      @action = options.fetch(:action, :all)
      @name = privilege_name
      @owned_by = options.fetch(:owned_by, false)
    end

    def scoper
      @owned_by[:scoper]
    end

    def attribute
      @owned_by.fetch(:find_by, :id)
    end

    def to_s
      "%-50s %-30s %-50s %s" % [@resource.to_s.upcase, @action, @name, @owned_by]
    end
    
    def load_object(account, params)
      return nil unless @owned_by
      raise Exception if(scoper.nil? or !account.respond_to?(scoper))
      # TODO: Add support for scoping beyond account
      account.send(scoper).send("find_by_#{attribute}", params[attribute])
    end
  end
end