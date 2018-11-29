require_relative '../../../test_helper'
module Ember
  module Tickets
    class CollabControllerTest < ActionController::TestCase
      include ApiTicketsTestHelper

      def wrap_cname(params)
        { collab: params }
      end

      def test_notify
        check_enable_collab
        ticket = create_ticket
        params_hash = { body: 'Sample text', m_ts: 'Sample TS', m_type: '1', metadata: '{}', mid: '789798', token: '89678', top_members: '[]' }
        post :notify, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
        disable_collab
        assert_response 204
      end

      private

        def disable_collab
          @account.revoke_feature(:collaboration)
        end

        def check_enable_collab
          @account.add_feature(:collaboration)
          cset = Collab::Setting.find_by_account_id(@account.id)
          if cset.blank?
            cset = Collab::Setting.new
            cset.account_id = @account.id
            cset.key = ""
            @account.collab_settings = cset
            @account.collab_settings.save
          end
        end
    end
  end
end
