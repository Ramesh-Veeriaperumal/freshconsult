class Import::Skills::Agent
  include ImportCsvUtil

  attr_accessor :file_location, :imported_agent_details, :notify_details,
          :available_skills, :available_agents

  HEADERS_MAPPING = {"Email" => 0, "Skills" => 1}
  ALL_CONDITIONS = 'all'
  SKILL = 'skills'

  def initialize(params={})
    @file_location = params[:file_path]
    @imported_agent_details = Hash.new
    @csv_headers = Hash.new
    @notify_details = {
      :customer_message => {
        :skill_creation_success => [],
        :skill_creation_failed => [],
        :skill_not_found => [],
        :skill_update_success => [], # agent update success
        :agent_update_failed => {},
        :agent_not_found => []
      },
      :csv_errors => Hash.new { |h, k| h[k] = [] },
      :system_usage => {
        :other_errors => []
      }
    }
  end

  def import
    read_file(file_location)
    notify_error_and_cleanup and return if @rows.count.zero? or non_proper_header?
    parse_csv_content
    update_imported_agents
    check_invalid_emails
    notify_and_cleanup
  rescue Exception => e
    Rails.logger.debug("Exception while Importing skills:: #{e.inspect}")
    Rails.logger.debug(e.backtrace)
    NewRelic::Agent.notice_error(e)
  end

  private
    def current_account
      Account.current
    end

    def non_proper_header?
      (HEADERS_MAPPING.keys - @rows.first).count.nonzero?
    end

    def parse_csv_content
      set_headers(@rows.first)
      @rows.delete_at(0)
      @rows.each do |content|
        csv_email = fetch_email(content)
        imported_agent_details[csv_email] = fetch_skills(content) if csv_email.present?
      end
    end

    def set_headers(content)
      content.each_with_index do |header_key, index|
        @csv_headers[header_key] = index
      end
    end

    def update_imported_agents
      imported_agents.each do |agent|
        if imported_agent_details[agent.email].present?
          @current_agent = agent.email
          skills = imported_agent_details[agent.email]
          find_or_create_skills(skills)
          skill_ids = fetch_agent_skill_ids(skills).uniq
          begin
            agent.skill_ids = []      # clearing existing skills to get new preference from csv
            agent.skill_ids = skill_ids
            if skills.count == skill_ids.count
              notify_details[:customer_message][:skill_update_success] << agent.email
            else
              notify_details[:customer_message][:agent_update_failed][agent.email] = agent.email # just to increase error count
              notify_details[:csv_errors][@current_agent] << "Unable to assign skills #{fetch_unassigned_skill_names(skills)}"
            end
          rescue ActiveRecord::RecordInvalid => e
            agent.reload # not working in staging so again fetching from db.
            agent.skill_ids = skill_ids.slice(0..User::MAX_NO_OF_SKILLS_PER_USER-1) #slicing 1st 35 skills because it will not take partial skill ids.
            unassigned_skill_ids = skill_ids[User::MAX_NO_OF_SKILLS_PER_USER, skill_ids.length]
            notify_details[:customer_message][:agent_update_failed][agent.email] = build_skill_limit_error(unassigned_skill_ids, e.exception.message)
            notify_details[:csv_errors][@current_agent] << build_skill_limit_error(unassigned_skill_ids, e.exception.message)
          rescue Exception => e
            # need to check
            NewRelic::Agent.notice_error(e)
            notify_details[:system_usage][:other_errors] << [current_account.id, agent.email, e.exception.message]
          end
        end
      end
    end

    def fetch_unassigned_skill_names(skills)
      skills.select do |_skill_name|
        available_skills[_skill_name.strip.downcase].blank?
      end.compact.join(' , ')
    end

    def find_or_create_skills(skill_collection)
      new_skills = find_new_skills(skill_collection)
      create_new_skills(new_skills) if new_skills.count.nonzero?
    end

    def fetch_agent_skill_ids(skill_collection)
      skill_ids = skill_collection.map do |_skill_name|
        if available_skills[_skill_name.strip.downcase].present?
          available_skills[_skill_name.strip.downcase]
        else
          unless notify_details[:customer_message][:skill_creation_failed].include?(_skill_name.strip.downcase)
            notify_details[:customer_message][:skill_not_found] << _skill_name.strip.downcase
          end
          nil
        end
      end.compact
      Rails.logger.debug("Skills for #{@current_agent} #{skill_collection.inspect}  --- #{skill_ids.inspect}")
      skill_ids
    end

    def find_new_skills(csv_skills)
      csv_skills.collect do |_skill|
        _skill unless available_skills.keys.include?(_skill.strip.downcase)
      end.compact
    end

    def create_new_skills(new_skills)
      new_skills.each do |_skill_name|
        next if notify_details[:customer_message][:skill_creation_failed].include?(_skill_name.strip)

        _skill = current_account.skills.create(:name => _skill_name.strip, :match_type => ALL_CONDITIONS)
        if _skill.errors.any?
          notify_details[:customer_message][:skill_creation_failed] << _skill_name.strip
          notify_details[:csv_errors][@current_agent] << fetch_validation_errors(_skill)
        else
          available_skills[_skill.name.downcase] = _skill.id
          notify_details[:customer_message][:skill_creation_success] << _skill.name
        end
      end
    end

    def notify_and_cleanup
      UserNotifier.send_email(:notify_skill_import, User.current.email, :message => notify_details[:customer_message], :csv_data => build_csv_string)
      delete_import_file(file_location)
      current_account.agent_skill_import.destroy
    end

    def notify_error_and_cleanup
      UserNotifier.send_email(:notify_skill_import, User.current.email, :failure => true, :file_name => file_location.split('/').last)
      delete_import_file(file_location)
      current_account.agent_skill_import.destroy
    end

    def available_skills
      @available_skills ||= current_account.skills_trimmed_version_from_cache.map {|_skill|
        [_skill.name.downcase, _skill.id]
      }.to_h
    end

    def available_agents
      @available_agents ||= begin
        current_account.agents_details_from_cache.map do |agent|
          agent.email
        end
      end
    end

    def imported_agents
      @imported_agents ||= begin
        Sharding.run_on_slave do
          current_account.all_users.visible.technicians.where(email: imported_agent_details.keys)
        end
      end
    end

    def build_skill_limit_error(unassigned_skill_ids, error_msg)
      skill_names = unassigned_skill_ids.collect do |_skill_id|
        available_skills.key(_skill_id)
      end
      "Unassigned skill list: #{skill_names.join(', ')} #{error_msg}"
    end

    def fetch_validation_errors(skill_obj)
      error_string = String.new
      skill_obj.errors.messages.each do |k, _error_msg|
        error_string << "#{_error_msg.join(',')} "
      end
      "#{skill_obj.name} #{error_string.strip} "
    end

    def check_invalid_emails
      invalid_emails = (imported_agent_details.keys - imported_agents.pluck(:email))
      notify_details[:customer_message][:agent_not_found] = invalid_emails
    end

    def build_csv_string
      return if notify_details[:csv_errors].blank? and notify_details[:customer_message][:agent_not_found].blank?
      csv_string = CSVBridge.generate do |csv|
        csv << ["Email", "Skills", "Errors"]
        notify_details[:csv_errors].each do |agent_email, errors|
          agent_info = imported_agent_details[agent_email]
          csv << [agent_email, agent_info.join(', '), errors.join(', ')]
        end

        notify_details[:customer_message][:agent_not_found].each do |agent_email|
          agent_info = imported_agent_details[agent_email]
          csv << [agent_email, agent_info.join(', '), "Incorrect Email"]
        end
      end
    end

    Agent::SKILL_IMPORT_FIELDS.each do |header_name|
      define_method("fetch_#{header_name.downcase}") do |content|
        result = content[@csv_headers[header_name]].strip
        if header_name.downcase.eql?(SKILL)
          return result.split(',').map do |item|
            item.strip if item.present?
          end.compact.uniq
        end
        result
      end
    end
end
