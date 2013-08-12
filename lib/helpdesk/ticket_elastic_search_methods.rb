module Helpdesk::TicketElasticSearchMethods

  def self.included(base)
    base.class_eval do

      def es_flexifield_columns
        @@es_flexi_txt_cols ||= Flexifield.column_names.select {|v| v =~ /^ff(s|_text)/}
      end

      def es_from
        if source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:twitter]
          requester.twitter_id
        elsif source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook]
          requester.fb_profile_id
        else
          from_email
        end
      end

      def es_cc_emails
        cc_email_hash[:cc_emails] if cc_email_hash
      end

      def es_fwd_emails
        cc_email_hash[:fwd_emails] if cc_email_hash
      end

      def update_notes_es_index
        if !@model_changes[:deleted].nil? or !@model_changes[:spam].nil?
          delete_from_es_notes if (deleted? or spam?) 
          restore_es_notes if (!deleted? and !spam?)
        end
      end
       
      def delete_from_es_notes
        Resque.enqueue(Search::Notes::DeleteNotesIndex, { :ticket_id => id, 
                    :account_id => account_id}) if es_available? and ES_ENABLED
      end

      def restore_es_notes
        Resque.enqueue(Search::Notes::RestoreNotesIndex, { :ticket_id => id, 
                    :account_id => account_id}) if es_available? and ES_ENABLED
      end

    end
  end

end