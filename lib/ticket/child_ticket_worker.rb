class Ticket::ChildTicketWorker < BaseWorker

  include ParentChildHelper

  def initialize(params)
    @failed_items  = []
    @msg_to_notify = []
    @params        = params
    @account       = Account.current
    load_assoc_parent_tkt
    load_parent_template
  end

  def child_tkt_create
    @current_user = load_user.make_current
    if @parent_template && @parent_template.visible_to_me?
      child_templates.each  do |child_templ|
        kick_off_child_creation child_templ
      end
    else
      error_msg = @parent_template ? "tmpl_inaccessible" : "tmpl_unavailable"
      @msg_to_notify << error_msg
    end
  rescue Exception => e
    exception_sandbox e
  ensure
    if @msg_to_notify.present? || @failed_items.present?
      notify_params = {
        :user         => @current_user,
        :parent_tkt   => @assoc_parent_ticket,
        :error_msg    => @msg_to_notify.uniq,
        :child_count  => @params[:child_ids].count,
        :failed_items => @failed_items
      }
      Helpdesk::TicketNotifier.send_later(:deliver_notify_bulk_child_creation,
        notify_params)
    end
  end

  private

  def load_user user_id = nil
    user = execute_on_db { @account.technicians.find_by_id(user_id || @params[:user_id]) }
  end

  def portal portal_id = nil
    @portal ||= execute_on_db { @account.portals.find_by_id(portal_id || @params[:portal_id]) }
  end

  def load_assoc_parent_tkt
    @assoc_parent_ticket ||= execute_on_db { @account.tickets.preload(:ticket_old_body,:schema_less_ticket,
      :attachments).find_by_param(@params[:assoc_parent_tkt_id], @account) }
  end

  def child_templates
    @child_templs ||= execute_on_db { @parent_template.child_templates.where(id: @params[:child_ids]) }
  end

  def execute_on_db(db_name="run_on_slave")
    Sharding.safe_send(db_name.to_sym) do
      yield
    end
  end

  def build_ticket
    @item = @account.tickets.new
    construct_tkt
  end

  def kick_off_child_creation child_templ
    if allow_child_creation?
      build_ticket
      allocate_data child_templ
      build_tkt_attachments child_templ
      validate_attrbs
      @item.save_ticket!
    else
      @failed_items << child_templ.name
    end
  rescue Exception => e
    @failed_items << child_templ.name
    exception_sandbox e
  end

  def allow_child_creation?
    if @assoc_parent_ticket && @assoc_parent_ticket.can_be_associated?
      @msg_to_notify << "child_tkt_limit_reached" unless @assoc_parent_ticket.child_tkt_limit_reached?
    else
      @msg_to_notify << "assoc_prt_tkt_unavailable"
    end
    @msg_to_notify.present? ? false : true
  end

  def allocate_data child_template
    templ_data = child_template.template_data
    templ_data.each do |key,value|
      consign_values key, value
    end
    descp_html(child_template.data_description_html, templ_data)
    @item.cc_email  = {:cc_emails => [], :fwd_emails => [], :reply_cc => [], :tkt_cc => []}
    set_ticket_association
  end

  def consign_values key, value
    if key == "inherit_parent"
      attrbs = if value.is_a?(Array)
        value.flatten!
        value = merge_section_fields(value) if @account.dynamic_sections_enabled?
        value
      elsif  value == "all"
        all_attrs_from_parent
      end
      attrbs.each { |key|
        val = prt_tkt_fd_value(key)
        assign_attr(key, val) }
    else
      assign_attr key, liqd_parser(value)
    end
  end

  def descp_html descp_value, data
    if descp_value and !inherit_descp_html?(data)
      assign_attr "description_html", liqd_parser(descp_value)
    end
  end

  def inherit_descp_html? data
    data.keys.include?("inherit_parent") && (data["inherit_parent"] == "all" ||
      data["inherit_parent"].include?("description_html"))
  end

  def liqd_parser value
    value = if value.is_a?(String)
      Liquid::Template.parse(value).render('ticket' => @assoc_parent_ticket,
        'helpdesk_name' => @assoc_parent_ticket.account.helpdesk_name)
    else
      value
    end
  end

  def assign_attr key, value
    if TicketConstants::CHILD_DEFAULT_FD_MAPPING.include?(key)
      if key == "tags"
        (@item.tag_names = value)
      elsif key == "description_html"
        @item.ticket_body.description_html = value
      else
        @item.safe_send("#{key}=",value)
      end
    else
      @item.custom_field.merge!({key => value})
    end
  end

  def build_tkt_attachments child_template
    data = child_template.template_data
    attachable_item = if inherit_descp_html?(data)
      @assoc_parent_ticket
    else
      child_template
    end
    fetch_attachments attachable_item
  end

  def fetch_attachments assoc_parent_item
    assoc_parent_item.all_attachments.each do |attachment|
      @item.attachments.build(content: attachment.to_io, description: '', account_id: @account)
    end
    assoc_parent_item.cloud_files.each do |cloud_file|
      @item.cloud_files.build(url: cloud_file.url, application_id: cloud_file.application_id, filename: cloud_file.filename)
    end
  end

  def validate_attrbs
    ["group", "product", "responder", "requester"].each do |attrb|
      safe_send("validate_#{attrb}")
    end
  end

  def validate_group
    if @item.group_id
      @item.group_id = execute_on_db { @account.groups.find_by_id(@item.group_id).try(:id) }
    end
  end

  def validate_product
    if @item.product_id
      @item.product_id = execute_on_db { @account.products.find_by_id(@item.product_id).try(:id) }
    end
  end

  def validate_responder
    if @item.responder_id
      agent = load_user(@item.responder_id)
      @item.responder_id = nil if agent.nil? || agent.blocked?
    end
  end

  def validate_requester
    if (req = @item.requester)
      @item.email = nil
      @item.requester_id = nil if (req.deleted? || req.spam? || req.blocked?)
    elsif @item.email
      user = execute_on_db { @account.all_users.find_by_an_unique_id({ :email => @item.email }) }
      if user
        (user.deleted? || user.spam? || user.blocked?) ? (@item.email = nil) : (@item.requester_id = user.id)
      end
    end
    @item.requester_id = (@assoc_parent_ticket.responder_id.nil? ? @current_user.id :
      @assoc_parent_ticket.responder_id) if @item.requester_id.nil? and !@item.email
  end

  def merge_section_fields values
    execute_on_db {
      section_parent_fds = @account.section_parent_fields.select {|fd| values.include?(fd.name)}
      if section_parent_fds.present?
        pl_section_fd_ids = []
        section_parent_fds.each do |section_field|
          key = section_field.name
          parent_field_value = @assoc_parent_ticket.safe_send(key)
          next if parent_field_value.nil?
          picklist = section_field.picklist_values_with_sections.find_by_value(parent_field_value)
          if picklist and (pl_section = picklist.section)
            pl_section_fd_ids << pl_section.section_fields.pluck(:ticket_field_id)
          end
        end
        pl_section_fd_ids.flatten!
        @section_fields_name = section_fields_name(pl_section_fd_ids)
      end
    }
    values | (@section_fields_name || [])
  end

  def section_fields_name pl_section_fd_ids
    section_fields_name = []
    ticket_fields_with_nested_fields = @account.ticket_fields_with_nested_fields
    ticket_fields_with_nested_fields.where('id IN (?) and field_options like (?)', pl_section_fd_ids,'%section: true%').each do |tf|
      section_fields_name << tf.name
      child_levels = if tf.nested_field?
        ticket_fields_with_nested_fields.select { |field| field.parent_id == tf.id }
      end
      section_fields_name << child_levels.map(&:name) unless child_levels.blank?
      section_fields_name.flatten!
    end
    section_fields_name
  end

  def exception_sandbox exp
    puts exp.inspect
    puts exp.backtrace.join("\n\t")
    Rails.logger.error("Error while creating child tkts. \n#{exp.message}\n#{exp.backtrace.join("\n")}")
    NewRelic::Agent.notice_error(exp, {:description => "Error while craeting child tkts. :: #{@params}"})
  end
end
