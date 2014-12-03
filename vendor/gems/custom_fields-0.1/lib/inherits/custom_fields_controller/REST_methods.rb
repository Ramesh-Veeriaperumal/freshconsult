module Inherits
  module CustomFieldsController
    module RESTMethods
  
      def index
        @fields_to_render = index_scoper

        respond_to do |format|
          format.html {
            @fields_json = fields_as_json @fields_to_render
          }
          format.xml  { render :xml  => @fields_to_render }
          format.json { render :json => @fields_to_render }
        end
      end

      def update
        @fields_to_render = []
        fields_posted     = JSON.parse params[:jsonData]

        fields_posted.each_with_index do |field, i| # Hack - should consult Parsu
          field.symbolize_keys!
          unless field[:position] && (field[:position] == (i+1))
            field[:position]  = i+1
            field[:action]  ||= 'update'
          end
        end
        @errors = execute_action_on_fields fields_posted
        flash_message @errors

        if !@errors.empty?
          @fields_to_render.sort!{ |f1,f2| f1.position <=> f2.position }
          @fields_json = fields_as_json @fields_to_render
        end
      end

      private
        def fields_as_json fields
          fields.map do |field|
            field.as_json({:methods => [:dom_type, :choices, :action]}).values.first
          end.to_json
        end

        def execute_action_on_fields fields_posted # Query Optimization # TODO
          grouped_fields  = fields_posted.group_by { |field| field.delete(:action)}
          errors          = []

          ['create', 'update', 'delete', nil].each do |action| # order - important (affects queries - acts_as_list)
            grouped_fields[action].each do |field|
              field       =  send("#{action || "return"}_field", field)
              unless field.nil?
                # label.gsub!(' ','&nbsp;') is not working # TODO - indent flash messages
                unless field.errors.count.zero?
                  errors    << "#{field.label.capitalize} 
                                #{field.errors.full_messages.join(', ')}"
                  field.action = action
                end
                @fields_to_render << field
              end
            end
          end

          errors.join('</br>').html_safe
        end

        def create_field field_details
          scoper_class.create_field field_details
        end

        def update_field field_details
          custom_field = find_field_by_id field_details.delete(:id)
          custom_field.update_field field_details unless custom_field.nil?
        end

        def delete_field field_details
          custom_field = find_field_by_id field_details.delete(:id)
          custom_field.delete_field unless custom_field.nil?
        end

        def return_field field_details
          return find_field_by_id field_details.delete(:id)
        end

        def find_field_by_id id
          index_scoper.find{ |field| field.id == id }
        end

        def flash_message(errors)
          unless errors.empty?
            flash[:error]  = errors
          else
            flash[:notice] = t(:'flash.cf.success', 
                      :type => t(:"flash.cf.type.#{self.class.name.demodulize.underscore}"))
          end
        end

    end
  end
end