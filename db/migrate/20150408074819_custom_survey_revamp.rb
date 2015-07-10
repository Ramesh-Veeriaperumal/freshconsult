class CustomSurveyRevamp < ActiveRecord::Migration
  shard :all

  SHARD_AUTO_INCREMENT = {
    "shard_1" => 1,
    "shard_2" => 1000000000,
    "shard_3" => 2000000000,
    "shard_4" => 3000000000,
    "shard_5" => 4000000000,
    "shard_6" => 5000000000,
    "shard_7" => 6000000000
  }

  SurveyRatingToCustomSurveyRating = {
    Survey::HAPPY.to_s   => CustomSurvey::Survey::EXTREMELY_HAPPY.to_s,
    Survey::UNHAPPY.to_s => CustomSurvey::Survey::EXTREMELY_UNHAPPY.to_s,
    Survey::NEUTRAL.to_s => CustomSurvey::Survey::NEUTRAL.to_s
  }

  CustomSurveyRatingToSurveyRating = SurveyRatingToCustomSurveyRating.invert

  SurveyRatingToCustomSurveyRating.default = CustomSurveyRatingToSurveyRating.default = "--"

  def perform_predeployment_migration
    create_tables_in_production
    add_columns_to_surveys
    add_columns_to_survey_handles
    add_index_to_survey_result
  end

  def up   
    add_columns_to_surveys
    add_columns_to_survey_handles
    create_table_survey_questions
    create_table_survey_question_choices
    create_table_survey_result_data
    add_index_to_survey_result
    migrate_data
    # drop_columns_from_survey
    # drop_columns_from_survey_result
  end

  def down
    # revert_drop_columns_from_survey
    # revert_drop_columns_from_survey_result
    remove_index_from_survey_result
    revert_migrate_data
    revert_add_columns_to_surveys
    revert_add_columns_to_survey_handles  
    drop_table :survey_questions
    drop_table :survey_question_choices
    drop_table :survey_result_data    
  end

  private

    def create_tables_in_production 
      SHARD_AUTO_INCREMENT.each do |s_n,a_i|
        Sharding.run_on_shard(s_n) do

          ActiveRecord::Base.connection.execute(
            "CREATE TABLE `survey_questions` (
              `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
              `account_id` bigint(20) DEFAULT NULL,
              `survey_id` bigint(20) DEFAULT NULL,
              `name` text,
              `field_type` int(11) DEFAULT NULL,
              `position` int(11) DEFAULT NULL,
              `deleted` tinyint(1) DEFAULT '0',
              `label` text,
              `column_name` varchar(255) DEFAULT NULL,
              `default` tinyint(1) DEFAULT '0',
              `created_at` datetime NOT NULL,
              `updated_at` datetime NOT NULL,
              PRIMARY KEY (`id`),
              KEY `idx_cf_questions_on_account_id_and_survey_id_and_position` (`account_id`,`survey_id`,`position`)
            ) ENGINE=InnoDB AUTO_INCREMENT=#{a_i} DEFAULT CHARSET=utf8;"
          )

          ActiveRecord::Base.connection.execute(
            "CREATE TABLE `survey_question_choices` (
              `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
              `account_id` bigint(20) unsigned DEFAULT NULL,
              `survey_question_id` bigint(20) unsigned DEFAULT NULL,
              `value` varchar(255) DEFAULT NULL,
              `face_value` int(11) DEFAULT NULL,
              `position` int(11) DEFAULT NULL,
              `created_at` datetime NOT NULL,
              `updated_at` datetime NOT NULL,
              PRIMARY KEY (`id`),
              KEY `idx_cf_choices_on_account_id_and_survey_question_id_and_position` (`account_id`,`survey_question_id`,`position`)
            ) ENGINE=InnoDB AUTO_INCREMENT=#{a_i} DEFAULT CHARSET=utf8;"
          )

          ActiveRecord::Base.connection.execute(
            "CREATE TABLE `survey_result_data` (
              `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
              `account_id` bigint(20) NOT NULL DEFAULT '0',
              `survey_id` bigint(20) DEFAULT NULL,
              `survey_result_id` bigint(20) DEFAULT NULL,
              `cf_int01` smallint(20) DEFAULT NULL,
              `cf_int02` smallint(20) DEFAULT NULL,
              `cf_int03` smallint(20) DEFAULT NULL,
              `cf_int04` smallint(20) DEFAULT NULL,
              `cf_int05` smallint(20) DEFAULT NULL,
              `cf_int06` smallint(20) DEFAULT NULL,
              `cf_int07` smallint(20) DEFAULT NULL,
              `cf_int08` smallint(20) DEFAULT NULL,
              `cf_int09` smallint(20) DEFAULT NULL,
              `cf_int10` smallint(20) DEFAULT NULL,
              `cf_int11` smallint(20) DEFAULT NULL,
              `cf_int12` smallint(20) DEFAULT NULL,
              `cf_int13` smallint(20) DEFAULT NULL,
              `cf_int14` smallint(20) DEFAULT NULL,
              `cf_int15` smallint(20) DEFAULT NULL,
              `cf_int16` smallint(20) DEFAULT NULL,
              `cf_int17` smallint(20) DEFAULT NULL,
              `cf_int18` smallint(20) DEFAULT NULL,
              `cf_int19` smallint(20) DEFAULT NULL,
              `cf_int20` smallint(20) DEFAULT NULL,
              `cf_int21` smallint(20) DEFAULT NULL,
              `cf_str01` varchar(255) DEFAULT NULL,
              `cf_str02` varchar(255) DEFAULT NULL,
              `cf_str03` varchar(255) DEFAULT NULL,
              `cf_str04` varchar(255) DEFAULT NULL,
              `cf_str05` varchar(255) DEFAULT NULL,
              `cf_str06` varchar(255) DEFAULT NULL,
              `cf_str07` varchar(255) DEFAULT NULL,
              `cf_str08` varchar(255) DEFAULT NULL,
              `cf_str09` varchar(255) DEFAULT NULL,
              `cf_str10` varchar(255) DEFAULT NULL,
              `cf_str11` varchar(255) DEFAULT NULL,
              `cf_str12` varchar(255) DEFAULT NULL,
              `cf_str13` varchar(255) DEFAULT NULL,
              `cf_str14` varchar(255) DEFAULT NULL,
              `cf_str15` varchar(255) DEFAULT NULL,
              `cf_str16` varchar(255) DEFAULT NULL,
              `cf_str17` varchar(255) DEFAULT NULL,
              `cf_str18` varchar(255) DEFAULT NULL,
              `cf_str19` varchar(255) DEFAULT NULL,
              `cf_str20` varchar(255) DEFAULT NULL,
              `cf_text01` text,
              `cf_text02` text,
              `cf_text03` text,
              `cf_text04` text,
              `cf_text05` text,
              `cf_text06` text,
              `cf_text07` text,
              `cf_text08` text,
              `cf_text09` text,
              `cf_text10` text,
              `cf_text11` text,
              `cf_text12` text,
              `cf_text13` text,
              `cf_text14` text,
              `cf_text15` text,
              `cf_text16` text,
              `cf_text17` text,
              `cf_text18` text,
              `cf_text19` text,
              `cf_text20` text,
              `created_at` datetime DEFAULT NULL,
              `updated_at` datetime DEFAULT NULL,
              PRIMARY KEY (`account_id`,`id`),
              KEY `index_survey_result_data_on_account_id_and_survey_result_id` (`account_id`,`survey_result_id`),
              KEY `index_survey_result_data_on_account_id_and_survey_id` (`account_id`,`survey_id`),
              KEY `index_survey_result_data_id` (`id`)
            ) ENGINE=InnoDB AUTO_INCREMENT=#{a_i} DEFAULT CHARSET=utf8
            /*!50100 PARTITION BY HASH (account_id)
            PARTITIONS 128 */;"
          )

        end
      end
    end

    def add_columns_to_surveys
      Lhm.change_table :surveys, :atomic_switch => true do |m|
        m.add_column :title_text, "varchar(255)"
        m.add_column :active, "tinyint"
        m.add_column :thanks_text, "text"
        m.add_column :feedback_response_text, "text"
        m.add_column :can_comment, "tinyint"
        m.add_column :default, "tinyint(1) DEFAULT 0"
        m.add_column :comments_text, "text"
      end
    end

    def add_columns_to_survey_handles
      Lhm.change_table :survey_handles, :atomic_switch => true do |m|
        m.add_column :preview, "boolean DEFAULT false"
        m.add_column :agent_id, "bigint unsigned"
        m.add_column :group_id, "bigint unsigned"

        m.add_index ["account_id", "id_token(20)"]
      end
    end

    def add_index_to_survey_result
      Lhm.change_table :survey_results, :atomic_switch => true do |m|
        m.add_index [:account_id, :survey_id]
      end
    end

    def migrate_data
      ShardMapping.find_in_batches(:batch_size => 300) do |shard_mappings|
        shard_mappings.each do |shard_mapping|
          Sharding.select_shard_of(shard_mapping.account_id) do
            account = Account.find shard_mapping.account_id
            account.make_current
            I18n.locale = account.language
            last_survey_result_id = {}
            account.survey_handles.each do |survey_handle|
              survey_handle.update_attributes({
                :agent_id => survey_handle.surveyable.responder_id,
                :group_id => survey_handle.surveyable.group_id
              })
            end
            account.surveys.each do |survey|
              survey.update_attributes({
                :title_text => I18n.t('admin.surveys.new_layout.default_survey'),
                :thanks_text => I18n.t('admin.surveys.new_thanks.thanks_feedback'),
                :feedback_response_text => I18n.t('admin.surveys.new_thanks.feedback_response_text'),
                :comments_text => I18n.t('admin.surveys.new_thanks.comments_feedback'),
                :active => (account.features?(:survey_links) ? true : false),
                :can_comment => true,
                :default => true
              })
              unhappy_text = survey.unhappy_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.unhappy') :  survey.unhappy_text
              neutral_text = survey.neutral_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.neutral') :  survey.neutral_text
              happy_text = survey.happy_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.happy') : survey.happy_text
              CustomSurvey::SurveyQuestion.create(
                :account_id => account.id,
                :name => 'default_survey_question',
                :label => survey.link_text,
                :column_name => "cf_int01",
                :position => 1,
                :survey_id => survey.id,
                :field_type => :custom_survey_radio,
                :default => true,
                :custom_field_choices_attributes => [
                  { :position => 1, :_destroy => 0, :value => unhappy_text, :face_value => CustomSurvey::Survey::EXTREMELY_UNHAPPY },
                  { :position => 2, :_destroy => 0, :value => neutral_text, :face_value => CustomSurvey::Survey::NEUTRAL },
                  { :position => 3, :_destroy => 0, :value => happy_text, :face_value => CustomSurvey::Survey::EXTREMELY_HAPPY }
                ]
              )
              survey.survey_results.each do |survey_result|
                update_results_and_create_result_data survey_result, survey, account
              end
              last_survey_result_id[survey.id] = survey.survey_results.last ? survey.survey_results.last.id : 0
            end
            account.all_observer_rules.each do |observer_rule|
              should_save = false
              observer_rule.filter_data[:events].each do |event|
                if event[:name] == "customer_feedback"
                  event[:value] = SurveyRatingToCustomSurveyRating[event[:value].to_s]
                  should_save = true
                end
              end
              observer_rule.save if should_save #to avoid unnecessay update_query due to serialized data columns
            end

            account.quests.each do |quest|
              should_save = false
              quest.filter_data[:actual_data].each do |actual_data|
                if actual_data[:name] == "st_survey_rating"
                  actual_data[:value] = SurveyRatingToCustomSurveyRating[actual_data[:value].to_s]
                  should_save = true
                end
              end
              quest.filter_data[:and_filters].each do |and_filter|
                if and_filter[:name] == "st_survey_rating" && SurveyRatingToCustomSurveyRating[and_filter[:value]] != SurveyRatingToCustomSurveyRating.default
                  and_filter[:value] = SurveyRatingToCustomSurveyRating[and_filter[:value].to_s]
                  should_save = true
                end
              end
              quest.save if should_save
            end

            account.features.custom_survey.create
            delta_timestamp = account.features.custom_survey.created_at
            account.surveys.each do |survey|
              survey.survey_results.where("id > #{last_survey_result_id[survey.id]} and created_at <= '#{delta_timestamp.to_s(:db)}'").each do |survey_result|
                update_results_and_create_result_data survey_result, survey, account
              end
            end
            account.email_notifications.create(
              :notification_type => EmailNotification::PREVIEW_EMAIL_VERIFICATION,
              :account_id => account.id,
              :requester_notification => false,
              :agent_notification => true,
              :agent_template => '<p>Hi agent,<br/><br/>This email is to give a preview of how customer satisfaction survey feedback is done.<br/><br/></p>',
              :agent_subject_template => '{{ticket.subject}}'
            )
          end
        end
      end
    end

    def update_results_and_create_result_data survey_result, survey, account
      rating = CustomSurvey::Survey::NEUTRAL
      if survey_result.rating == Survey::HAPPY
        rating = CustomSurvey::Survey::EXTREMELY_HAPPY
      elsif survey_result.rating == Survey::UNHAPPY
        rating = CustomSurvey::Survey::EXTREMELY_UNHAPPY
      end
      survey_result.update_attributes({
        :agent_id => survey_result.surveyable.responder_id,
        :group_id => survey_result.surveyable.group_id
      })
      CustomSurvey::SurveyResultData.create({
        :account_id => account.id,
        :survey_id => survey.id,
        :survey_result_id => survey_result.id,
        :cf_int01 => rating
      })
    end

    def drop_columns_from_survey
      Lhm.change_table :surveys, :atomic_switch => true do |m|
        m.remove_column :link_text
        m.remove_column :happy_text
        m.remove_column :neutral_text
        m.remove_column :unhappy_text
      end
    end
    
    def drop_columns_from_survey_result
      Lhm.change_table :survey_results, :atomic_switch => true do |m|
        m.remove_column :rating
      end
    end
    
    # methods to revert migration changes
    def revert_add_columns_to_surveys
      Lhm.change_table :surveys, :atomic_switch => true do |m|
        m.remove_column :title_text
        m.remove_column :active
        m.remove_column :thanks_text
        m.remove_column :feedback_response_text
        m.remove_column :can_comment
        m.remove_column :default
        m.remove_column :comments_text
      end
    end

    def revert_add_columns_to_survey_handles
      Lhm.change_table :survey_handles, :atomic_switch => true do |m|
        m.remove_column :preview
        m.remove_column :agent_id
        m.remove_column :group_id 

        m.remove_index ["account_id", "id_token(20)"]
      end
    end

    def revert_drop_columns_from_survey
      Lhm.change_table :surveys, :atomic_switch => true do |m|
        m.add_column :link_text, "varchar(255)" 
        m.add_column :happy_text, "varchar(255)"
        m.add_column :neutral_text, "varchar(255)"
        m.add_column :unhappy_text, "varchar(255)"
      end
    end

    def revert_drop_columns_from_survey_result
      Lhm.change_table :survey_results, :atomic_switch => true do |m|
        m.add_column :rating, "integer"
      end
    end

    def remove_index_from_survey_result
      Lhm.change_table :survey_results, :atomic_switch => true do |m|
        m.remove_index [:account_id, :survey_id]
      end
    end

    def revert_migrate_data
      ShardMapping.find_in_batches(:batch_size => 300) do |shard_mappings|
        shard_mappings.each do |shard_mapping|
          Sharding.select_shard_of(shard_mapping.account_id) do
            account = Account.find shard_mapping.account_id
            account.make_current
            
            account.custom_surveys.each do |survey|
              survey_question = survey.default_question
              unless survey_question.nil?
                attributes = { :link_text => survey_question.label }
                survey_question.choices.each do |choice|
                  attributes["happy_text"]   = choice[:value] if choice[:face_value] == CustomSurvey::Survey::EXTREMELY_HAPPY
                  attributes["unhappy_text"] = choice[:value] if choice[:face_value] == CustomSurvey::Survey::EXTREMELY_UNHAPPY
                  attributes["neutral_text"] = choice[:value] if choice[:face_value] == CustomSurvey::Survey::NEUTRAL
                end
                survey.update_attributes(attributes)
              end
            end
            account.surveys.each do |survey|
              survey.survey_results.each do |survey_result|
                survey_result_data = CustomSurvey::SurveyResultData.find_by_survey_result_id(survey_result.id)
                actual_rating = survey_result_data[:cf_int01]
                rating = Survey::NEUTRAL
                if actual_rating == CustomSurvey::Survey::EXTREMELY_HAPPY
                  rating = Survey::HAPPY
                elsif actual_rating == CustomSurvey::Survey::EXTREMELY_UNHAPPY
                  rating = Survey::UNHAPPY
                end
                survey_result.update_attributes({:rating => rating})
              end
            end
            account.all_observer_rules.each do |observer_rule|
              should_save = false
              observer_rule.filter_data[:events].each do |event|
                if event[:name] == "customer_feedback"
                  event[:value] = CustomSurveyRatingToSurveyRating[event[:value].to_s]
                  should_save = true
                end
              end
              observer_rule.save if should_save #to avoid unnecessay update_query due to serialized data columns
            end

            account.quests.each do |quest|
              should_save = false
              quest.filter_data[:actual_data].each do |actual_data|
                if actual_data[:name] == "st_survey_rating"
                  actual_data[:value] = CustomSurveyRatingToSurveyRating[actual_data[:value].to_s]
                  should_save = true
                end
              end
              quest.filter_data[:and_filters].each do |and_filter|
                if and_filter[:name] == "st_survey_rating" && CustomSurveyRatingToSurveyRating[and_filter[:value]] != CustomSurveyRatingToSurveyRating.default
                  and_filter[:value] = CustomSurveyRatingToSurveyRating[and_filter[:value].to_s]
                  should_save = true
                end
              end
              quest.save if should_save
            end

            account.features.custom_survey.destroy
            account.email_notifications.where(:notification_type => EmailNotification::PREVIEW_EMAIL_VERIFICATION).destroy_all
            Account.reset_current_account
          end
        end
      end
    end

end

CustomSurveyRevamp.new.perform_predeployment_migration
# CustomSurveyRevamp.new.send(:migrate_data) #post deployment
