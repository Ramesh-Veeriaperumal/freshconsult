window.App = window.App || {};
window.App.Contacts.Contacts_merge = window.App.Contacts.Contacts_merge || {};

(function ($) {
  "use strict";

  window.App.Contacts.Contacts_merge = {
    ErrorString: "",
    Twitter: 0,
    Email: 0,
    Facebook: 0,
    Phone: 0,
    ContactNumber: 1,
    Limits: {"twitter" : 2, "facebook" : 2, "emails" : 6, "contacts" : 6, "phone" : 2},
    
    contactsSearch: new Template(
        '<li class="#{d}"><div class="contactelement" data-id="#{id}" data-name="#{name}" data-email="#{email}" '+
        'data-twitter="#{twitter}" data-facebook="#{facebook}" data-phone="#{phone}" data-avatar="#{avatar}" '+
        'data-emails="#{user_emails}">'+
        '<span class="round-icon ficon-plus fsize-15"></span>'+
        '<div data-uid="#{id}" class="user-contact contact_merge_element">'+
        '<div id="avatar_image"><div id="pic" class="preview_pic" size_type="thumb">'+
        '<img alt="" onerror="imgerror(this)" src="#{avatar}"></div></div>'+
        '<div class="user_info_item"><a class="contact_item_info"><b>#{name}</b></a>'+
        '<div class="contact_data">'+
        '<span>#{email}</span>'+
        '</div></div></div></div></li>'
    ),
    
    initialize: function (data) {
      if(data){
        App.Merge.initialize();
        this.bindHandlers();
        this.setDefaults();
        this.setValidationData(data["user"]);
      }
    },

    bindHandlers: function () {
      this.selectUserKeyup();
      this.mergeValidation();
      this.clickOnTyped();
      this.newMergeConfirmClick();
      this.backUserMergeClick();
      this.contactDivClick();
      this.primaryMarkerClick();
      this.respIconClick();
    },

    bindAutocompleter: function () {
      var cachedBackend = new Autocompleter.Cache(this.lookup, {choices: 10});
      this.cachedLookup = cachedBackend.lookup.bind(cachedBackend);
      new Autocompleter.PanedSearch("search-user", this.cachedLookup, this.contactsSearch, 
        "search_results", $A([]), {frequency: 0.1, acceptNewValues: true, 
          afterPaneShow: this.contactsMergeAfterShow, separatorRegEx:/;|,/});
    },

    lookup: function (searchString, callback) { 
      jQuery('.match_results').addClass('sloading loading-small');
      var list = jQuery('.match_results').find('ul');
      if(list.length)
        list.empty();
      new Ajax.Request(window.App.Contacts.Contacts_merge.searchUrl+"v="+searchString, 
                          { parameters: {name: searchString, rand: (new Date()).getTime()},
                            method: 'get',
                            dataType: "json",
                            onSuccess: function(response) {       
                              callback(response.responseJSON.results);
                              jQuery('.match_results').removeClass('sloading loading-small');
                            } 
                          }
                      );
    },

    selectUserKeyup: function () {
      var self = this;
      jQuery('body').on('keyup.merge_contacts', '#search-user', function(){
        jQuery('.match_results').toggle(jQuery(this).val().length >= 2);
        jQuery('.searchicon').toggleClass('typed', jQuery(this).val()!="");
      });
    },

    mergeValidation: function () {
      var self = this;
      jQuery(document).on("mergeValidate", function () {
        self.validateMerge();
      });
    },

    clickOnTyped: function () {
      jQuery('body').on('click.merge_contacts', '.typed', function(){
        App.Merge.clearSearchField(jQuery(this));
        jQuery('.match_results').hide();
      });
    },

    newMergeConfirmClick: function () {
      jQuery('body').on('click.merge_contacts', '#new_merge_confirm', function() {
        jQuery(this).button("loading");
      });
    },

    backUserMergeClick: function () {
      jQuery('body').on('click.merge_contacts', '#back-user-merge', function(){
        jQuery('#new_merge_confirm').button('reset');
        jQuery('#new_merge_confirm').val('Continue');
        jQuery(document).trigger("mergeValidate");
      });
    },

    contactDivClick: function () {
      var self = this;
      jQuery('body').on('click.merge_contacts', '.contactelement', function(){
        var in_element = jQuery("<input type='hidden' name='target[]' id='target[]' />").val(jQuery(this).data('id'));
        if(!jQuery(this).children('.round-icon').hasClass('clicked')){
          self.createMergeUser(in_element, jQuery(this));
          self.modifyValidationValues(jQuery(this), true);
          App.Contacts.Contacts_merge.contactsMergeAfterShow();
        }
      });
    },

    createMergeUser: function (in_element, element) {
      jQuery('#inputs').append(in_element);
      var old_element = jQuery('.contact-primary').clone(), item_info = old_element.find('.contact_item_info');
      var userData = {
        "name" : element.data("name"), 
        "id" : element.data("id"), 
        "avatar" : element.data("avatar"), 
        "emails" : element.data("emails"), 
        "twitter" : element.data("twitter"), 
        "facebook" : element.data("facebook"), 
        "phone" : element.data("phone"),
        "primary" : this.markPrimary
      }
      var email = this.getEmails(userData["emails"]);
      var new_contact = $(JST["app/contacts/selected_contact"](userData));
      new_contact.find('.contact_data').append(jQuery(email));
      new_contact.appendTo('.merge_entity');
      element.children('.round-icon').removeClass('ficon-plus').addClass('ficon-checkmark-round-o clicked');
      item_info.attr('href', '/contacts/'+old_element.find('.user-contact').data('uid'));
      item_info.attr('target', '_blank');
    },

    getEmails: function (emails) {
      var arr = emails.split(","), str = "";
      jQuery.each(arr, function (i) {
         str = str+"<span>"+arr[i]+"</span>"
      });
      return jQuery(str)
    },

    primaryMarkerClick: function () {
      var self = this;
      jQuery('body').on('click.merge_contacts', '.m-primary-marker', function(){
        jQuery('input[type="hidden"]#parent_user_id').attr({name:'target[]', id:false});
        jQuery('input[value='+jQuery(this).siblings('.contact-area').data('id')+']').attr({id:"parent_user_id", name:"parent_user"});
        jQuery('.merge-contact').removeClass('contact-primary');
        jQuery(this).parent().addClass('contact-primary');
        jQuery('.twipsy').hide();
        jQuery('.m-primary-marker').attr('title',self.markPrimary);
        jQuery(this).attr('title',self.primaryText).trigger('mouseover');
      });
    },

    respIconClick: function () {
      var self = this;
      jQuery('body').on('click.merge_contacts', '.round-icon', function(){
        var icons = jQuery(this), chosen_contact = icons.parent(), contact_cover = chosen_contact.parent(), list_contact = jQuery('.contactelement[data-id='+chosen_contact.data("id")+']');
        if(!contact_cover.hasClass('present-contact') && !chosen_contact.hasClass('contactelement')){
          if(!contact_cover.hasClass('contact-primary')){
            jQuery('#inputs').children().each(function(){
              if(jQuery(this).val() == chosen_contact.children('.user-contact').data('uid') ){
                jQuery(this).remove();
              }
            });
            self.modifyValidationValues(chosen_contact, false);
            contact_cover.remove();
            list_contact.children('.round-icon').removeClass('ficon-checkmark-round-o clicked').addClass('ficon-plus');
            list_contact.children().find('.contact_data, .contact_item_info').removeClass('added-contact');
          }
        }
        self.validateMerge(); 
      });
    },

    contactsMergeAfterShow: function () {
      jQuery('#inputs input').each( function(){
        var contact_part = jQuery('.contactelement[data-id='+jQuery(this).val()+']');
        if(contact_part.length)
        {
          contact_part.children('.round-icon').removeClass('ficon-plus').addClass('ficon-checkmark-round-o clicked');
          contact_part.find('.contact_item_info, .contact_data').addClass('added-contact');
        }
      });
      if(jQuery('input[name="target[]"]').length>0){
        jQuery('#new_merge_confirm').removeAttr('disabled').removeClass('disabled');
      }
      else{
        jQuery('#new_merge_confirm').attr('disabled','disabled').addClass('disabled');
      }
      jQuery(document).trigger("mergeValidate");
    },

    //MERGE VALIDATION METHODS

    setValidationData: function (data) {
      this.Email = data["user_emails"].length;
      if(data["twitter_id"])
        this.Twitter = 1;
      if(data["fb_profile_id"])
        this.Facebook = 1;
      if(data["phone"])
        this.Phone = 1;
    },

    setDefaults: function () {
      this.ErrorString="";this.Twitter=0;this.Email=0;this.Facebook=0;this.Phone=0;
      this.ContactNumber=1;
    },

    modifyValidationValues: function (element, add) {
      if(add){
        this.ContactNumber += 1
        if(element.data("emails").length)
          this.Email += element.data("emails").split(",").length;
        this.Twitter += element.data("twitter");
        this.Facebook += element.data("facebook");
        this.Phone += element.data("phone");
      }else{
        this.ContactNumber -= 1
        if(element.data("emails").length)
          this.Email -= element.data("emails").split(",").length;
        this.Twitter -= element.data("twitter");
        this.Facebook -= element.data("facebook");
        this.Phone -= element.data("phone");
      }
    },

    validateMerge: function () {
      this.ErrorString = "";
      this.computeErrors();
      // this.restrictEmails();
    },

    computeErrors: function () {
      if(this.Twitter >= this.Limits["twitter"])
        this.attributeError("twitter");
      if(this.Facebook >= this.Limits["facebook"])
        this.attributeError("facebook");
      if(this.ContactNumber >= this.Limits["contacts"])
        this.attributeError("contacts");
      if(this.Email >= this.Limits["emails"])
        this.attributeError("emails");
      // if(this.Phone >= this.Limits["phone"])
      //   this.attributeError("phone");
      if(this.ErrorString == ""){
        jQuery("p.errors").html("");
        if(jQuery('input[name="target[]"]').length>0)
          jQuery('#new_merge_confirm').removeAttr('disabled').removeClass('disabled');
      }
    },

    attributeError: function(att) {
      // jQuery(".contactelement[data-"+att+"]").parent().not(".selected").addClass("disabled");
      if(!this.ErrorString.length)
        this.ErrorString = this.ErrorSentance;
      else
        this.ErrorString += ", "
      this.ErrorString += (this.Limits[att]-1)+" "+att;
      jQuery("p.errors").html(this.ErrorString);
      jQuery('#new_merge_confirm').attr('disabled','disabled').addClass('disabled');
    },

    // restrictEmails: function () {
    //   var limit = this.Limits["emails"]-this.Email
    //   jQuery('.contactelement[data-emails]').parent().removeClass("disabled");
    //   jQuery('.contactelement[data-emails]').filter(function(){
    //     return jQuery(this).data("emails").split(",").length > limit;
    //   }).parent().addClass("disabled");
    // }
  };
}(window.jQuery));
