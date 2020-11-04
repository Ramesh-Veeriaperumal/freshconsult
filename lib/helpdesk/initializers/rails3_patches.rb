# https://github.com/rails/rails/pull/15106 Fix for transactional callbacks to execute in same order
module ActiveRecord
  module Transactions
    extend ActiveSupport::Concern

    module ClassMethods
      def after_commit(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          options[:if] = ["transaction_include_action?(:#{options[:on]})"].concat(Array.wrap(options[:if]))
        end
        options[:prepend] = true if options.is_a?(Hash)
        args << { prepend: true } unless options.is_a?(Hash)
        set_callback(:commit, :after, *args, &block)
      end

      # This callback is called after a create, update, or destroy are rolled back.
      #
      # Please check the documentation of +after_commit+ for options.
      def after_rollback(*args, &block)
        options = args.last
        if options.is_a?(Hash) && options[:on]
          options[:if] = ["transaction_include_action?(:#{options[:on]})"].concat(Array.wrap(options[:if]))
        end
        options[:prepend] = true if options.is_a?(Hash)
        args << { prepend: true } unless options.is_a?(Hash)
        set_callback(:rollback, :after, *args, &block)
      end
    end
  end
end

# Patch for Reconnect not releasing connection. - https://github.com/rails/rails/pull/18417
# Fix is a workaround to achieve the equivalent of Rails 4.2 patch - https://github.com/rails/rails/commit/1997f7bf0e5c0bfbf2245c6d795271fc502e2b33
module ActiveRecord
  module ConnectionAdapters
    class Mysql2Adapter
      def reconnect!
        begin
          disconnect!
          connect
        rescue
          @in_use = false
          raise
        end
      end
    end

    class ConnectionPool
      def checkout_and_verify(c)
          c.run_callbacks :checkout do
            c.verify!
          end
          c
        rescue
          # checkin(c) should be sufficient but it is throwing error in Rails 3.2 for stale connection objects so working around to get the equivalent actions.
          release c
          c.disconnect!
          raise
      end
    end
  end
end

# Monitor the logs and then take a call to gohead with the fix.
# Fix link from Rails 4.1+ : https://github.com/rails/rails/pull/12779
# FD side problem noticed during Multi-AZ db failures. More details on - https://jira.freshworks.com/browse/FD-13418

module ActiveRecord
  module ConnectionAdapters
    class AbstractMysqlAdapter
      def begin_db_transaction
        execute 'BEGIN'
      rescue StandardError => e
        log_exception_skip('BEGIN')
        raise e if ENV['RAISE_TRANSACTION_ERROR'] == 'true'
      end

      def commit_db_transaction #:nodoc:
        execute 'COMMIT'
      rescue StandardError => e
        log_exception_skip('COMMIT')
        raise e if ENV['RAISE_TRANSACTION_ERROR'] == 'true'
      end

      def rollback_db_transaction #:nodoc:
        execute 'ROLLBACK'
      rescue StandardError => e
        log_exception_skip('ROLLBACK')
        raise e if ENV['RAISE_TRANSACTION_ERROR'] == 'true'
      end

      def log_exception_skip(action)
        if defined?(Rails.logger.info)
          Rails.logger.info("AR TRANSACTION ERROR SKIPPED :: #{action} :: #{Thread.current[:message_uuid].inspect}")
        end
      end
    end
  end
end

# Monkey Patch AR Update method to include account_id for tables that have account_id column.
# Raw method override of - https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/persistence.rb#L354
module ActiveRecord
  module Persistence
    def update(attribute_names = @attributes.keys)
      attributes_with_values = arel_attributes_values(false, false, attribute_names)
      return 0 if attributes_with_values.empty?
      klass = self.class
      stmt = nil
      if account_id_column_exists?
        stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id)).where(klass.arel_table["account_id"].eq(account_id)).arel.compile_update(attributes_with_values)
      else
        stmt = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id)).arel.compile_update(attributes_with_values)
      end
      klass.connection.update stmt
    end

    # MonekyPatch :
    # https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/persistence.rb#L320
    # https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/persistence.rb#L192
    # to include account_id in where conditions for tables that has account_id column.
    # We cannot override https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/relation.rb#L275
    # because relations are meant for bulk updates and it can have multiple touch points in the Framework like Migration, rake tasks, unit tests etc.

    # MonkeyPatch :
    # https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/persistence.rb#L117
    # https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/persistence.rb#L128
    # to include account_id in where conditions for tables that has account_id column.

    def destroy
      destroy_associations

      if persisted?
        IdentityMap.remove(self) if IdentityMap.enabled?
        pk         = self.class.primary_key
        column     = self.class.columns_hash[pk]
        substitute = connection.substitute_at(column, 0)
        if account_id_column_exists?
          relation = self.class.unscoped.where(self.class.arel_table[pk].eq(substitute)).where(self.class.arel_table["account_id"].eq(account_id))
        else
          relation = self.class.unscoped.where(self.class.arel_table[pk].eq(substitute))
        end
        relation.bind_values = [[column, id]]
        relation.delete_all
      end

      @destroyed = true
      freeze
    end

    def delete
      if persisted?
        if account_id_column_exists?
          relation = self.class.unscoped.where(self.class.arel_table[self.class.primary_key].eq(id)).where(self.class.arel_table["account_id"].eq(account_id))
        else
          relation = self.class.unscoped.where(self.class.arel_table[self.class.primary_key].eq(id))
        end
        IdentityMap.remove_by_id(self.symbolized_base_class, self.class.primary_key ) if IdentityMap.enabled?
        IdentityMap.remove(self) if IdentityMap.enabled?
        relation.delete_all
      end

      @destroyed = true
      freeze
    end

    def touch(name = nil)
      attributes = timestamp_attributes_for_update_in_model
      attributes << name if name

      unless attributes.empty?
        current_time = current_time_from_proper_timezone
        changes = {}

        attributes.each do |column|
          changes[column.to_s] = write_attribute(column.to_s, current_time)
        end

        changes[self.class.locking_column] = increment_lock if locking_enabled?

        @changed_attributes.except!(*changes.keys)
        primary_key = self.class.primary_key

        if account_id_column_exists?
          self.class.unscoped.where(primary_key => self[primary_key], 'account_id' => self['account_id']).update_all(changes) == 1
        else
          self.class.unscoped.where(primary_key => self[primary_key]).update_all(changes) == 1
        end
      end
    end

    def update_column(name, value)
      name = name.to_s
      raise ActiveRecordError, "#{name} is marked as readonly" if self.class.readonly_attributes.include?(name)
      raise ActiveRecordError, "can not update on a new record object" unless persisted?

      updated_count = nil
      if account_id_column_exists?
        updated_count = self.class.unscoped.where(self.class.primary_key => id, 'account_id' => self['account_id']).update_all(name => value)
      else
        updated_count = self.class.unscoped.where(self.class.primary_key => id).update_all(name => value)
      end

      raw_write_attribute(name, value)

      updated_count == 1
    end

    def account_id_column_exists?
      self.class.column_names.include? "account_id"
    end
  end
end

# To prevent queries meant for replica from going to primary
# Need to check this when we upgrade active_record_shards gem
# Change - disallow_replica is an instance variable(@disallow_slave in older versions, and @disallow_replica in latest versions) in gem
#   Since on_cx_switch_block is used as a class method, this causes an issue in multi-threaded environments like Sidekiq, Shoryuken

module ActiveRecordShards
  module ConnectionSwitcher
    def on_cx_switch_block(which, options = {}, &block)
      old_options = current_shard_selection.options
      switch_to_replica = (which == :slave && disallow_replica.zero?)
      switch_connection(slave: switch_to_replica)

      self.disallow_replica += 1 if which == :master

      # we avoid_readonly_scope to prevent some stack overflow problems, like when
      # .columns calls .with_scope which calls .columns and onward, endlessly.
      if self == ActiveRecord::Base || !switch_to_replica || options[:construct_ro_scope] == false
        yield
      else
        readonly.scoping(&block)
      end
    ensure
      self.disallow_replica -= 1 if which == :master
      switch_connection(old_options)
    end

    def disallow_replica
      Thread.current[:disallow_replica] ||= 0
    end

    def disallow_replica=(value)
      Thread.current[:disallow_replica] = value
    end
  end
end

#https://github.com/rails/rails/issues/3205, showing exception trace for transacational callbacks
module Foo
  module CommittedWithExceptions
    def committed!
      super
    rescue Exception => e # same as active_record/connection_adapters/abstract/database_statements.rb:370
      logger.error e.message + "\n " + e.backtrace.join("\n ")
      raise
    end
  end
end
 
ActiveRecord::Base.send(:include, Foo::CommittedWithExceptions)

# for rails 3 rendering a hidden input tag with nil value to update the attr, if no input is given
module ActionView
  module Helpers
    def feature_check_box(model_name, method, options = {}, checked_value = "1", unchecked_value = "0")
      check_box(model_name, "features_#{method}", options, checked_value, unchecked_value)
    end

    module FormHelper
      def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        InstanceTag.new(object_name, method, self, 
                        options.delete(:object)).to_check_box_tag(options, checked_value.to_s, unchecked_value.to_s)
      end
    end

    class InstanceTag
      def select_content_tag(option_tags, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        select = content_tag("select", add_options(option_tags, options, value(object)), html_options)
        select
      end
    end
  end
end

# In Rails 3. submit button we are not getting id.This method is for QA Automation
module ActionView
  module Helpers
    class FormBuilder
      def submit(value=nil, options={})
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.submit_tag(value, options.reverse_merge(:id => "#{object_name}_submit"))
      end

      def feature_check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        model_name = @object_name
        account = @template.instance_variable_get("@#{model_name}")
        throw "feature_check_box only work on models with features" unless account.respond_to?(:features)
        if AccountSettings::SettingsConfig[method].present? && options[:checked].nil?
          options[:checked] = account.safe_send("#{method}_enabled?")
        elsif options[:checked].nil?
          options[:checked] = account.features.safe_send("#{method}?")
        end
        options[:id] ||= "#{model_name}_features_#{method}"
        options[:name] = "#{model_name}[features][#{method}]"
        @template.feature_check_box(@object_name, method, objectify_options(options), checked_value, unchecked_value)
      end
    end
  end
end

ActiveModel::Errors.class_eval do
  def fd_json(options=nil)
    a = []
    to_hash.map do |key, values|
      values.each do |val|
        a << [key.to_s, val]
      end
    end
    a.to_json
  end
end

#https://github.com/rack/rack/issues/718. 
#Issue got fixed in rack 1.5.2 but sctionpack is depended on that so we can't upgrade
#So, monkey patching the same thing
module Rack
  module Multipart
    class Parser
      def get_filename(head)
        filename = nil
        case head
        when Rack::Multipart::RFC2183
          filename = Hash[head.scan(Rack::Multipart::DISPPARM)]['filename']
          filename = $1 if filename and filename =~ /^"(.*)"$/
        when Rack::Multipart::BROKEN_QUOTED, Rack::Multipart::BROKEN_UNQUOTED
          filename = $1
        end

        return unless filename

        if filename.scan(/%.?.?/).all? { |s| s =~ /%[0-9a-fA-F]{2}/ }
          filename = Rack::Utils.unescape(filename)
        end

        scrub_filename filename

        if filename !~ /\\[^\\"]/
          filename = filename.gsub(/\\(.)/, '\1')
        end
        filename
      end

      if "<3".respond_to? :valid_encoding?
        def scrub_filename(filename)
          unless filename.valid_encoding?
            # FIXME: this force_encoding is for Ruby 2.0 and 1.9 support.
            # We can remove it after they are dropped
            filename.force_encoding(Encoding::ASCII_8BIT)
            filename.encode!(:invalid => :replace, :undef => :replace)
          end
        end
      else
        def scrub_filename(filename)
        end
      end

    end
  end
end


#https://github.com/rails/rails/pull/17978
# Fix for append_info_to_payload not getting called during exception 
module ActionController
  module Instrumentation
    def process_action(*args)
      raw_payload = {
        :controller => self.class.name,
        :action     => self.action_name,
        :params     => request.filtered_parameters,
        :format     => request.format.try(:ref),
        :method     => request.request_method,
        :path       => (request.fullpath rescue "unknown")
      }

      ActiveSupport::Notifications.instrument("start_processing.action_controller", raw_payload.dup)

      ActiveSupport::Notifications.instrument("process_action.action_controller", raw_payload) do |payload|
        begin
          result = super
          payload[:status] = response.status
          result
        ensure
          append_info_to_payload(payload)
        end
      end
    end
  end
end

# http://jira.freshworks.com/browse/INFRA-678
# https://github.com/rails/rails/issues/1525#issuecomment-1724316
module AbstractController
  module Rendering

    module Antifreeze
      def inspect
        @view_renderer.lookup_context.find_all(@_request[:action], @_request[:controller]).inspect
      end
    end

    def view_context
      context = view_context_class.new(view_renderer, view_assigns, self)
      context.extend Antifreeze
      context
    end

  end
end

# Overwriting ActionDispatch::Request#reset_session to track all session
# resets happening along with its callers.
#
#   rails/actionpack/lib/action_dispatch/http/request.rb#215
#
#     def reset_session
#       session.destroy if session && session.respond_to?(:destroy)
#       self.session = {}
#       @env['action_dispatch.request.flash_hash'] = nil
#     end
#
# Extending for the sole purpose of tracking and will be removed once done
module ActionDispatch
  class Request
    def reset_session
      Rails.logger.info "Session reset called from :: #{caller_stack(12).inspect}"
      if session && session.respond_to?(:destroy)
        Rails.logger.info "Session reset called for :: #{session.inspect}"
        session.destroy
        Rails.logger.info "Session destroyed :: #{session.inspect}"
      end
      self.session = {}
      @env['action_dispatch.request.flash_hash'] = nil
    end

    private

      def caller_stack(num)
        (2..num).to_a.map { |i| caller[i] }
      end
  end
end
#security patch FD-30709
ActionDispatch::Request.prepend(Module.new do
  def formats
    super().select do |format|
      format.symbol || format.ref == '*/*'
    end
  end
end)

[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    def to_json(options = {})
      Oj.dump(self.as_json(options), mode: :compat)
    end
  end
end
