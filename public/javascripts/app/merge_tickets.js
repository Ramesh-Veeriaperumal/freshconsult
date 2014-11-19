window.App = window.App || {};
window.App.Tickets.Merge_tickets = window.App.Tickets.Merge_tickets || {};

(function ($) {
  "use strict";

  window.App.Tickets.Merge_tickets = {

    global: {},

    ticketSearch: new Template(
                          '<li><div class="ticketdiv" data-id="#{display_id}">'+
                          '<span id="resp-icon"></span>'+
                          '<div id="merge-ticket" class="merge_element" data-id="#{display_id}" data-created="#{created_at_int}">'+
                          '<span class="item_info" title="#{subject}">##{display_id} #{subject}</span>'+
                          '<div class="info-data hideForList">'+
                          '<span class="merge-ticket-info">#{ticket_info}</span>'+
                          '</div></div></div></li>'
                        ),

    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      App.Merge.initialize();
      this.bindHandlers();
    },
    onLeave: function () {
      jQuery('body').off('.merge_tickets');
      jQuery('#ticket-merge').parent().remove();
    },

    bindHandlers: function () {
      this.typedClick();
      this.searchKeyup();
      this.checkRequester();
      this.enableContinue();
      this.primaryMarkerClick();
      this.bulkMergeClick();
      this.searchTypeChange();
      this.ticketDivClick();
      this.clickRespIcon();
    },

    typedClick: function () {
      jQuery('body').on('click.merge_tickets', '.typed', function(){
        clearSearchField(jQuery(this));
        var type = jQuery('#search-type option:selected').val();
        jQuery('#'+type+'_results').hide();
      });
    },

    searchKeyup: function () {
      jQuery('body').on('keyup.merge_tickets', '.search_merge', function(){
        var search_type = jQuery('#search-type option:selected').val();
        var minChars = ( search_type == "display_id" ) ? 1 : 2
        jQuery('.merge_results').hide();
        if((jQuery(this).val() != "") && (jQuery(this).val().length >= minChars))
          jQuery('#'+search_type+'_results').show();
        else
          jQuery('#'+search_type+'_results').hide();
      });
    },

    checkRequester: function () {
      var requester = jQuery('.requester_name').html();
      var same = true;
      jQuery('.requester_name').each(function(index){
        if(jQuery(this).html() != requester)
        {
          same = false;
          return false;
        }
      });
      if(same){
        jQuery('#select-requester').val('<'+requester+'>').keyup();
        if(App.Tickets.Merge_tickets.global['select-requester']){
          App.Tickets.Merge_tickets.global['select-requester'].onSearchFieldKeyDown(42);
        }
        setTimeout(function(){ jQuery('#select-requester').val(requester) }, 100);
      }
    },

    primaryMarkerClick: function () {
      var $this = this;
      jQuery('body').on('click.merge_tickets', '.primary-marker', function(){
        App.Merge.makePrimary(jQuery(this).parents('.merge-cont'));
        jQuery('.twipsy').hide();
        jQuery('.primary-marker').attr('data-original-title','Mark as primary')
        jQuery(this).attr('data-original-title','Primary ticket').trigger('mouseover')
        $this.enableContinue();
      });
    },

    bulkMergeClick: function () {
      jQuery('body').on('click.merge_tickets', '#bulk_merge', function(){
        jQuery('#bulk_merge').button("loading");
        jQuery('#cancel').attr("disabled", true).addClass("disabled");
        jQuery("#target_ticket").val(jQuery('.cont-primary #merge-ticket').data("id"));
        var source_tickets = [];
        var target = jQuery('#bulk_merge_tickets');
        jQuery(".merge-cont:not('.cont-primary')").each(function(){ 
          target.append(jQuery('<input />').attr({
            name: "source_tickets[]",
            type: 'hidden',
            value: jQuery(this).find("#merge-ticket").data("id"),
            'class': 'src'
          }));
        });
      });
    },

    searchTypeChange: function () {
      jQuery('body').on('change.merge_tickets', '#search-type', function(){
        jQuery('.searchticket').hide();
        jQuery('.merge_results').hide();
        var type = jQuery('#search-type option:selected').val()
        jQuery('.searchticket').each(function(){
          jQuery(this).toggle(jQuery(this).hasClass(type));
        });
        if(jQuery('.'+type).find('.search_merge').val() != "")
          jQuery('#'+type+'_results').show() 
      });
    },

    clickRespIcon: function () {
      jQuery('body').on('click.merge_tickets', '.merge-cont:not(".cont-primary") #resp-icon', function(){
        var id = jQuery(this).closest("#contact-area").find("#merge-ticket").data("id");
        var element = jQuery('.ticketdiv').find("[data-id = '"+id+"']").parent();
        element.find("#resp-icon").removeClass("clicked").parents('li').removeClass("clicked");
        jQuery(this).closest(".merge-cont").remove();
        this.enableContinue();
        this.changeTicketCount();
      });
    },

    ticketDivClick: function () {
      var $this = this;
      jQuery('body').on('click.merge_tickets', '.ticketdiv', function(){
        if(!jQuery(this).find('#resp-icon').hasClass("clicked"))
        {
          jQuery(this).parent().addClass("clicked");
          var element = jQuery(".cont-primary").clone();
          App.Merge.appendToMergeList(element, jQuery(this));
          element.find('.primary-marker').attr('title','Mark as primary').addClass('tooltip');
          var replace_element = element.find('.item_info');
          var title =  replace_element.attr('title');
          var ticket_id = element.find("#merge-ticket").data("id")
          var replace_html = "<a class='item_info' target='_blank' title='"+title+"' href='/helpdesk/tickets/"+ticket_id+"'>"
                                                                                            +replace_element.html()+"</a>"
          replace_element.replaceWith(replace_html);
          $this.enableContinue();
          $this.changeTicketCount();
        }
      });
    },

    lookup: function (searchString, callback) {
      var type = jQuery('#search-type option:selected').val();
      var list =  jQuery('#'+type+'_results').find('ul');
      var search_field = jQuery('#search-type option:selected').val();
      list.empty();
      jQuery('#'+type+'_results').addClass("sloading");
      new Ajax.Request('/search/tickets/filter/'+search_field,
                        { 
                          parameters: {
                            term: searchString,
                          },
                          onSuccess: function(response) {   
                            jQuery('.merge_results:visible').removeClass("sloading");
                            callback(response.responseJSON.results);
                          } 
                        });
    },

    bindAutocompleter: function () {
      var idcachedBackend,requestercachedBackend,subjectcachedBackend;
      var idcachedLookup,requestercachedLookup,subjectcachedLookup;
      var autocompleter_hash = {  id :  { cache : idcachedLookup, backend : idcachedBackend, 
                                          searchBox : 'select-id', searchResults : 'display_id_results',
                                          minChars : 1 },
                                requester :  {  cache : requestercachedLookup, backend : requestercachedBackend, 
                                                searchBox : 'select-requester', searchResults : 'requester_results',
                                                minChars : 2 },
                                subject :  {  cache : subjectcachedLookup, backend : subjectcachedBackend, 
                                              searchBox : 'select-subject', searchResults : 'subject_results',
                                              minChars : 2 }
                              }
      this.afterShow();
      var _this = this;
      jQuery.each(autocompleter_hash, function(){
        this.backend = new Autocompleter.Cache(_this.lookup, {choices: 15});
        this.cache = this.backend.lookup.bind(this.backend);
        App.Tickets.Merge_tickets.global[this.searchBox] = new Autocompleter.PanedSearch( this.searchBox, this.cache, App.Tickets.Merge_tickets.ticketSearch,
        this.searchResults, $A([]), {frequency: 0.1, acceptNewValues: true,
        afterPaneShow: _this.afterShow, minChars: this.minChars, separatorRegEx:/;|,/});
      })
    },

    afterShow: function () {
      var x = jQuery('.ticketdiv');
      x.each(function(){
        var y = jQuery(this);
        jQuery('.merge-cont #merge-ticket').each( function(){
          
          if(jQuery(this).data('id') == y.data('id'))
          {
            y.children('#resp-icon').addClass('clicked');
            y.addClass('clicked').parents('li').addClass('clicked');
          }
        });
      });
    },

    enableContinue: function () {
      if( (jQuery('.merge-cont').hasClass('cont-primary')) && (jQuery('.merge-cont').length > 1) )
        jQuery("#bulk_merge").attr("disabled", false );
      else
        jQuery("#bulk_merge").attr("disabled", true );
    },

    changeTicketCount: function () {
      var subtitle = jQuery('.merge-sub-title');
      var count = ""+jQuery('.merge-cont').length
      var txt = count+(( count == 1 ) ? subtitle.data('defaultText') : subtitle.data('pluralizedText') )
      jQuery('.merge-sub-title').text(txt);
    },

    findOldestTicket: function () {
      var oldestTicket = null;
      var earliestCreatedDate = null;
      jQuery('.merge-cont .merge_element').each(function(index, ele){
        var ele = jQuery(ele),
            createdDate = ele.data('created');
        if(earliestCreatedDate == null || earliestCreatedDate > createdDate){
          earliestCreatedDate = createdDate;
          oldestTicket = ele.parents('.merge-cont');
        }
      });
      return oldestTicket;
    }

  };
}(window.jQuery));
