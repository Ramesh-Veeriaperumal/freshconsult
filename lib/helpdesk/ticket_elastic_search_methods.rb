module Helpdesk::TicketElasticSearchMethods

  def self.included(base)
    base.class_eval do

      def es_flexifield_columns
        @@es_flexi_txt_cols ||= Flexifield.column_names.select {|v| v =~ /^ff(s|_text|_int|_decimal)/}
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

      #=> Methods for the count cluster
      def tag_names
        tags.map(&:name)
      end

      def tag_ids
        tags.map(&:id)
      end

      def watchers
        subscriptions.map(&:user_id)
      end

      def status_stop_sla_timer
        ticket_status.stop_sla_timer
      end

      def status_deleted
        ticket_status.deleted
      end

      def custom_attributes
        flexifield.as_json(root: false, only: Flexifield.column_names.select {|v| v =~ /^ffs_/})
      end
      #=> Till here

      def update_notes_es_index
        if !@model_changes[:deleted].nil? or !@model_changes[:spam].nil?
          delete_from_es_notes if (deleted? or spam?) 
          restore_es_notes if (!deleted? and !spam?)
        end
      end
       
      def delete_from_es_notes
        SearchSidekiq::Notes::DeleteNotesIndex.perform_async({ :ticket_id => id }) if ES_ENABLED
      end

      def restore_es_notes
        SearchSidekiq::Notes::RestoreNotesIndex.perform_async({ :ticket_id => id }) if ES_ENABLED
      end

    end
  end

end