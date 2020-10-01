module Spam::Core
  class Base

    ASSOCIATIONS_TO_SERIALIZE = {
      helpdesk_tickets: [:flexifield, :ticket_body, :schema_less_ticket, :ticket_states, :ticket_topic, :topic, :article_ticket, :article, :reminders, :subscriptions],
      :helpdesk_notes => [:survey_remark, :note_body, :schema_less_note, :external_note]
    }
    
    # :tag_uses => "taggable", :tags, :parent
    ASSOCIATIONS_TO_MODIFY = {
      :helpdesk_tickets => [:attachments => "attachable", :cloud_files => "droppable", :activities  => "notable", :survey_handles => "surveyable", :survey_results => "surveyable", :support_scores => "scorable", :time_sheets => "workable", :tweet => "tweetable", :fb_post => "postable"],
      :helpdesk_notes => [:tweet => "tweetable", :fb_post => "postable", :attachments => "attachable", :cloud_files => "droppable", :shared_attachments => "shared_attachable" ]
    }

    attr_accessor :model, :spam_model, :notes, :spam_note, :serialized_ticket_data, :serialized_note_data

    # intializing intial object
    # accepts model type of ticket object
    def initialize(model)
      self.model = model
    end

    def perform
      # return if it is not a spam ticket
      # return unless self.model.spam
      # serializing current model associations
      self.serialized_ticket_data, self.serialized_note_data = serialized_model_data
      # create a spam model
      build_spam_model_and_modify
      # delete the record mysql
      delete_from_mysql
    end

    def restore
      # restore tickets and notes
      restore_tickets_and_notes
      # delete from spam_tickets
      delete_spam_tickets      
    end

    def store_params
      # build new spam ticket
      
      # post to email create
    end

    private

    def restore_tickets_and_notes
      # restoring ticket
      ActiveRecord::Base.transaction do
        ticket_data = model.associations_data[:helpdesk_tickets]
        ["description","description_html"].each do |key|
          ticket_data.delete(key)
        end
        ticket_data[:ticket_body_attributes] = model.associations_data[:helpdesk_tickets_association][:ticket_body]
        ticket = Helpdesk::Ticket.new(ticket_data)
        ticket.spam = false
        ticket_associations_data = model.associations_data[:helpdesk_tickets_association]
        ticket_associations_data.each do |key,value|
          next if key == :ticket_body
          if value.is_a?(Array)
            ticket.safe_send(key).build(value) unless value.blank?
          else
            ticket.safe_send("build_#{key}",value)
          end
        end
        ticket.save_ticket
        modify_association(model,ticket, "Helpdesk::Ticket",:helpdesk_tickets)
        spam_notes = model.spam_notes
        if spam_notes
          spam_notes.each do |note|
            note_data = note.associations_data[:helpdesk_notes]
            ["body","body_html"].each do |key|
              note_data.delete(key)
            end
            note_data[:note_body_attributes] = note.associations_data[:helpdesk_notes_association][:note_body]
            restored_note = ticket.notes.build(note_data)            
            note_associations_data = note.associations_data[:helpdesk_notes_association]
            note_associations_data.each do |key,value|
              next if key == :note_body
              restored_note.safe_send("build_#{key}",value)
              if value.is_a?(Array)
                restored_note.safe_send(key).build(value) unless value.blank?
              else
                restored_note.safe_send("build_#{key}",value)
              end
            end
            restored_note.save_note
            modify_association(note,restored_note, "Helpdesk::Note",:helpdesk_notes)
          end
        end
      end
    end

    def delete_spam_tickets
      spam_ticket = Helpdesk::SpamTicket.find_by_id(model.id)
      spam_ticket.destroy_spam_notes
      spam_ticket.destroy
    end

    def serialized_model_data
      ticket_model_hash = {}
      ticket_association_hash = {}
      note_model = []
      note_model_hash = {}
      # Generating model_hash for tickets
      ticket_model_hash[:helpdesk_tickets] = association_data_of_object(model)
      ASSOCIATIONS_TO_SERIALIZE[:helpdesk_tickets].each do |association_name| 
        model_association = model.safe_send(association_name)
        ticket_association_hash[association_name] = association_data_of_object(model_association) if model_association
      end
      ticket_model_hash[:helpdesk_tickets_association] = ticket_association_hash
      ticket_model = ticket_model_hash
      # Get all notes 
      self.notes = model.notes
      self.notes.each do |note|
        note_model_hash = {}
        note_model_hash[:helpdesk_notes] = association_data_of_object(note)
        note_model_hash[:helpdesk_notes_association] = {}
        ASSOCIATIONS_TO_SERIALIZE[:helpdesk_notes].each do |association_name| 
          model_association = note.safe_send(association_name)
          note_model_hash[:helpdesk_notes_association][association_name] = association_data_of_object(model_association) if model_association
        end
        note_model.push(note_model_hash)
      end
      [ticket_model,note_model]
    end

    def association_data_of_object(data)
      if data.kind_of?(Array)
        Array(data).collect { |d| hash_data_of_object(d) }
      else
        hash_data_of_object(data)
      end
    end

    def hash_data_of_object(data)
      data_attr = data.attributes
      return delete_custom_id(data,data_attr)      
    end

    def delete_custom_id(data,data_attr)
      data_attr.delete("display_id") if data.kind_of?(Helpdesk::Ticket)
      data_attr.delete("ticket_id")
      data_attr.delete("note_id")
      data_attr.delete("id")
      data_attr
    end

    def build_spam_model_and_modify
      ActiveRecord::Base.transaction do
        spam_ticket = Helpdesk::SpamTicket.create(:subject => model.subject, :description => model.description.to_s[0..65000], :requester_id => model.requester_id, :associations_data => self.serialized_ticket_data, :ticket_id => model.id)
        modify_association(model,spam_ticket, "Helpdesk::SpamTicket",:helpdesk_tickets)
        self.notes.each_with_index do |note,index|          
          spam_note = Helpdesk::SpamNote.create(:body => note.body.to_s[0..65000], :user_id => note.user_id, :spam_ticket_id => spam_ticket.id, :associations_data => self.serialized_note_data[index])
          modify_association(note,spam_note, "Helpdesk::SpamNote",:helpdesk_notes)
        end
      end
    end

    def delete_from_mysql
      ticket = Helpdesk::Ticket.find_by_id(model.id)
      ticket.destroy if ticket
    end

    def modify_association(responder,spam, polymorphic_type,symbol)
      ASSOCIATIONS_TO_MODIFY[symbol].each do |association|
        association.each do |key,value|
          model_association = responder.safe_send(key)
          unless model_association.blank?
            if model_association.is_a?(Array)
              model_association.each do |element|
                element.safe_send("#{value}_id=",spam.id)
                element.safe_send("#{value}_type=",polymorphic_type)
                element.save
              end
            else
              model_association.safe_send("#{value}_id=",spam.id)
              model_association.safe_send("#{value}_type=",polymorphic_type)
              model_association.save
            end
          end
        end
      end
    end

    def modify_data_of_object(model_association,polymorphic_name,poly_type)
      if model_association.is_a?(Array)
        model_association.each do |ass_name|
          ass_name.update_attributes({"#{polymorphic_name}_id" => self.spam_model.id, "#{polymorphic_name}_type" => poly_type})
        end
      else
        model_association.update_attributes({"#{polymorphic_name}_id" => self.spam_model.id, "#{polymorphic_name}_type" => poly_type})
      end
    end

  end
end
