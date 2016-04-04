module Swf
  class Register

    include Swf::ExceptionHandler

    def initialize(args)
      @domain             = args[:name]
      @description        = args[:description]
      @retention_duration = args[:retention_duration]
      @workflows          = args[:workflows]
      @activities         = args[:activities]
    end

    def perform
      swf_sandbox do
        register_domain

        @workflows.values.each do |workflow|
          register_workflow(workflow)
        end

        @activities.values.each do |activity|
          register_activity(activity)
        end
      end
    end  

    private

      def register_domain
        unless domain_exists?
          $swf_client.register_domain(  
            name: @domain,
            description: @domain_description,
            workflow_execution_retention_period_in_days: @retention_duration,
          )
        end
      end

      def register_workflow(workflow)
        unless workflow_exists?(workflow)
          workflow.merge!(domain: @domain).delete(:activities)
          $swf_client.register_workflow_type(workflow)
        end
      end
 
      def register_activity(activity)
        unless activity_exists?(activity)
          activity.merge!(domain: @domain)
          $swf_client.register_activity_type(activity)
        end
      end
      
      # The results of the following methods may be split into multiple pages(1000 per page). 
      # To retrieve subsequent pages, make the call again using the next_page_token.
      
      def domain_exists?
        domain_list = $swf_client.list_domains(
          registration_status: "REGISTERED" 
        )
        domain_list.domain_infos.select {|info| info["name"] == @domain }.any?
      end
      
      ["workflow", "activity"].each do |object_name|
        define_method("#{object_name}_exists?") do |object|
          object_list = $swf_client.send("list_#{object_name}_types", {
            domain: @domain,
            name: object[:name],
            registration_status: "REGISTERED" 
          })
          object_list.type_infos.select { |info| info["#{object_name}_type"]["name"] == object[:name] &&
                                                    info["#{object_name}_type"]["version"] == object[:version] }.any?
        end
      end

  end
end