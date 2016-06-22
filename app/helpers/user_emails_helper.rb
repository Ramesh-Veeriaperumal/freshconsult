module UserEmailsHelper
  class FreshdeskDomElement < CustomFields::View::DomElement

    def initialize(form_builder, object_name, class_name, field, field_label, dom_type, required, enabled,
                      field_value = '', dom_placeholder = '', bottom_note = '', args = {})
    @account = args[:account]
    @user_companies = args[:user_companies]
    @contractor = args[:contractor]
    super
    end

    def construct_email
      construct_user_email
    end

    def construct_disabled
      if @field_name == "email"
        @field_value = @form_builder.object.user_emails.map(&:email).join(", ")
      end
      super
    end

    def construct_text
      return construct_company_field if @account.features_included?(:multiple_user_companies) && 
                                        @field_name == "company_name"
      super
    end

    private

    def construct_user_email
      output = <<HTML
        <div id="emails_con" class="email_con">
        <ul class="user_emails">
          #{display_user_emails}
        </ul>
        <div class="ue_add_email"><a id="add_new_mail" class="#{@form_builder.object.new_record? ? "disabled" : ""}" href="javascript:void(null);">
          <span class="add_pad ue_action_icons ficon-plus fsize-12"></span><span id="add_email"></span>#{t('merge_contacts.add_another')}</a></div>
        </div>
HTML
    output.html_safe
    end

    # Extension of dom element for user emails display in form
    def display_user_emails
      output = []
      count = 0
      @form_builder.fields_for :user_emails do |ue|
        output << %(<li class="#{ue.object.primary_role ? "disabled" : ""} #{ue.object.new_record? ? "new_email" : ""}" data-count = "#{count}" data-email = "#{html_escape ue.object.email}" data-id = "#{ue.object.id}">)
        if !ue.object.primary_role
          output << content_tag(:span, "", :class => "remove_pad ue_remove_image ue_action_icons ficon-minus fsize-12", "data-email" => ue.object.id)
          title = t('merge_contacts.make_primary')
        else
          output << %(<span class='remove_pad ue_remove_image ue_action_icons disabled ficon-minus fsize-12'></span>)
          title = t('merge_contacts.primary')
        end

        if ue.object.new_record?
            output << ue.text_field(:email, :id => "email_sec", :class => "useremail cont text ue_input fillone", "autocomplete" => "off", "placeholder" => "Enter an email", "data-verified" => ue.object.verified)
        else
            output << ue.hidden_field(:email, :id => "email_sec", :class => "useremail cont #{ue.object.primary_role? ? "disabled" : ""} text ue_input fillone", "autocomplete" => "off", "data-verified" => ue.object.verified)
            output << "<p class='ue_text #{ue.object.primary_role? ? "disabled" : ""}'>#{html_escape ue.object.email}</p>"
        end

        unless ue.object.new_record?
          output << content_tag(:span, "", 
                      :class => "email-tick tooltip fsize-20 #{ue.object.primary_role ? "ficon-checkmark-round primary" : "make_primary"}",
                      :title => title)
          output << content_tag(:span, "", :class => "email-tick tooltip ficon-unverified unverified fsize-16", :title => t('merge_contacts.not_verified')) unless ue.object.verified?
        end
        output << ue.hidden_field(:id, :class => "ue_id")
        output << ue.hidden_field(:primary_role, :class => "ue_primary") 
        output << ue.hidden_field(:_destroy, :value => false, :class => "ue_destroy")
        output << %(<label id="email_sec_#{ue.object.id}-error" class="error" for="email_sec_#{ue.object.id}"></label>)
        output << "</li>"
        count = count+1
      end
      output.join("").html_safe
    end

    def construct_company_field
      output = []
      count = @user_companies.length
      @user_companies.each_with_index do |user_company, index|
        company = user_company.company
        output << %(<li class="uc_list" data-client-manager="#{user_company.client_manager}" data-default-company="#{user_company.default}">)
        output << content_tag(:a, "", :class => "remove_pad uc_actions ficon-minus fsize-12",
                                      :target => "_blank",
                                      :rel => "freshdialog", 
                                      :title => t('contacts.remove_company'),
                                      :'data-target' => "#company-delete-confirmation",
                                      :'data-submit-label' => t('confirm'),
                                      :'data-submit-class' => "btn btn-primary",
                                      :'data-width' => "400px",
                                      :'data-close-label' => t('cancel'),
                                      :'data-destroy-on-close' => true)
        output << "<p class='uc_text' data-id='#{company.id}'>#{html_escape company.name}</p>"
        if user_company.default == true
          title = t('contacts.default_company')
          class_name = "ficon-checkmark-round primary"
        else
          title = t('contacts.mark_default_company')
          class_name = "make_company_default"
        end
        output << content_tag(:span, "", 
                      :class => "default_company tooltip fsize-20 ml9 #{class_name}",
                      :title => title)
        output << "<i class='fsize-18 tooltip client_manager 
                        #{user_company.client_manager == true ? "unmanage ficon-ticket" : "manage ficon-ticket-thin"}' 
                      title='#{t('contacts.client_manager')}'></i>"
        output << "</li>"
      end if @user_companies.present?
      check_box_html = @form_builder.check_box(:contractor, 
                                              { :class => "activate", 
                                                :checked => @contractor}, true, false).html_safe
      output = output.join("").html_safe
      ret = <<HTML
        <div id="user_companies" class="user_comp">
          <ul class="companies">
            #{output}
          </ul>
          <div class="uc_add_company">
            <a id="add_new_company" href="javascript:void(null);">
              <span class="add_pad uc_actions ficon-plus fsize-12"></span>
              <span id="add_company"></span>
              #{t('add_new_company')}
            </a>
          </div>
        </div>
HTML
      ret.html_safe
    end
  end
end
