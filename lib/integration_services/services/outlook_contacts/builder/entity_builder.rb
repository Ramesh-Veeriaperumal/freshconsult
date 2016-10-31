module IntegrationServices::Services
  module OutlookContacts::Builder
    class EntityBuilder

      SEEK_COLS = %w[email mobile phone].freeze

      def initialize(formatter, sync_account)
        @sync_account = sync_account
        @formatter = formatter
      end

      def convert_to_fd_user(user_info, user_id=nil)
        hash = get_fd_user(user_info, user_id)
        user = hash[:user]
        return nil if user.blank?
        update_email_attribute = hash[:update_email_attribute]
        user_attrs = @formatter.map_outlook_to_fd_user_attributes(user_info)
        user = update_user_attributes(user, user_attrs, update_email_attribute)
        user.deleted = false if user.changed? && user.deleted?
        user
      end

      def seek_columns_absent?(user_info)
        seek_columns = get_seek_columns(user_info)
        columns_present = seek_columns.select{|k,v| v.present?}
        columns_present.keys.length == 0
      end

      private

        def get_fd_user(user_info, user_id=nil)
          user = nil
          seek_cols = get_seek_columns(user_info)
          update_email_attribute = true
          if user_id.present? # user already mapped
            user = find_user_by_id(user_id)
          else
            return {:user => nil} if seek_columns_absent?(user_info)
            if seek_cols[:email].present? #fetch user by email
              user = find_user_by_email(seek_cols[:email])
              # case when outlook contact has email and mobile/phone. contact with email present in freshdesk and mapped to some other outlook contact.
              if user.present? && user_already_mapped?(user.id)
                return {:user => nil} if email_alone_present?(user_info)
                user = nil
                update_email_attribute = false
              end
            end
            if user.blank? && seek_cols[:mobile].present? #fetch user by mobile
              user = find_user_by_mobile(seek_cols[:mobile], user_info)
            end
            if user.blank? && seek_cols[:phone].present? #fetch user by phone
              user = find_user_by_phone(seek_cols[:phone], user_info)
            end
            user = Account.current.users.new if user.blank?
          end
          return {:user => nil} if user.agent?
          {:user => user, :update_email_attribute => update_email_attribute}
        end

        def get_seek_columns(user_info)
          seek_columns = {}
          SEEK_COLS.each do |column|
            seek_columns[column.to_sym] = @formatter.send(column.to_sym, user_info)
          end
          seek_columns
        end

        def find_user_by_id(user_id)
          Account.current.all_users.find_by_id(user_id)
        end

        def find_user_by_email(email)
          Account.current.user_emails.user_for_email(email) unless email.blank?
        end

        def find_user_by_mobile(mobile, user_info)
          user = nil
          users = Account.current.users.where(:mobile => mobile)
          if users.present?
            non_linked_users = get_non_linked_users(users)
            phone = @formatter.phone(user_info)
            users_with_phone_matched = users.select{|user| phone.present? && user.phone == phone }
            user = users_with_phone_matched.length > 0 ? highest_priority_user(users_with_phone_matched) : highest_priority_user(non_linked_users)
          end
          user
        end

        def find_user_by_phone(phone, user_info)
          user = nil
          users = Account.current.users.where(:phone => phone)
          if users.present?
            non_linked_users = get_non_linked_users(users)
            user = highest_priority_user(non_linked_users)
          end
          user
        end

        def user_already_mapped?(user_id)
          existing_map = @sync_account.sync_entity_mappings.where(:user_id => user_id)
          existing_map.present?
        end

        def email_alone_present?(user_info)
          seek_columns = get_seek_columns(user_info)
          columns_present = seek_columns.select {|k, v| v.present?}
          columns_present.keys.length == 1 && columns_present.keys[0] == :email
        end

        def get_non_linked_users(users)
          user_ids = users.collect{|user| user.id}
          existing_map = @sync_account.sync_entity_mappings.where('user_id in (?)', user_ids)
          mapped_user_ids = existing_map.collect{|i| i.user_id}
          users.delete_if do |user|
            mapped_user_ids.include?(user.id)
          end
          users
        end

        def highest_priority_user(users)
          users.max{|user1, user2| user1[:updated_at] <=> user2[:updated_at]}
        end

        def update_user_attributes(user, user_attrs, update_email_attribute)
          if user.exist_in_db?
            user = handle_existing_user(user, user_attrs, update_email_attribute)
          else
            user = handle_new_user(user, user_attrs, update_email_attribute)
          end
          user
        end

        def handle_existing_user(user, user_attrs, update_email_attribute)
          overwrite = @sync_account.overwrite_existing_user
          user_attrs.each do |attribute, value|
            next if SEEK_COLS.include?(attribute.to_s) && value.blank?
            if attribute.to_s == "email"
              next if !update_email_attribute
              user_emails = user.emails
              if user_emails.present?
                if !user_emails.include?(value) && user_emails.length < 5
                  user.user_emails.new(:email => value)
                end
              else
                user.send("#{attribute}=", value) #handle error if errors out
              end
            else
              if overwrite
                user.send("#{attribute}=", value)
              elsif user[attribute].blank?
                user.send("#{attribute}=", value)
              end
            end
          end
          user
        end

        def handle_new_user(user, user_attrs, update_email_attribute)
          user_attrs.each do |attribute, value|
            if attribute.to_s == "email"
              user.send("#{attribute}=", value) if update_email_attribute
            else
              user.send("#{attribute}=", value)
            end
          end
          user
        end

    end
  end
end
