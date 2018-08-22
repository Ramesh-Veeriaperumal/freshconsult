module Ember
  module Search
    class SpotlightController < ApiApplicationController
      include ::Search::V2::AbstractController
      decorate_views(decorate_objects: [:results])

      around_filter :run_on_slave

      COLLECTION_RESPONSE_FOR = %w(results).freeze

      private

        def esv2_agent_models
          @@esv2_agent_spotlight ||= {
            'company'       => { model: 'Company',            associations: [] },
            'topic'         => { model: 'Topic',              associations: [{ forum: :forum_category }, :user] },
            'ticket'        => { model: 'Helpdesk::Ticket',   associations: [{ flexifield: :flexifield_def }, { requester: %i[avatar tags user_emails user_companies] }, { ticket_states: :tickets }, :ticket_old_body, :ticket_status, :company, :tags] },
            'archiveticket' => { model: 'Helpdesk::ArchiveTicket', associations: [{ requester: %i[avatar tags user_emails user_companies] }, :tags] },
            # TODO: When mulitlingual solutions are to be supported, the associations preloading has to be changed accordingly.
            'article'       => { model: 'Solution::Article',  associations: [:user, :article_body, :recent_author, { draft: :draft_body }, { solution_article_meta: { solution_category_meta: :"#{Language.for_current_account.to_key}_category" } }, { solution_folder_meta: [:customer_folders, :"#{Language.for_current_account.to_key}_folder"] }] },
            'user'          => { model: 'User',               associations: [:avatar, :customer, :default_user_company, :companies] }
          }
        end

        def esv2_portal_models
          @@esv2_portal_spotlight ||= {
            'ticket'        => { model: 'Helpdesk::Ticket',         associations: [:ticket_old_body, :group, :requester, :company] },
            'archiveticket' => { model: 'Helpdesk::ArchiveTicket',  associations: [] },
            'topic'         => { model: 'Topic',                    associations: [:forum] },
            'article'       => { model: 'Solution::Article',        associations: [:article_body, { solution_folder_meta: :solution_category_meta }] }
          }
        end

        def esv2_contact_merge_models
          @@esv2_contact_merge_models ||= {
            'user' => { model: 'User', associations: [{ account: :features }, :company, :user_emails] }
          }
        end

        def esv2_contact_search_models
          @@esv2_contact_search_models ||= {
            'user' => { model: 'User', associations: [{ account: :features }, :company, :user_emails] }
          }
        end

        def esv2_company_search_models
          @@esv2_company_search_models ||= {
            'company' => { model: 'Company', associations: [] }
          }
        end
    end
  end
end
