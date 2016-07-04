var FullcontactWidget = Class.create();
FullcontactWidget.prototype = {

    VIEW_LATEST: new Template(
      "<div id='fc-view-template'>" +
        "<div>Click below to view the latest updates from FullContact</div>" +
        "<div class='center'><button id='fc-view-latest' class='mt5' type='button'>View latest</button></div>" +
        "<a class='hide' id='fc-hidden-dialog' rel='freshdialog' data-submit-label='Update' data-close-on-submit='false' data-target='#fc-latest-data' title='Update Latest' data-width='530' href='#'>View latest</a>" +
        "<div id='fc-latest-data' class='hide'></div>" +
      "</div>" +
      "<div id='fc-loading' class='sloading loading-small loading-block custom-position hide'></div>"

    ),

    DISPLAY_MESSAGE: new Template(
        "<form accept-charset='UTF-8' class='update-form' id='fc-update-form'>" +
          "#{diff_data}" +
        "</form>"
    ),

    AVATAR_HTML: new Template(
      '<div class="row-fluid mb15"><div class="span3 cnt-upt-lbl">Avatar</div>' +
        '<div class="span9 cnt-upt-fld row-fluid">' +
          '<span class="span6">' +
            '<div class="span12 mb5">' +
              '#{existing_image_html}' +
            '</div>' +
            '<label ><input type="radio" name="cont-pic" value="existing" checked="checked" /><span class="ml5 vertical-alignment">Retain Existing</span></label>' +
          '</span>' +
          '<span class="span6" >' +
            '<div class="span12 mb5">' +
              '<div class="preview_pic thumb avatar-text text-center bg-6">' +
                '<img alt="NO IMAGE" id="fc-new-avatar" class="thumb" onerror="imgerror(this)" size_type="thumb" src="#{new_image_url}">' +
              '</div>' +
            '</div>' +
            '<label ><input type="radio" name="cont-pic" value="new" /><span class="ml5 vertical-alignment">Use Updated</span></label>' +
          '</span>' +
        '</div>' +
      '</div>'
    ),

    FIELD_INPUT_HTML: new Template(
      "<div class='row-fluid mb15 fields-to-update'>" +
        "<div class='span3 cnt-upt-lbl'>#{display_name}</div>" +
        "<div class='span9 cnt-upt-fld'>" +
          "<span class='mb4'><input type='#{type}' class='field-value' data-field-name='#{field_name}' value='#{new_value}'/></span>" +
          "<span class='muted'>Existing: <b>#{old_value}</b></span>" +
        "</div>" +
      "</div>"
    ),

    ERROR_MESSAGE: "Unknown error. Please contact support@freshdesk.com",

    UPTO_DATE: "Fields are up to date.",

    NO_DOMAINS_ERROR: "No domains added for company.",

  initialize:function(){
    fullcontact_widget = this;
    var $this = this;
    $this.freshdeskWidget = new Freshdesk.Widget({
        app_name: "fullcontact",
        use_server_password: true,
        integratable_type: "crm",
        widget_name: "fullcontact_widget",
        ssl_enabled: false
    });
    $this.fullcontactBundle = fullcontactBundle;
    jQuery(document).off('.fullcontact');

    jQuery(document).on('click.fullcontact','#fc-view-latest', (function(ev){
        ev.preventDefault();
        jQuery("#fullcontact .content #fc-view-template").hide();
        jQuery("#fullcontact .content #fc-loading").show();
        if (!jQuery('.modal#fc-latest-data').get(0)){
          if($this.fullcontactBundle.contact_id){
              $this.type = "contact";
              $this.fetch_contact_details();
          }
          else if($this.fullcontactBundle.company_domains){
              $this.type = "company";
              $this.fetch_company_details();
          }
          else{
            jQuery("#fullcontact .content").html($this.NO_DOMAINS_ERROR);
          }
        }
        else{
          jQuery("#fc-hidden-dialog").click();
          $this.load_widget();
        }
    }));

    jQuery(document).on('submit.fullcontact','#fc-update-form', (function(ev){
      ev.preventDefault();
      if(jQuery('#fc-update-form').valid()){
        jQuery('#fc-latest-data').modal('hide');
        jQuery("#fullcontact .content #fc-view-template").hide();
        jQuery("#fullcontact .content #fc-loading").show();
        var field_values = {};
        jQuery(".fields-to-update").each(function(key, value) {
          field_values[jQuery(value).find(".field-value").data("fieldName")] = (jQuery(value).find(".field-value").val() || "");
        });
        if(jQuery("[name=cont-pic]:checked").val() === 'new'){
          field_values['avatar'] = jQuery("#fc-new-avatar").attr("src");
        }
        var id = fullcontactBundle.contact_id || fullcontactBundle.company_id;
        fullcontact_widget.update_db(field_values, fullcontact_widget.type, id);
      }
      return false;
    }));

    jQuery("#fullcontact .content").html(this.VIEW_LATEST.evaluate({}));
  },

  load_widget:function(){
    jQuery("#fullcontact .content #fc-loading").hide();
    jQuery("#fullcontact .content #fc-view-template").show();
  },

  fetch_contact_details:function(){
    var $this = this;
        this.freshdeskWidget.request({
            source_url: "/integrations/service_proxy/fetch",
            event: 'contact_diff',
            payload: JSON.stringify({contact_id: $this.fullcontactBundle.contact_id}),
            on_failure: $this.handlefailure,
            on_success: function(resData) {
                $this.process_response(resData.responseJSON);
            }
        });
  },
  fetch_company_details:function(){
    var $this = this;
    this.freshdeskWidget.request({
      source_url: "/integrations/service_proxy/fetch",
      event: 'company_diff',
      payload: JSON.stringify({company_id: $this.fullcontactBundle.company_id}),
      on_failure: $this.handlefailure,
      on_success: function(resData) {
        $this.process_response(resData.responseJSON);
      }
    });
  },
  process_response:function(responseJSON){
    if(responseJSON.status === 200){
      if(responseJSON["fd_fields"].length === 0) {
        jQuery("#fullcontact .content").html(this.UPTO_DATE);
      }
      else {
        var avatar_html = "",
            diff_fields_html = "";
        for(var t=0; t<responseJSON["fd_fields"].length; t++){
          var field_hash = responseJSON["fd_fields"][t],
              field_name = Object.keys(field_hash)[0],
              disp_name = field_hash[field_name][0],
              old_value = field_hash[field_name][1],
              new_value = field_hash[field_name][2],
              field_type = field_hash[field_name][3];
              field_type = (field_type !== "url") ? "text" : field_type;
          if(field_name === "avatar"){
            avatar_html += this.AVATAR_HTML.evaluate({existing_image_html: old_value,new_image_url: new_value});
          }
          else{
            diff_fields_html += this.FIELD_INPUT_HTML.evaluate({display_name: disp_name, field_name: field_name, old_value: (old_value || "nil").escapeHTML(), new_value: String(new_value).escapeHTML(), type: field_type});
          }
        }

        jQuery("#fc-hidden-dialog").click();
        jQuery("#fc-latest-data-content").append(this.DISPLAY_MESSAGE.evaluate({diff_data: avatar_html+diff_fields_html}));
        this.load_widget();
      }
    }
    else{
      jQuery("#fullcontact #fc-loading").hide();
      jQuery("#fullcontact .content").html(responseJSON.message);
    }
  },

  update_db:function(field_values, type, id){ 
    var $this = this,
        payload = JSON.stringify({field_values: field_values, type: type, id: id});
    $this.id = id;
    this.freshdeskWidget.request({
      source_url: "/integrations/service_proxy/fetch",
      event: 'update_db',
      payload: payload,
      on_failure: $this.handlefailure,
      on_success: function(resData) {
        if(resData.responseJSON.status === 200){
          var type = $this.type === "company" ? "companies" : "contacts";
          url = "/" + type + "/" + $this.id;
          jQuery("#fullcontact .content").html(resData.responseJSON.message);
          jQuery.pjax({url: url, container: '#body-container', timeout: -1});
        }
        else{
          jQuery("#fullcontact .content").html(resData.responseJSON.message);
        }
      }
    });
  },

  handlefailure: function(evt) {
    jQuery("#fullcontact_loading").remove();
    jQuery("#fullcontact .content").html(this.ERROR_MESSAGE);
  },
}