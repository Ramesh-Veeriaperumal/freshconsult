module Ember
  module Contacts
    class MergeController < ApiApplicationController
      include HelperConcern

      def merge
        @validation_klass = 'ContactMergeValidation'
        return unless validate_body_params
        sanitize_body_params
        return unless load_primary_contact
        @delegator_klass = 'ContactMergeDelegator'
        return unless validate_delegator(@item, scoper: scoper, target_ids: params[cname][:target_ids])
        return render_custom_errors unless merge_with_contacts(@delegator.target_users)
        MergeContacts.perform_async(parent: params[cname][:primary_id], children: params[cname][:target_ids])
        head 204
      end

      private

        def scoper
          current_account.contacts.preload(:user_companies, :user_emails)
        end

        def load_primary_contact
          @item = scoper.find_by_id(params[cname][:primary_id])
          log_and_render_404 unless @item
          @item
        end

        def merge_with_contacts(target_users)
          @source_company_ids = @item.user_companies.map(&:company_id)
          @target_company_ids = []
          target_users.each { |target| merge_with_contact(target) }
          @item.save
        end

        def merge_with_contact(target)
          merge_companies(target)
          target.mobile = '' if @item.mobile.eql? target.mobile
          target.phone = '' if @item.phone.eql? target.phone
          target.deleted = true
          target.user_emails.update_all_with_publish({  user_id: @item.id,
                                                        primary_role: false,
                                                        verified: @item.active? }, ['user_id != ?', @item.id])
          target.email = nil
          target.parent_id = @item.id
          target.save
        end

        def merge_companies(target)
          target.user_companies.each do |uc|
            next if @source_company_ids.include?(uc.company_id) || @target_company_ids.include?(uc.company_id)
            @item.user_companies.build(company_id: uc.company_id, client_manager: uc.client_manager,
                                       default: @source_company_ids.present? ? false : uc.default)
            @target_company_ids << uc.company_id
          end
        end

        def constants_class
          :ContactConstants.to_s.freeze
        end
    end
  end
end
