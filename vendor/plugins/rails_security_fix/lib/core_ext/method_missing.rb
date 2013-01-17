#https://groups.google.com/forum/?fromgroups=#!topic/rubyonrails-security/DCNTNp_qjFM
#Better way is to move to Rails 2.3.15

ActiveRecord::Base.class_eval do

  class << self
    
    private
    
      def method_missing(method_id, *arguments, &block)
        if match = ActiveRecord::DynamicFinderMatch.match(method_id)
            attribute_names = match.attribute_names
            super unless all_attributes_exists?(attribute_names)
            if match.finder?
              finder = match.finder
              bang = match.bang?
              # def self.find_by_login_and_activated(*args)
              #   options = args.extract_options!
              #   attributes = construct_attributes_from_arguments(
              #     [:login,:activated],
              #     args
              #   )
              #   finder_options = { :conditions => attributes }
              #   validate_find_options(options)
              #   set_readonly_option!(options)
              #
              #   if options[:conditions]
              #     with_scope(:find => finder_options) do
              #       find(:first, options)
              #     end
              #   else
              #     find(:first, options.merge(finder_options))
              #   end
              # end
              self.class_eval <<-EOS, __FILE__, __LINE__ + 1
                def self.#{method_id}(*args)
                  #options = args.extract_options!
                  options = if args.length > #{attribute_names.size}  
                                  args.extract_options! 
                              else
                               {}
                            end
                  attributes = construct_attributes_from_arguments(
                    [:#{attribute_names.join(',:')}],
                    args
                  )
                  finder_options = { :conditions => attributes }
                  validate_find_options(options)
                  set_readonly_option!(options)

                  #{'result = ' if bang}if options[:conditions]
                    with_scope(:find => finder_options) do
                      find(:#{finder}, options)
                    end
                  else
                    find(:#{finder}, options.merge(finder_options))
                  end
                  #{'result || raise(RecordNotFound, "Couldn\'t find #{name} with #{attributes.to_a.collect {|pair| "#{pair.first} = #{pair.second}"}.join(\', \')}")' if bang}
                end
              EOS
              send(method_id, *arguments)
            elsif match.instantiator?
              instantiator = match.instantiator
              # def self.find_or_create_by_user_id(*args)
              #   guard_protected_attributes = false
              #
              #   if args[0].is_a?(Hash)
              #     guard_protected_attributes = true
              #     attributes = args[0].with_indifferent_access
              #     find_attributes = attributes.slice(*[:user_id])
              #   else
              #     find_attributes = attributes = construct_attributes_from_arguments([:user_id], args)
              #   end
              #
              #   options = { :conditions => find_attributes }
              #   set_readonly_option!(options)
              #
              #   record = find(:first, options)
              #
              #   if record.nil?
              #     record = self.new { |r| r.send(:attributes=, attributes, guard_protected_attributes) }
              #     yield(record) if block_given?
              #     record.save
              #     record
              #   else
              #     record
              #   end
              # end
              self.class_eval <<-EOS, __FILE__, __LINE__ + 1
                def self.#{method_id}(*args)
                  attributes = [:#{attribute_names.join(',:')}]
                  protected_attributes_for_create, unprotected_attributes_for_create = {}, {}
                  args.each_with_index do |arg, i|
                    if arg.is_a?(Hash)
                      protected_attributes_for_create = args[i].with_indifferent_access
                    else
                      unprotected_attributes_for_create[attributes[i]] = args[i]
                    end
                  end

                  find_attributes = (protected_attributes_for_create.merge(unprotected_attributes_for_create)).slice(*attributes)

                  options = { :conditions => find_attributes }
                  set_readonly_option!(options)

                  record = find(:first, options)

                  if record.nil?
                    record = self.new do |r|
                      r.send(:attributes=, protected_attributes_for_create, true) unless protected_attributes_for_create.empty?
                      r.send(:attributes=, unprotected_attributes_for_create, false) unless unprotected_attributes_for_create.empty?
                    end
                    #{'yield(record) if block_given?'}
                    #{'record.save' if instantiator == :create}
                    record
                  else
                    record
                  end
                end
              EOS
              send(method_id, *arguments, &block)
            end
          elsif match = ActiveRecord::DynamicScopeMatch.match(method_id)
            attribute_names = match.attribute_names
            super unless all_attributes_exists?(attribute_names)
            if match.scope?
              self.class_eval <<-EOS, __FILE__, __LINE__ + 1
                def self.#{method_id}(*args)                        # def self.scoped_by_user_name_and_password(*args)
                  options = args.extract_options!                   #   options = args.extract_options!
                  attributes = construct_attributes_from_arguments( #   attributes = construct_attributes_from_arguments(
                    [:#{attribute_names.join(',:')}], args          #     [:user_name, :password], args
                  )                                                 #   )
                                                                    # 
                  scoped(:conditions => attributes)                 #   scoped(:conditions => attributes)
                end                                                 # end
              EOS
              send(method_id, *arguments)
            end
          else
            super
          end
        end

    
    
   
  end
end