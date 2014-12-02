window.App = window.App || {};
window.App.Contacts.Contacts_merge = window.App.Contacts.Contacts_merge || {};

(function ($) {
  "use strict";

  window.App.Contacts.Contacts_merge = {

    contactsSearch: new Template(
        '<li><div class="contactdiv" data-id="#{id}">'+
        '<span id="resp-icon"></span>'+
        '<div id="user-contact" data-uid="#{id}" class="merge_element">'+
        '<div id="avatar_image"><div id="pic" class="preview_pic" size_type="thumb">'+
        '<img alt="" onerror="imgerror(this)" src="#{avatar}"></div></div>'+
        '<div id="user_info_item"><a class="item_info"><b>#{name}</b></a>'+
        '<div class="info_contact_data">'+
        '<span>#{email}</span>'+
        '<span>#{company}</span>'+
        '</div></div></div></div></li>'
    ),
    
    initialize: function (data) {
      App.Merge.initialize();
      this.bindHandlers();
    },

    bindHandlers: function () {
      this.selectUserKeyup();
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
      new Autocompleter.PanedSearch("select-user", this.cachedLookup, this.contactsSearch, 
        "match_results", $A([]), {frequency: 0.1, acceptNewValues: true, 
          afterPaneShow: this.contactsMergeAfterShow(), separatorRegEx:/;|,/});
    },

    lookup: function (searchString, callback) { 
      jQuery('#match_results').addClass('sloading loading-small');
      var list = jQuery('#match_results').find('ul');
      if(list.length)
        list.empty();
      new Ajax.Request(window.App.Contacts.Contacts_merge.searchUrl+'v='+searchString, 
                          { parameters: {name: searchString, rand: (new Date()).getTime()},
                            method: 'get',
                            onSuccess: function(response) {       
                              callback(response.responseJSON.results);
                              jQuery('#match_results').removeClass('sloading loading-small');
                            } 
                          }
                      );
    },

    selectUserKeyup: function () {
      jQuery('body').on('keyup.merge_contacts', '#select-user', function(){
        jQuery('#match_results').toggle(jQuery(this).val().length >= 2);
        jQuery('.searchicon').toggleClass('typed', jQuery(this).val()!="");
      });
    },

    clickOnTyped: function () {
      jQuery('body').on('click.merge_contacts', '.typed', function(){
        App.Merge.clearSearchField(jQuery(this));
        jQuery('#match_results').hide();
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
      });
    },

    contactDivClick: function () {
      jQuery('body').on('click.merge_contacts', '.contactdiv', function(){
        var in_element = jQuery("<input type='hidden' name='ids[]' id='ids[]' />").val(jQuery(this).data('id'));
        // var in_element = "<input type='hidden' name='ids[]' id='ids[]' value="+jQuery(this).data('id')+" />";
        if(!jQuery(this).children('#resp-icon').hasClass('clicked'))
        {
          jQuery('#inputs').append(in_element);
          var element = jQuery('.cont-primary').clone();
          App.Merge.appendToMergeList(element, jQuery(this));
          var item_info = element.find('.item_info');
          item_info.attr('href', '/contacts/'+element.find('#user-contact').data('uid'));
          item_info.attr('target', '_blank');
          App.Contacts.Contacts_merge.contactsMergeAfterShow();
        }
      });
    },

    primaryMarkerClick: function () {
      jQuery('body').on('click.merge_contacts', '.primary-marker', function(){
        jQuery('input[type="hidden"]#parent_user_id').attr({name:'ids[]', id:false});
        jQuery('input[value='+jQuery(this).siblings('#contact-area').children('#user-contact').data('uid')+']').attr({id:"parent_user_id", name:"parent_user"});
        App.Merge.makePrimary(jQuery(this).parent());
      });
    },

    respIconClick: function () {
      jQuery('body').on('click.merge_contacts', '#resp-icon', function(){
        var icons = jQuery(this), chosen_contact = icons.parent(), contact_cover = chosen_contact.parent();
        if(!contact_cover.hasClass('present-contact') && !chosen_contact.hasClass('contactdiv'))
        {
          if(!contact_cover.hasClass('cont-primary'))
          {
            jQuery('#inputs').children().each(function(){
              if(jQuery(this).val() == chosen_contact.children('#user-contact').data('uid'))
              {
                jQuery(this).remove();
              }
            });
            contact_cover.remove();
            jQuery('.contactdiv').children('#resp-icon').removeClass('clicked');
            jQuery('.contactdiv').children().find('.info_contact_data, .item_info').removeClass('added-contact');
            App.Contacts.Contacts_merge.contactsMergeAfterShow();
          }
        } 
      });
    },

    contactsMergeAfterShow: function () {
      var contact_divs = jQuery('.contactdiv');
      contact_divs.each(function(){
        var contact_part = jQuery(this);
        jQuery('#inputs').children('input').each( function(){
          if(jQuery(this).val() == contact_part.data('id'))
          {
            contact_part.children('#resp-icon').addClass('clicked');
            contact_part.find('.item_info, .info_contact_data').addClass('added-contact');
          }
        });
      });
      if(jQuery('#inputs').children('[name="ids[]"]').length>0)
      {
        jQuery('#new_merge_confirm').removeAttr('disabled').removeClass('disabled');
      }
      else
      {
        jQuery('#new_merge_confirm').attr('disabled','disabled').addClass('disabled');
      }
    }
  };
}(window.jQuery));

