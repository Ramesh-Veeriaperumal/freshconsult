require 'authority/privilege'
require 'authority/bookkeeper'

module Authority
  class Mapper

    attr_accessor :privileges, :privileges_by_name

    def initialize
      self.privileges = {}
      self.privileges_by_name = []
    end

    def build(&block)
      instance_exec(&block)
      # TODO: Move this elsewhere !
      Authority::Authorization::Keeper.map(self.privileges_by_name) #unless Rails.env.production?
    end

    def add_privilege(privilege_name, &block)
      @privilege_scope = privilege_name
      privileges_by_name << @privilege_scope
      instance_exec(&block)
      @privilege_scope = nil
    end
    
    def resource(resource, *args)
      privilege_objects = []
      options = args.extract_options!

      if options.key?(:only)
        options[:only].each do |action|
          privilege_objects << Privilege.new(resource,
                                @privilege_scope,
                                :action => action,
                                :owned_by => options.fetch(:owned_by, false))
        end
      else
        privilege_objects << Privilege.new(resource,
                              @privilege_scope,
                              :owned_by => options.fetch(:owned_by, false))
      end

      # Add objects to respective resource in hash
      privileges[resource] ||= []
      privileges[resource] += privilege_objects
    end
    
    def method_missing(privilege_name, *args, &block)
      super if block.nil?
      add_privilege(privilege_name, &block)
    end

  end
end