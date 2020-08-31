# encoding: utf-8

# Base class for archiving a ticket
module Archive
  module Core
    class Base
      include Publisher

      # Renaming ticket_old_body to ticket_body. Need to handle this while restoring ticket.
      ASSOCIATIONS_TO_SERIALIZE = {
        helpdesk_tickets: [:flexifield, :ticket_body, :schema_less_ticket, :ticket_states, :reminders, :subscriptions,
                           :bot_ticket, :canned_form_handles],
        # helpdesk_notes: [:survey_remark, :note_body, :schema_less_note, :external_note]
      }.freeze

      # tag_uses: "taggable", :tags, :parent
      # removed custom_survey_results
      ASSOCIATIONS_TO_MODIFY = {
        helpdesk_tickets: ['helpdesk_attachments' => 'attachable', 'helpdesk_dropboxes' => 'droppable', 'helpdesk_activities' => 'notable', 'survey_results' => 'surveyable',
                           'support_scores' => 'scorable', 'helpdesk_time_sheets' => 'workable', 'social_tweets' => 'tweetable',
                           'ticket_topics' => 'ticketable', 'social_fb_posts' => 'postable', 'helpdesk_tag_uses' => 'taggable', 'article_tickets' => 'ticketable', 'integrated_resources' => 'local_integratable',
                           'inline_attachments' => 'attachable', 'helpdesk_notes' => 'notable', :cti_calls => 'recordable']
        # :helpdesk_notes => ["social_tweets" => "tweetable", "social_fb_posts" => "postable", "helpdesk_attachments" => "attachable", "helpdesk_dropboxes" => "droppable", "helpdesk_shared_attachments" => "shared_attachable" ,"inline_attachments" => "attachable", :cti_calls => "recordable"]
      }.freeze

      MODIFY_ASSOCIATIONS_TO_CENTRAL = {
        helpdesk_tickets: {
          helpdesk_time_sheets: { account_association: :time_sheets },
          article_tickets: { account_association: :article_tickets }
        }
      }.freeze

      RAW_MYSQL_TICKET_ASSOCIATION = ['helpdesk_ticket_bodies', 'helpdesk_schema_less_tickets', 'helpdesk_ticket_states', 'mobihelp_ticket_infos',
                                      'helpdesk_reminders', 'helpdesk_subscriptions', 'bot_responses', 'bot_tickets', 'canned_form_handles'].freeze
      RAW_MYSQL_TICKET_POLYMORPHIC_ASSOCIATION = {
        'flexifields' => 'flexifield_set'
      }.freeze
      RAW_MYSQL_NOTE_ASSOCIATION = [].freeze # ["survey_remarks", "helpdesk_note_bodies","helpdesk_schema_less_notes","helpdesk_external_notes"]

      # create archive ticket
      # expects ticket object as input
      # returns archive_ticket
      def create_archive_ticket(ticket)
        current_time = Time.now.utc
        Helpdesk::ArchiveTicket.create(
          subject: ticket.subject,
          requester_id: ticket.requester_id,
          responder_id: ticket.responder_id,
          source: ticket.source,
          status: ticket.status,
          group_id: ticket.group_id,
          priority: ticket.priority,
          ticket_type: ticket.ticket_type,
          display_id: ticket.display_id,
          ticket_id: ticket.id,
          created_at: ticket.created_at,
          updated_at: ticket.updated_at,
          archive_created_at: current_time,
          archive_updated_at: current_time,
          progress: true,
          access_token: ticket.access_token,
          owner_id: ticket.owner_id, # ticket's company_id,
          product_id: ticket.product_id
        )
      end

      # create archive ticket body in s3
      # expects archive_ticket and ticket object as input
      # returns archive_ticket
      def create_archive_ticket_body(archive_ticket, ticket)
        Sharding.run_on_slave do
          ticket_model_hash = {}
          ticket_association_hash = {}
          # Generating model_hash for tickets
          ticket_model_hash[:helpdesk_tickets] = association_data_of_object(ticket)
          ASSOCIATIONS_TO_SERIALIZE[:helpdesk_tickets].each do |association_name|
            model_association = ticket.safe_send(association_name)
            ticket_association_hash[association_name] = association_data_of_object(model_association) if model_association
          end
          ticket_model_hash[:helpdesk_tickets_association] = ticket_association_hash
          archive_ticket.archive_ticket_association_attributes = {
            description: ticket.description,
            association_data: ticket_model_hash,
            description_html: ticket.description_html,
            account_id: ticket.account_id,
            subject: ticket.subject,
            requester_id: ticket.requester_id,
            responder_id: ticket.responder_id,
            source: ticket.source,
            status: ticket.status,
            group_id: ticket.group_id,
            priority: ticket.priority,
            ticket_type: ticket.ticket_type,
            display_id: ticket.display_id,
            ticket_id: ticket.id,
            created_at: ticket.created_at,
            updated_at: ticket.updated_at,
            archive_created_at: archive_ticket.archive_created_at,
            archive_updated_at: archive_ticket.archive_updated_at,
            access_token: ticket.access_token,
            owner_id: ticket.owner_id
          }
          args = {
            :data => archive_ticket.archive_ticket_content,
            :key_id => archive_ticket.id,
            :account_id => archive_ticket.account_id
          }
          bucket = S3_CONFIG[:archive_ticket_body]
          Helpdesk::S3::ArchiveTicket::Body.push_to_s3(args,bucket)
          archive_ticket
        end
      end

      # modify ticket association
      # expects ticket and archive_ticket as inputs
      def modify_archive_ticket_association(ticket, archive_ticket)
        modify_association(ticket, archive_ticket, 'Helpdesk::Ticket', 'Helpdesk::ArchiveTicket', :helpdesk_tickets)
      end

      # create archive note
      # expects note and archive_ticket as input
      # returns archive_note
      def create_archive_note(note, archive_ticket)
        ::Helpdesk::ArchiveNote.create(
          user_id: note.user_id,
          account_id: note.account_id,
          archive_ticket_id: archive_ticket.id,
          note_id: note.id,
          notable_id: archive_ticket.ticket_id,
          source: note.source,
          incoming: note.incoming,
          private: note.safe_send(:private),
          created_at: note.created_at,
          updated_at: note.updated_at,
          deleted:  note.deleted
        )
      end

      # creates archvie note body in s3
      # expects note, archive_note and archive_ticket
      def create_note_body_association(note, archive_note, archive_ticket)
        Sharding.run_on_slave do
          note_model_hash = {}
          note_association_hash = {}
          # Generating model_hash for tickets
          note_model_hash[:helpdesk_tickets] = association_data_of_object(note)
          ASSOCIATIONS_TO_SERIALIZE[:helpdesk_notes].each do |association_name|
            model_association = note.safe_send(association_name)
            note_association_hash[association_name] = association_data_of_object(model_association) if model_association
          end
          note_model_hash[:helpdesk_notes_association] = note_association_hash
          archive_note.archive_note_association_attributes = {
            body: note.body,
            body_html: note.body_html,
            associations_data: note_model_hash,
            account_id: note.account_id,
            user_id: note.user_id,
            archive_ticket_id: archive_ticket.id,
            note_id: note.id,
            notable_id: archive_ticket.ticket_id,
            source: note.source,
            incoming: note.incoming,
            private: note.safe_send(:private),
            created_at: note.created_at,
            updated_at: note.updated_at
          }
          args = {
            data: archive_note.archive_note_content,
            key_id: archive_note.id,
            account_id: archive_note.account_id
          }
          bucket = S3_CONFIG[:archive_note_body]
          Helpdesk::S3::ArchiveNote::Body.push_to_s3(args, bucket)
          archive_note
        end
      end

      # modify archive_note
      # expects archvie_note
      def modify_archive_note_association(note, archive_note)
        modify_association(note, archive_note, 'Helpdesk::Note', 'Helpdesk::ArchiveNote', :helpdesk_notes)
      end

      def delete_ticket(ticket, archive_ticket)
        ticket.archive = true
        ticket.misc_changes = { archive: [false, true] }
        key = RabbitMq::Constants::RMQ_GENERIC_TICKET_KEY
        ticket.count_es_manual_publish('destroy') if Account.current.count_es_writes_enabled? # for count es, its a delete action and we ll remove document from count cluster.
        ticket.save_deleted_ticket_info(true)
        ticket.manual_publish(['update', key, { manual_publish: true }], [:destroy, nil], true)
        if mysql_ticket_delete(ticket.id, ticket.account_id, archive_ticket)
          Helpdesk::ArchiveTicket.where(id: archive_ticket.id, account_id: archive_ticket.account_id, progress: true)
                                 .update_all(progress: false)
        end
      end

      private

        def mysql_ticket_delete(ticket_id, account_id, archive_ticket)
          ActiveRecord::Base.connection.execute("delete from helpdesk_tickets where id=#{ticket_id} and account_id=#{account_id}")
          delete_tickets_association(ticket_id, account_id, archive_ticket)
          true
        end

        def mysql_note_delete(ticket_id, account_id)
          # select helpdesk_notes
          note_ids = ActiveRecord::Base.connection.select_values("select id from helpdesk_notes where notable_id=#{ticket_id} and notable_type='Helpdesk::Ticket' and account_id=#{account_id}")
          # delete dependent notes
          unless note_ids.empty?
            delete_notes_association(note_ids, account_id)
            ActiveRecord::Base.connection.execute("delete from helpdesk_notes where id in (#{note_ids.join(',')}) and account_id=#{account_id}")
          end
        end

        def delete_tickets_association(ticket_id, account_id, archive_ticket)
          RAW_MYSQL_TICKET_ASSOCIATION.each do |table_name|
            ActiveRecord::Base.connection.execute("delete from #{table_name} where account_id=#{account_id} and ticket_id=#{ticket_id}")
          end
          RAW_MYSQL_TICKET_POLYMORPHIC_ASSOCIATION.each do |table_name, association_name|
            ActiveRecord::Base.connection.execute("delete from #{table_name} where account_id=#{account_id} and #{association_name}_id=#{ticket_id} and #{association_name}_type = 'Helpdesk::Ticket'")
          end
          delete_denorm_ff_record(archive_ticket)
          # mysql_note_delete(ticket_id, account_id)
        end

        def delete_notes_association(note_ids, account_id)
          RAW_MYSQL_NOTE_ASSOCIATION.each do |table_name|
            ActiveRecord::Base.connection.execute("delete from #{table_name} where account_id=#{account_id} and note_id in (#{note_ids.join(',')})")
          end
        end

        def delete_denorm_ff_record(archive_ticket)
          flexifield_id = archive_ticket.helpdesk_tickets_association['flexifield']['id'] if archive_ticket.helpdesk_tickets_association && archive_ticket.helpdesk_tickets_association['flexifield']
          ActiveRecord::Base.connection.execute("delete from denormalized_flexifields where account_id=#{archive_ticket.account_id} and flexifield_id=#{flexifield_id}") if flexifield_id
        end

        def association_data_of_object(data)
          if data.is_a?(Array)
            Array(data).collect { |d| hash_data_of_object(d) }
          else
            hash_data_of_object(data)
          end
        end

        def hash_data_of_object(data)
          data.attributes
        end

        def modify_association(responder, archive, from_polymorphic_type, to_polymorphic_type, symbol)
          poly_id = responder.id
          ASSOCIATIONS_TO_MODIFY[symbol].each do |association|
            association.each do |key, value|
              if key.to_sym == :inline_attachments
                attach_from_polymorphic_type = symbol == :helpdesk_tickets ? 'Ticket::Inline' : 'Note::Inline'
                attach_to_polymorphic_type = modify_inline_attachments(symbol)
                ids = ActiveRecord::Base.connection.select_values("select id from helpdesk_attachments where account_id=#{responder.account_id} and #{value}_id=#{poly_id} and #{value}_type= '#{attach_from_polymorphic_type}'")
                ActiveRecord::Base.connection.execute("update helpdesk_attachments set #{value}_id=#{archive.id}, #{value}_type='#{attach_to_polymorphic_type}' where id in (#{ids.join(',')}) and account_id=#{responder.account_id}") unless ids.empty?
              else
                ids = ActiveRecord::Base.connection.select_values("select id from #{key} where account_id=#{responder.account_id} and  #{value}_id=#{poly_id} and #{value}_type= '#{from_polymorphic_type}'")
                unless ids.empty?
                  key = key.to_sym
                  if MODIFY_ASSOCIATIONS_TO_CENTRAL[symbol].key?(key)
                    options = {
                      ids:            ids,
                      table_name:     symbol,
                      rel_table:      key,
                      rel_table_args: MODIFY_ASSOCIATIONS_TO_CENTRAL[symbol][key],
                      archive_ticket_id: archive.id
                    }
                    publish_to_central(options)
                  end
                  ActiveRecord::Base.connection.execute("update #{key} set #{value}_id=#{archive.id}, #{value}_type='#{to_polymorphic_type}' where id in (#{ids.join(',')}) and account_id=#{responder.account_id}")
                end

                if key.to_sym == :helpdesk_notes
                  SearchV2::IndexOperations::PostArchiveProcess.perform_async(
                    account_id: responder.account_id, archive_ticket_id: archive.id, ticket_id: poly_id, note_ids: ids
                  )
                end
              end
            end
          end
        end

        def modify_inline_attachments(symbol)
          symbol == :helpdesk_tickets ? 'ArchiveTicket::Inline' : 'ArchiveNote::Inline'
        end

        def helpdesk_time_sheets_publish_args(time_sheet, _options)
          [[], [:update, { archive_changes: { archive_ticket_id: [nil, time_sheet.archive_ticket_id], ticket_id: [time_sheet.ticket_id, nil] } }]]
        end

        def article_tickets_publish_args(article_ticket, _options)
          [[], [:update, { archive_changes: { ticketable_type: ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket'], ticketable_id: [article_ticket.ticketable_id, _options[:archive_ticket_id]] } }]]
        end
    end
  end
end
