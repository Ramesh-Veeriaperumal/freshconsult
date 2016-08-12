/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};

(function ($) {
  "use strict";
  
  App.Tickets.CannedResponse = { 
    init: function () {
      this.bindEvents();
      simpleTimedSearch("#searchbox", ca_responses_search_url, 2000);

      this.loadRecent();

      jQuery('<div id="cf_cache" class="hide"></div>').appendTo('body');

      jQuery('#canned_response_list a').first().click();
    },
    bindEvents: function (){
      jQuery('#searchbox').bind('keyup', function (ev) {
        if(ev.keyCode >= 46 && ev.keyCode <= 90 || ev.keyCode == 8)
        {
          jQuery('#clear-search').show();
          jQuery('#search-list').show();
          jQuery('#fold-list').hide();
          jQuery('#search-list').empty().append("<div class='sloading loading-align'></div>");
        }
      });

      jQuery(document).on('click.ticket_details', ".item_info", function(){
        jQuery(".item_info").removeClass('folderSelected');
        var a = jQuery(this).data('folder');
        jQuery('[data-folder=' + a + ']').addClass('folderSelected');
      });

      if (jQuery('#fold-list .small-list-left').children().hasClass('list-noinfo'))
      {
        localStorage.removeItem('local_ca_response');
        jQuery('#response_dialog').addClass('no_folders');
      }

      jQuery(document).on('click.ticket_details', '.folderSelected', function(ev){
      ev.preventDefault();
      });

      jQuery(document).on('click.ticket_details', '[data-response]', function(ev){
        ev.preventDefault();
        var id = jQuery(this).data('response');
        var recId = [];
        if (!localStorage["local_ca_response"] ) 
        {
          localStorage["local_ca_response"] = recId;
        }
        else
        {
          recId = jQuery.parseJSON('[' + localStorage["local_ca_response"] + ']')
        }
        for(var i = 0; i < recId.length;i++)
        {
          if(recId[i] == id)
          {
            recId.splice(i,1);
          }
        }
        recId.reverse();
        recId.push(id);   
        recId.reverse(); 
        if(recId.length >= 8)
        {
          recId.splice(8);
        }
        localStorage["local_ca_response"]=recId.toString();
      });

      jQuery("#clear-search").bind('click', function(){
        jQuery("#searchbox").val('');
        jQuery('#search-list').hide();
        jQuery('#fold-list').show();
        jQuery(this).hide();
      });

    },
    loadRecent: function() {
      if(!localStorage["local_ca_response"])
      {
        jQuery('#recently_used_container').hide();
      }
      else
      {
        jQuery('#recently_used_container').show();
        jQuery('#response_dialog').removeClass('no_recently_used');
        jQuery('#recently_used_list').empty().addClass('sloading loading-small');
        new Ajax.Request(ca_responses_recent_url+'&ids=['+localStorage["local_ca_response"]+']', 
          {
            asynchronous: true,
            evalScripts: true,
            method: 'get'
          });   
      }
    },
    unBindEvents: function () {
      jQuery(document).off('.ticket_details')
    }
  }

 // jQuery('[data-folder]').bind('click', function(){
    //jQuery('#responses').empty().addClass('sloading loading-small');
  //});

}(window.jQuery));