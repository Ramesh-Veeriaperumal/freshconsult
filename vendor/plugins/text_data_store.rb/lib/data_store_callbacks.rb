module DataStoreCallbacks

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def text_datastore_callbacks(options={})
      class_attribute :text_data_store_options
      self.text_data_store_options = {
        :class => options[:class]
      }
      generate_methods
    end

    def generate_methods
      class_name = text_data_store_options[:class]
      class_eval %Q(
        after_create "create_#{class_name}_body"
        after_update "update_#{class_name}_body"
        after_destroy "destroy_#{class_name}_body"
        after_rollback "handle_rollback_for_riak"

        def create_#{class_name}_body
          self.rollback_#{class_name}_body = true
          created_at_updated_at_on_create
          datastore("create")
        end

        def update_#{class_name}_body
          if self.#{class_name}_body_content && self.#{class_name}_body_content.attributes_changed?
              puts "Inside update action"
            self.rollback_#{class_name}_body = true
            created_at_updated_at_on_update
            load_full_text
            datastore("update")
          end
        end

        def destroy_#{class_name}_body
          self.previous_value = self.#{class_name}_body
            self.rollback_#{class_name}_body = true
          datastore("delete")
        end

        def handle_rollback_for_riak
          if self.rollback_#{class_name}_body
            self.rollback_#{class_name}_body = false
            if self.previous_value
              self.#{class_name}_body_content = self.previous_value
                datastore("rollback")
            else
              destroy_#{class_name}_body
            end
          end
        end

        def created_at_updated_at_on_create
          self.#{class_name}_body_content.created_at = self.#{class_name}_body_content.updated_at  = Time.now.utc
        end

        def created_at_updated_at_on_update
          self.#{class_name}_body_content.updated_at = Time.now.utc
        end
      )

      class_eval do
        def datastore(type)
          send("#{type}_in_#{$primary_cluster}")
          send("#{type}_in_#{$secondary_cluster}")
          send("#{type}_in_#{$backup_cluster}")
        end
      end
    end
  end
end
