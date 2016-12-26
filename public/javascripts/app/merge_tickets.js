window.App = window.App || {};
window.App.Tickets.Merge_tickets = window.App.Tickets.Merge_tickets || {};

(function ($) {
  "use strict";

  App.Tickets.Merge_tickets = {

    global: {},

    ticketSearch: new Template(
                          '<li><div class="ticketdiv" data-id="#{display_id}">'+
                          '<span id="resp-icon"></span>'+
                          '<div id="merge-ticket" class="merge_element" data-id="#{display_id}" data-req-id="#{requester_id}" data-created="#{created_at_int}">'+
                          '<span class="item_info" title="#{subject}">##{display_id} #{subject}</span>'+
                          '<div class="info-data hideForList">'+
                          '<span class="merge-ticket-info">#{ticket_info}</span>'+
                          '</div></div></div></li>'
                        ),

    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.initialize();
    },
    onLeave: function () {
      jQuery('body').off('.merge_tickets');
      jQuery('#ticket-merge').parent().remove();
    },
    initialize: function(){
      App.Merge.initialize();
      this.bindHandlers();
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
      this.clickCheckbox();
    },

    typedClick: function () {
      jQuery('body').on('click.merge_tickets', '.typed', function(){
        clearSearchField(jQuery(this));
        var type = jQuery('#search-type option:selected').val();
        jQuery('#'+type+'_results').hide();
      });
    },

    searchKeyup: function () {
      jQuery('body').on('keyup.merge_tickets', '.search_merge', function(event){
        if(event.keyCode != 13)
        {
          var search_type = jQuery('#search-type option:selected').val();
          var minChars = ( search_type == "display_id" ) ? 1 : 2
          jQuery('.merge_results').hide();
          if((jQuery(this).val() != "") && (jQuery(this).val().length >= minChars))
          { 
           jQuery('#'+search_type+'_results').show();
          }
          else
          {
           jQuery('#'+search_type+'_results').hide();
          }
        }
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
      var id_info = jQuery('#merge-ticket').data('req-id');
      if(same){
        jQuery(".searchidinfo").data("id-info",id_info);
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
        if(type == 'requester')
        {
          if(jQuery("#select-requester").val() != "") {
            jQuery('#'+type+'_results').show();
          }
        }
        else
        {
          if(jQuery('.'+type).find('.search_merge').val () != ""){
           jQuery('#'+type+'_results').show();
          }
        }
      });
    },

    clickRespIcon: function () {
      var $this = this;
      jQuery('body').on('click.merge_tickets', '.merge-cont:not(".cont-primary") #resp-icon', function(){
        var id = jQuery(this).closest("#contact-area").find("#merge-ticket").data("id");
        var element = jQuery('.ticketdiv').find("[data-id = '"+id+"']").parent();
        element.find("#resp-icon").removeClass("clicked").parents('li').removeClass("clicked");
        jQuery(this).closest(".merge-cont").remove();
        $this.enableContinue();
        $this.changeTicketCount();
        $this.toggleRecipientsCheckbox();
      });
    },

    clickCheckbox: function () {
      jQuery('body').on('mousedown.merge_tickets', '#add_recipients', function () {
        jQuery(this).data('customerCheck', true);
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
          $this.toggleRecipientsCheckbox();
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
      var reqid;
      if(type == 'requester')
      {
        reqid = jQuery('.searchidinfo').data('idInfo');
      }
      list.empty();
      jQuery('#'+type+'_results').addClass("sloading");
      new Ajax.Request('/search/tickets/filter/'+search_field,
      { 
                          parameters: {
                            term: searchString,
                            reqid: reqid,
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
    },

    toggleRecipientsCheckbox: function () {
      if (!jQuery('#add_recipients').data('customerCheck')) {
        jQuery('#add_recipients').attr('checked', this.recipientsCheck());
      }
    },

    recipientsCheck: function () {
      var requesterIds = jQuery.map(jQuery('#merge-content #merge-ticket'), function (el) { return jQuery(el).data('reqId'); });
      return jQuery('#merge-content #merge-ticket').length > 1 && jQuery.unique(requesterIds).length === 1;
    },

    unBindEvent: function () {
      jQuery('body').off('.merge_tickets');
      jQuery('#ticket-merge').parent().remove();
    },

    requesterFieldSearchbox: function(){

     var select2_format = function(result, container, query){
        return result.value;
      }

      var select2_results = function(result, container, query) {
        var display_results = "<b>"+ result.name + "</b>"; 
        var split_info = result.info.split(/<|\(/);
        var detail;
        if(result.info != undefined)
        {
         display_results += "<br><span class='select2_list_detail'>" + result.info + "</span>";
        }
        return display_results;
      }

      jQuery("#select-requester").select2({
        minimumInputLength: 2,
        ajax: {
          url: "/search/autocomplete/requesters",
          dataType: 'json',
          data: function(term){
            var toRet = { q: term };
            return toRet; 
          },
          results: function (data) {
            var results = [];
            var detail_info,searchterm;
            jQuery.each(data.results, function(i,item){
              var split_info = item.details.split(/<|\(/);
              detail_info="";
              if(item.details != undefined)
              {
                if(split_info[1]) {
                  detail_info = split_info[1].slice(0,-1);
                }
                else {
                  detail_info = item.details;
                }
                if(detail_info.length > 25) {
                  detail_info = detail_info.substring(0,26)+ "...";
                }
              }
              searchterm = item.value + '(' + detail_info + ')';
              results.push({id: item.id, value: searchterm, name: item.value, info: detail_info});
            });
            return { results: results }
          }
        },
        specialFormatting: true,
        formatResult: select2_results,
        formatSelection: select2_format,
        width: 'resolve',
      });

      jQuery("#select-requester").on('change', function(e){ 
        var requester_field = jQuery("#select-requester");
        var searchTermEmail = requester_field.select2('data')['value'];
        var id_data =  requester_field.select2('data')['id'];
        jQuery(".searchidinfo").data("id-info",id_data);
        requester_field.val(searchTermEmail).keyup(); 
        if(App.Tickets.Merge_tickets.global['select-requester']){
          App.Tickets.Merge_tickets.global['select-requester'].onSearchFieldKeyDown(42);
        }
      });
    }
  };
}(window.jQuery));
