require_relative '../../../test_helper'
module Ember
  module Contacts
    class MergeControllerTest < ActionController::TestCase
      include UsersTestHelper

      def setup
        super
        before_all
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run
        @account.features.multiple_user_companies.create
        @@before_all_run = true
      end

      def wrap_cname(params)
        { merge: params }
      end

      def test_merge_with_no_params
        post :merge, construct_params({version: 'private'}, {})
        assert_response 400
        match_json([bad_request_error_pattern(:primary_id, :missing_field),
                    bad_request_error_pattern(:target_ids, :missing_field)])
      end

      def test_merge_with_non_existing_contact
        post :merge, construct_params({version: 'private'}, {primary_id: (User.last.try(:id) || 0) + 10, target_ids: [1,2]})
        assert_response 404
      end

      def test_merge_with_invalid_target_ids
        primary_contact = add_new_user(@account)
        invalid_ids = [primary_contact.id + 10, primary_contact.id + 20]
        post :merge, construct_params({version: 'private'}, {primary_id: primary_contact.id, target_ids: invalid_ids})
        assert_response 400
        match_json([bad_request_error_pattern(:target_ids, :invalid_list, list: invalid_ids.join(', '))])
      end

      def test_merge_validation_failures
        primary_contact = add_new_user(@account)
        target_ids = []
        5.times do
          target_ids << add_new_user(@account).id
        end
        params_hash = { primary_id: primary_contact.id, target_ids: target_ids }
        post :merge, construct_params({version: 'private'}, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(:emails, :contact_merge_validation, max_value: 5, field: 'emails')])
      end

      def test_merge_with_errors
        primary_contact = add_new_user(@account)
        target_ids = []
        rand(2..4).times do
          target_ids << add_new_user(@account).id
        end
        params_hash = { primary_id: primary_contact.id, target_ids: target_ids }
        User.any_instance.stubs(:save).returns(false)
        post :merge, construct_params({version: 'private'}, params_hash)
        assert_response 500
        User.any_instance.unstub(:save)
      end

      def test_merge_success
        primary_contact = add_new_user(@account, customer_id: create_company.id)
        target_ids = []
        rand(2..4).times do
          target_ids << add_new_user(@account, customer_id: create_company.id).id
        end
        params_hash = { primary_id: primary_contact.id, target_ids: target_ids }
        post :merge, construct_params({version: 'private'}, params_hash)
        assert_response 204
        primary_contact.reload
        assert_equal target_ids.size + 1, primary_contact.user_emails.count
        assert_equal target_ids.size + 1, primary_contact.user_companies.count
        Account.current.all_contacts.where(id: target_ids).each { |x| assert x.deleted }
      end
    end
  end
end
