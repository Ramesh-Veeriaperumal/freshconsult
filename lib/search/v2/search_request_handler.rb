module Search
  module V2

    class SearchRequestHandler

      attr_accessor :types, :tenant

      def initialize(types=[], tenant_id)
        @types  = types
        @tenant = Tenant.fetch(tenant_id)
      end

      # Search for hits in ES and send response
      # To-do: Custom format required?
      #
      def fetch(search_term)
        Utils::EsClient.new(:get, search_path, construct_payload(search_term)).response
      end

      private

        # The path to direct search requests
        # Eg: http://localhost:9200/ticket_v1,user_v1/_search
        #
        def search_path
          [@tenant.aliases_path(@types), '_search'].join('/')
        end

        # Temporary for test
        # Will be using search templates for actual usecase
        # To-do: Remove after test
        #
        def construct_payload(search_term)
          {
            _source: false,
            size: 30,
            query: {
              multi_match: {
                query: search_term,
                fields: [ 'ticket.subject', 'ticket.description', 'ticket.to_emails', 'ticket.es_cc_emails', 
                          'ticket.es_fwd_emails', 'ticket.attachment_names', 'note.body', 'note.attachment_names',

                          'company.name', 'company.note', 'company.description', 'company.domains',

                          'user.name', 'user.emails', 'user.description', 'user.job_title', 'user.phone',
                          'user.mobile', 'user.company_name', 'user.twitter_id', 'user.fb_profile_id',

                          'topic.title', 'topic.posts.attachment_names', 'topic.posts.body',

                          'article.title', 'article.desc_un_html', 'article.tag_names', 'article.attachment_names'
                        ]
                }
              },
              highlight: {
                fields: {
                  name: {},
                  subject: {},
                  description: {},
                  subject: {},
                  description: {},
                  title: {},
                  desc_un_html: {},
                  title: {},
                  name: {},
                  job_title: {}
                },
                pre_tags: ['<span class="match">'],
                post_tags: ['</span>'],
                encoder: 'html',
                fragment_size: 80,
                number_of_fragments: 4
            }
          }.to_json
        end
    end

  end
end