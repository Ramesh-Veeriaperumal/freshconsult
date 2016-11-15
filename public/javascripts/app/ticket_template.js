var TicketTemplate = {
  init: function(){
    this.bindEvents();
    this.initLocalStorage();
  },
  destroy: function(){
    this.unBindEvents();
  },
  unBindEvents: function(){
      jQuery('body').off('.ticket_template');
      jQuery("#template-wrapper").off('.ticket_template');
  },
  bindEvents: function(){
    this.templateSubmitCallback();
    // Event for clicking select template
    jQuery('body').on('click.ticket_template', '[data-action="select-template"]', function(e){
      jQuery("#loading-box").find('span.loading-text').text("Applying template");
      e.stopPropagation();
      jQuery("#filter-template").val("");
      jQuery("#template-wrapper").toggleClass('active');
      this.getTemplateData("initload");
    }.bind(this));
    //Event for clicking document to close the template popup
    jQuery('body').on('click.ticket_template', function(event){
      var src = event.srcElement || event.target;
      var srcEle = jQuery(src).attr('id');
      if(jQuery('#template-wrapper').hasClass('active') && srcEle !== "filter-template"){
        jQuery("#template-wrapper").removeClass('active');
      }
    });
    // Event for clicking on template list
    jQuery("#template-wrapper").on('click.ticket_template', 'li', function(event){
        var src = event.srcElement || event.target;
			var curElem = jQuery(src);
			this.changeTemplate(curElem);
		}.bind(this));

    jQuery('body').on('keyup.ticket_template', '#filter-template', function(e){
      e.stopPropagation();
      var isKeyAllowed = this.checkAllowedKeys(e.keyCode);
      if(isKeyAllowed){
        debounce(this.getTemplateData("keypress"), 10000);
      }
    }.bind(this));
  },
  initLocalStorage: function(){
    var initarray = [];
    if(window.localStorage && !localStorage.getItem('recent-tmpl')){
      localStorage.setItem('recent-tmpl', Browser.stringify(initarray));
    }
  },
  checkAllowedKeys: function(keyCode){
    if(keyCode === 37 || keyCode === 38 || keyCode === 39 || keyCode === 40 || keyCode === 13){
      return false;
    }
    return true;
  },
  hideSearchBox: function(){
    var $filterWrapper = jQuery(".filter-wrapper");
    if($filterWrapper.is(':visible')){
      $filterWrapper.addClass('hide');
    }
  },
  showSearchBox: function(){
    var $filterWrapper = jQuery(".filter-wrapper");
    if($filterWrapper.hasClass('hide')){
      $filterWrapper.removeClass('hide');
    }
  },
  getTemplateData: function(event){
    var recentTemplate = this.getRecentTemplate(), loadParams = "";
    var recentTemplateArray = JSON.parse(recentTemplate);
    var searchParams = {};

    if(App.namespace === "helpdesk/tickets/new"){
      loadParams = {prime : "prime"};
      searchParams.prime = "prime";
    }
    if(recentTemplateArray.length > 0){
      if(typeof loadParams == 'string'){
        loadParams = {recent_ids: recentTemplate};
      }else{
        loadParams.recent_ids = recentTemplate;
      }
    }
    var searchUrl = "/helpdesk/tickets/search_templates",
        loadUrl = "/helpdesk/tickets/accessible_templates";
        searchString = jQuery("#filter-template").val();
        searchParams.search_string = searchString;
    var params = ((event === 'keypress' && searchString !== "") ? searchParams : loadParams),
        endpoint = ((event === 'keypress' && searchString !== "") ? searchUrl : loadUrl),
        _this = this, xhr = "";
        if(xhr && xhr.readyState != 4){
             xhr.abort();
         }
      xhr = jQuery.ajax({
        url: endpoint,
        data: params,
        beforeSend: function(){
          jQuery("#template-loading").show();
          jQuery("#template-items").hide();
          if(event !== 'keypress'){
            _this.hideSearchBox();
          }
        },
        success: function(data){
          data["previlage"] = jQuery("#template_previlage").val();
          data['istmplAvailable'] = jQuery("#template_count").val();
          if(event === 'keypress'){
            data["event"] = 'search';
          }
          var len = data.all_acc_templates.length + (data.recent_templates ? data.recent_templates.length : 0);
          jQuery("#template-loading").hide();
          jQuery("#template-items").show();
          var tmpl = JST["app/template/ticket_template"]({
              data: data
          });
          jQuery("#template-items").removeClass('sloading').html(tmpl);
          if(len >= 10 && event !=='keypress' ){
            _this.showSearchBox();
          }
          jQuery('[data-picklist]').scrollTop(0);
          _this.enablePicklist();
        },
        error: function(){

        }
      })
  },
  cloneCompanyField: function(){
    // Cloning select box for retaining
    this.requesterCompany = jQuery(".default_company").clone();
    this.requesterCompanyVal = jQuery(".default_company").find('select.select2').val();
    // Deleting generated selected, sice we can't able to destroy it.
    this.requesterCompany.find('div.select2').remove();
  },
  newTicketHooks: function(){
    var $dynamic_values = jQuery("#dynamic_values");
    CreateTicket.unBindEvents();
    this.createHiddenElement('requester_email', jQuery("#helpdesk_ticket_email").val(), $dynamic_values);
    this.createHiddenElement('cc_email', this.generateCcMail(), $dynamic_values);
    this.cloneCompanyField();
  },
  composeTicketHooks: function(){
    var $dynamic_values = jQuery("#dynamic_values");
    ComposeEmail.unbindEvents();
    this.createHiddenElement('config_emails', jQuery("#helpdesk_ticket_email_config_id").val(), $dynamic_values);
    this.createHiddenElement('requester_email', jQuery("#helpdesk_ticket_email").val(), $dynamic_values);
    this.createHiddenElement('cc_email', this.generateCcMail(), $dynamic_values);
    this.cloneCompanyField();
  },
  showLoader: function(){
    if(jQuery('.loading-template').hasClass('hide')){
      jQuery('.loading-template').removeClass('hide');
    }
  },
  hideLoader: function(){
    jQuery('.loading-template').addClass('hide');
  },
  createHiddenElement: function(fieldName, val, appendForm){
    jQuery('<input>').attr({
      type: 'hidden',
      value: val,
      name: fieldName
    }).appendTo(appendForm);
  },
  generateCcMail: function(){
    var cc_email = [];
    jQuery("[name='cc_emails[]']").each(function(){
      cc_email.push(jQuery(this).val());
    });
    return cc_email;
  },
  getRecentTemplate: function(){
    if(window.localStorage && localStorage.getItem('recent-tmpl')){
      return localStorage.getItem('recent-tmpl');
    }
  },
  enablePicklist: function(){
    var _this = this;
    jQuery("#filter-template").pickList({
  		listId: jQuery("#template-items"),
  		callback: function(){
  			var activeElem = jQuery("#template-items li.active");
        if(activeElem.length > 0){
          _this.changeTemplate(activeElem);
        }
  		}
	 });
 },
 changeTemplate: function(elem){
   var id = $(elem).data('id');
   this.setRecentTemplate(id);
   var requesterId = jQuery("#helpdesk_ticket_requester_id").val(),
       requesterValue = jQuery("#helpdesk_ticket_email").val();
    App.requesterId = requesterId;
    App.requesterValue = requesterValue;

   if(id){
     jQuery("input#_template_id").val('').val(id);
     jQuery("#dynamic_values").empty();
     this.showLoader();
     if(CreateTicket && App.namespace === "helpdesk/tickets/new"){
       this.newTicketHooks();
       //parent child template changes
       jQuery('#child_select_template_wrapper').empty();
     }
     if(ComposeEmail && App.namespace === "helpdesk/tickets/compose_email"){
       this.composeTicketHooks();
     }
   }
   jQuery("#template-wrapper").removeClass('active');
   jQuery('form#apply_template_form').submit();
 },
 templateSubmitCallback: function(){
   var _this = this;
   jQuery('form#apply_template_form').bind("ajax:complete", function(){

    //  OFF the event binding for nested fields
      jQuery(document).off('.nested_field');
     jQuery("#helpdesk_ticket_email").data("initialRequester", App.requesterValue);
     jQuery("#helpdesk_ticket_email").data("initialRequesterid", App.requesterId);
     jQuery("#helpdesk_ticket_requester_id").val("").val(App.requesterId);
    //  Retain company field in compose and new ticket
     if(App.namespace === "helpdesk/tickets/new"){
       jQuery("#ticket-fields-wrapper").find('.default_company').remove();
       _this.requesterCompany.insertAfter(jQuery(".default_requester"));
     }else{
       jQuery("#compose-new-email").find('.default_company').remove();
       _this.requesterCompany.insertBefore(jQuery(".default_priority"));
     }
     _this.requesterCompany.find('select').val(_this.requesterCompanyVal).trigger('change');
     jQuery("#helpdesk_ticket_status").trigger('change');
     jQuery("#loading-box").find('span.loading-text').text("Template Applied");
     setTimeout(function(){
       _this.hideLoader();
     }, 250);
   });
 },
 setRecentTemplate: function(id){
   if(window.localStorage){
     var recent = localStorage.getItem('recent-tmpl') ? JSON.parse(localStorage.getItem('recent-tmpl')) : [],
     templateIndex = recent.indexOf(id);
     if(recent.length > 10){
       recent.pop();
     }
     if(templateIndex === -1){
       recent.unshift(id);
     }else{
       recent.splice(templateIndex, 1);
       recent.unshift(id);
     }
     localStorage.setItem('recent-tmpl', Browser.stringify(recent));
   }
 }
};

// DEBOUNCE technique based on underscore
function debounce(func, wait, immediate) {
	var timeout;
	return function() {
		var context = this, args = arguments;
		var later = function() {
			timeout = null;
			if (!immediate) func.apply(context, args);
		};
		var callNow = immediate && !timeout;
		clearTimeout(timeout);
		timeout = setTimeout(later, wait);
		if (callNow) func.apply(context, args);
	};
};
