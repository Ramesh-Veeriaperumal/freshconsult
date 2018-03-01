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
        attr_accessor :s3_create, :s3_delete, :s3_update
        after_create "create_#{class_name}_body"
        after_update "update_#{class_name}_body"
        after_destroy "destroy_#{class_name}_body"
        after_rollback "handle_rollback_for_riak"
        after_commit ->(obj) { obj.push_to_resque_create }, on: :create
        after_commit ->(obj) { obj.push_to_resque_update }, on: :update
        after_commit "push_to_resque_destroy", on: :destroy

        def create_#{class_name}_body
          self.rollback_#{class_name}_body = true
          created_at_updated_at_on_create
          datastore("create")
        end

        def update_#{class_name}_body
          if self.#{class_name}_body_content && self.#{class_name}_body_content.attributes_changed?
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
          safe_send(type+"_in_#{$primary_cluster}")
          safe_send(type+"_in_#{$secondary_cluster}")
          safe_send(type+"_in_#{$backup_cluster}")
        end
      end
    end
  end
end
