module Search
  module V2

    class SearchRequestHandler

      attr_accessor :types, :tenant, :template_name

      def initialize(tenant_id, search_context, types=[])
        @tenant         = Tenant.fetch(tenant_id)
        @template_name  = Search::Utils::TEMPLATE_BY_CONTEXT[search_context]
        @types          = types
      end

      # Search for hits in ES and send response
      # To-do: Custom format required?
      #
      def fetch(search_params)
        Utils::EsClient.new(:get, 
                            (@template_name? template_query_path : search_path), 
                            construct_payload(search_params)
                          ).response
      end

      private

        # The path to direct search requests
        # Eg: http://localhost:9200/ticket_v1,user_v1/_search
        #
        def search_path
          [@tenant.aliases_path(@types), '_search'].join('/')
        end

        # The path to direct search requests using templates
        # Eg: http://localhost:9200/ticket_v1,user_v1/_search/template (w) payload
        #
        def template_query_path
          [@tenant.aliases_path(@types), '_search/template'].join('/')
        end

        # Temporary for test
        # Will be using search templates for actual usecase
        # To-do: Remove after test
        #
        def construct_payload(es_params)
          if @template_name
            {
              template: {
                file: @template_name
              },
              params: es_params
            }.to_json
          else
            # Still being used in agent side
            {
              _source: false,
              size: 30,
              query: {
                multi_match: {
                  query: es_params[:search_term],
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
                    title: {},
                    desc_un_html: {},
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
end