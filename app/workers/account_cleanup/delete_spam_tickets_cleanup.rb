module AccountCleanup
  class DeleteSpamTicketsCleanup < BaseWorker

    sidekiq_options :queue => :delete_spam_tickets, :retry => 0, :failures => :exhausted
    APPLICATION_NAME = 'DeleteSpamTicketsCleanup'.freeze

    include AccountCleanup::Common
    include Publisher
    include Utils::Freno

    # :tag_uses => "taggable", :tags, :parent
    POLYMORPHIC_ASSOCATION = {
      :helpdesk_tickets => { :helpdesk_dropboxes => "droppable", :helpdesk_activities  => "notable", :survey_results => "surveyable",
                              :support_scores => "scorable", :helpdesk_time_sheets => "workable", :social_tweets => "tweetable",
                              :ticket_topics => "ticketable",:social_fb_posts => "postable", :helpdesk_tag_uses => "taggable", :article_tickets => "ticketable",:integrated_resources => "local_integratable",
                              :flexifields => "flexifield_set", :ebay_questions =>  "questionable"},
      :helpdesk_notes => {:social_tweets => "tweetable", :social_fb_posts => "postable", :helpdesk_dropboxes => "droppable", :helpdesk_shared_attachments => "shared_attachable", :ebay_questions => "questionable" }
    }.freeze

    POLYMORPHIC_ASSOCATION_TO_CENTRAL = {
      helpdesk_tickets: {
        helpdesk_time_sheets: {
          account_association:     :all_tickets_time_sheets,
          presenter_method:        :save_deleted_time_sheet_info,
          destroy:                 true
        }
      },
      helpdesk_notes: {}
    }.freeze
    
    # Having ticket_id or note_id column as foreign keys
    ASSOCIATIONS = {
      :helpdesk_tickets => [ "helpdesk_ticket_bodies", "helpdesk_schema_less_tickets", "helpdesk_ticket_states", "mobihelp_ticket_infos", "helpdesk_reminders", "helpdesk_subscriptions"],
      :helpdesk_notes => [ "survey_remarks", "helpdesk_note_bodies", "helpdesk_schema_less_notes", "helpdesk_external_notes" ]
    }.freeze

    ASSOCIATIONS_FOREIGN_KEY = {
      :helpdesk_tickets => "ticket_id",
      :helpdesk_notes => "note_id"
    }.freeze

    POLYMORPHIC_TYPE_VALUES = {
      :helpdesk_tickets => [ 'Helpdesk::Ticket', 'Ticket::Inline' ],
      :helpdesk_notes => [ 'Note::Inline', 'Helpdesk::Note' ]
    }.freeze

    NUMBER_OF_DAYS = 30 # Delete from db if it remains deleted or marked spam for this number of days

    def perform(args)
      begin
        time_taken = Benchmark.ms do
          @account_id = args['account_id']
          # Given an account ID, perform deletion of delete and spam tickets
          perform_delete_tickets
        end
        Rails.logger.debug "******************** #{time_taken} ******************************************************************"
      rescue Exception => e
        Rails.logger.debug "Error in DeleteSpamTicketsCleanup :: #{e.message}"
        NewRelic::Agent.notice_error(e, :description => "Unable to perform deletion of deleted and spam tickets. Arguments: #{args}")
      ensure 
        Account.reset_current_account
      end
    end

    def perform_delete_tickets(batch_size = 50)
      Sharding.admin_select_shard_of(@account_id) do
        execute_on_db do
          account = Account.find(@account_id)
          account.make_current

          shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
          delete_spam_days = account.account_additional_settings.delete_spam_tickets_days
          number_of_days = delete_spam_days ? delete_spam_days : NUMBER_OF_DAYS
          while true
            @ticket_ids = select_values('helpdesk_tickets', "updated_at < '#{number_of_days.days.ago}' and account_id = #{@account_id} and (deleted = true or spam = true) LIMIT #{batch_size}")
            break if @ticket_ids.size.zero?

            # Check for any replication lag detected by Freno for the current user's shard in DB.
            lag = get_replication_lag_for_shard(APPLICATION_NAME, shard_name, 5.seconds)
            lag > 0 ? rerun_after(lag, shard_name) && return : proceed_with_delete
          end
        end
      end
    end

    private

      def rerun_after(lag, shard_name)
        Rails.logger.debug("Warning: Freno: DeleteSpamTicketsCleanup: replication lag: #{lag} secs :: shard :: #{shard_name}")
        AccountCleanup::DeleteSpamTicketsCleanup.perform_in(lag.seconds.from_now, account_id: @account_id)
      end

      def proceed_with_delete
        @note_ids = select_values('helpdesk_notes', "account_id = #{@account_id} and notable_id in (#{@ticket_ids.join(',')}) and notable_type = 'Helpdesk::Ticket'")
        execute_on_db('run_on_master') do
          # To delete from S3 as well
          delete_attachments(@ticket_ids, POLYMORPHIC_TYPE_VALUES[:helpdesk_tickets])
          delete_attachments(@note_ids, POLYMORPHIC_TYPE_VALUES[:helpdesk_notes])

          perform_es_deletion

          delete_associated_data
          delete_polymorphic_association_data

          execute_delete('helpdesk_notes', @note_ids)
          execute_delete('helpdesk_tickets', @ticket_ids)
        end
      end

    # TODO: BATCH SIZE FOR THESE TWO TYPES OF DELETION ? 100 batch size
    def delete_associated_data
      ASSOCIATIONS.each do |table_name, related_tables|
        related_tables.each do |rel_table|
          key = ASSOCIATIONS_FOREIGN_KEY[table_name]
          ids = instance_variable_get('@' + key + 's')
          ids.in_groups_of(100, false).each do |ids_in_batch|
            condition = "account_id = #{@account_id} and #{key} in (#{ids_in_batch.join(',')})"
            associated_ids = select_values(rel_table, condition)
            execute_delete(rel_table, associated_ids)
          end
        end
      end
    end

    def delete_polymorphic_association_data
      POLYMORPHIC_ASSOCATION.each do |table_name, rel_tables|
        rel_tables.each do |rel_table, polymorphic|
          types = POLYMORPHIC_TYPE_VALUES[table_name]
          ids = instance_variable_get('@' + ASSOCIATIONS_FOREIGN_KEY[table_name] + 's') # ticket_ids, note_ids
          ids.in_groups_of(100, false).each do |ids_in_batch|
            condition = "account_id = #{@account_id} and #{polymorphic}_id in (#{ids_in_batch.join(',')}) and #{polymorphic}_type in ('#{types.join("','")}')"
            associated_ids = select_values(rel_table, condition)
            if POLYMORPHIC_ASSOCATION_TO_CENTRAL[table_name].key?(rel_table)
              options = {
                ids:            associated_ids,
                table_name:     table_name,
                rel_table:      rel_table,
                rel_table_args: POLYMORPHIC_ASSOCATION_TO_CENTRAL[table_name][rel_table]
              }
              publish_to_central(options)
            end
            execute_delete(rel_table, associated_ids)
          end
        end
      end
    end

    def delete_attachments(attachable_ids, attachable_type)
      if attachable_ids.size > 0
        clean_attachments(account_id: @account_id, attachable_ids: attachable_ids, attachable_type: attachable_type)
      end 
    end

    def execute_delete(table_name, ids)
      return if ids.size == 0
      delete_query = "delete from #{table_name} where id in (#{ids.join(',')}) and account_id = #{@account_id}"
      Rails.logger.debug delete_query
      ActiveRecord::Base.connection.execute(delete_query)
    end

    def select_values(table_name, condition)
      query = "select id from #{table_name} where #{condition}"
      puts query
      ids = ActiveRecord::Base.connection.select_values(query)
    end

    def perform_es_deletion
      manual_publish_subscribers(Helpdesk::Ticket, @ticket_ids)
    end

    def manual_publish_subscribers(klass, object_ids)
      Account.current.tickets.where(id: object_ids).find_in_batches(batch_size: 300) do |tickets|
        tickets.each do |t|
          t.save_deleted_ticket_info
          t.manual_publish(['destroy', RabbitMq::Constants::RMQ_GENERIC_TICKET_KEY, manual_publish: true], [:destroy, nil])
        end
      end
    end

      def helpdesk_time_sheets_publish_args(*)
        [[], [:destroy, nil]]
      end
  end
end
