# encoding: utf-8

# Base class for archiving a ticket
module Archive
  module Core
    class Base

      ASSOCIATIONS_TO_SERIALIZE = {
        :helpdesk_tickets => [:flexifield, :ticket_old_body, :schema_less_ticket, :ticket_states, :mobihelp_ticket_info, :reminders, :subscriptions],
        :helpdesk_notes => [:survey_remark, :note_old_body, :schema_less_note, :external_note]
      }

      # :tag_uses => "taggable", :tags, :parent
      ASSOCIATIONS_TO_MODIFY = {
        :helpdesk_tickets => [:attachments => "attachable", :cloud_files => "droppable", :activities  => "notable", :survey_handles => "surveyable", :survey_results => "surveyable",
                              :support_scores => "scorable", :custom_survey_handles => "surveyable", :custom_survey_results => "surveyable", :time_sheets => "workable", :tweet => "tweetable",
                              :ticket_topic => "ticketable",:fb_post => "postable", :freshfone_call => "notable", :tag_uses => "taggable", :article_ticket => "ticketable",:integrated_resources => "local_integratable",
                              :inline_attachments => "attachable"],
        :helpdesk_notes => [:tweet => "tweetable", :fb_post => "postable", :freshfone_call => "notable", :attachments => "attachable", :cloud_files => "droppable", :shared_attachments => "shared_attachable" ,:inline_attachments => "attachable"]
      }

      def create_archive_ticket(ticket)
        ticket_model_hash = {}
        ticket_association_hash = {}
        # Generating model_hash for tickets
        ticket_model_hash[:helpdesk_tickets] = association_data_of_object(ticket)
        ASSOCIATIONS_TO_SERIALIZE[:helpdesk_tickets].each do |association_name|
          model_association = ticket.send(association_name)
          ticket_association_hash[association_name] = association_data_of_object(model_association) if model_association
        end
        ticket_model_hash[:helpdesk_tickets_association] = ticket_association_hash

        current_time = Time.now.utc
        archive_ticket = Helpdesk::ArchiveTicket.create(
          :subject => ticket.subject,
          :requester_id => ticket.requester_id,
          :responder_id => ticket.responder_id,
          :source => ticket.source,
          :status => ticket.status,
          :group_id => ticket.group_id,
          :priority => ticket.priority,
          :ticket_type => ticket.ticket_type,
          :display_id => ticket.display_id,
          :ticket_id => ticket.id,
          :archive_ticket_association_attributes => {
            :description => ticket.description,
            :association_data => ticket_model_hash,
            :description_html => ticket.description_html,
            :account_id => ticket.account_id
          },
          :created_at => ticket.created_at,
          :updated_at => ticket.updated_at,
          :archive_created_at => current_time,
          :archive_updated_at => current_time,
          :progress => true,
          :access_token => ticket.access_token
        )
      end

      def modify_archive_ticket_association(ticket,archive_ticket)
        modify_association(ticket,archive_ticket, "Helpdesk::ArchiveTicket",:helpdesk_tickets)
      end

      def create_archive_note(note,archive_ticket)
        note_model_hash = {}
        note_association_hash = {}
        # Generating model_hash for tickets
        note_model_hash[:helpdesk_tickets] = association_data_of_object(note)
        ASSOCIATIONS_TO_SERIALIZE[:helpdesk_notes].each do |association_name|
          model_association = note.send(association_name)
          note_association_hash[association_name] = association_data_of_object(model_association) if model_association
        end
        note_model_hash[:helpdesk_notes_association] = note_association_hash
        archive_note = ::Helpdesk::ArchiveNote.create(
          :user_id => note.user_id,
          :account_id => note.account_id,
          :archive_ticket_id => archive_ticket.id,
          :note_id => note.id,
          :notable_id => archive_ticket.ticket_id,
          :source => note.source,
          :incoming => note.incoming,
          :private => note.send(:private),
          :archive_note_association_attributes => {
            :body => note.body,
            :body_html => note.body_html,
            :associations_data => note_model_hash,
            :account_id => note.account_id,
          },
          :created_at => note.created_at,
          :updated_at => note.updated_at
        )
      end

      def modify_archive_note_association(note,archive_note)
        modify_association(note,archive_note, "Helpdesk::ArchiveNote",:helpdesk_notes)
      end

      def delete_ticket(ticket,archive_ticket)
        ticket.archive = true
        ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY, 
                                  {:manual_publish => true})
        
        if ticket.destroy
          archive_ticket.progress = false
          archive_ticket.save
        end
      end

      def on_success(status,options)
        Sharding.select_shard_of(options["account_id"]) do
          acc = Account.find(options["account_id"])
          acc.make_current
          Archive::DeleteTicket.perform_async(options)
        end
      end

      private

      def association_data_of_object(data)
        if data.kind_of?(Array)
          Array(data).collect { |d| hash_data_of_object(d) }
        else
          hash_data_of_object(data)
        end
      end

      def hash_data_of_object(data)
        return data.attributes
      end

      def modify_association(responder,archive, polymorphic_type,symbol)
        ASSOCIATIONS_TO_MODIFY[symbol].each do |association|
          association.each do |key,value|
            model_association = responder.send(key)
            polymorphic_type = modify_inline_attachments(symbol) if (key.to_sym == :inline_attachments)
            unless model_association.blank?
              if model_association.is_a?(Array)
                model_association.each do |element|
                  element.send("#{value}_id=",archive.id)
                  element.send("#{value}_type=",polymorphic_type)
                  element.save
                end
              else
                model_association.send("#{value}_id=",archive.id)
                model_association.send("#{value}_type=",polymorphic_type)
                model_association.save
              end
            end
          end
        end
      end

      def modify_inline_attachments(symbol)
        polymorphic_type =  (symbol == :helpdesk_tickets) ? "ArchiveTicket::Inline" : "ArchiveNote::Inline"
      end
    end
  end
end
