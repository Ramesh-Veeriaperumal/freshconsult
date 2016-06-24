
var AutoSuggest = {
  requester : function(){
          var req_metaobj = jQuery("#meta-req").data();

          function req_lookup(searchString, callback) {
              new Ajax.Request(req_metaobj.url+'?q='+encodeURIComponent(searchString),{
                  method:'GET',
                  onSuccess:  function(response) {
                  var choices = $A();
                  response.responseJSON.results
                  .each(function(item){ 
                  choices.push(item.details);
                  });  

                  _partial_list = jQuery("#helpdesk_ticket_email").data("partialRequesterList") || []
                  jQuery("#helpdesk_ticket_email").data("partialRequesterList", _partial_list.concat(response.responseJSON.results))
                  callback(choices);
                  }
              });
          }

          var req_cachedBackend = new Autocompleter.Cache(req_lookup, {choices: 20});
          var req_cachedLookup = req_cachedBackend.lookup.bind(req_cachedBackend); 

          new Autocompleter.Json(req_metaobj.obj+"_email", req_metaobj.obj+"_email_choices", req_cachedLookup, {
              afterUpdateElement: function(element, choice){      
                _partial_list = jQuery("#helpdesk_ticket_email").data("partialRequesterList")
                _partial_list.each(function(item){    
                  if(element.value == item.details){
                    jQuery('#helpdesk_ticket_requester_id').val(item.id);
                    jQuery('#helpdesk_ticket_email').blur().focus();
                  }
                });
              }
            });

            jQuery("body").on("keyup.newTicket", "#helpdesk_ticket_email", function(){
              jQuery(this).data("requesterCheck", false);
            });
  },

  cc: function(){
            var cc_metaobj = jQuery("#meta-cc").data();

            jQuery('body').on("click.newTicket", "#add_cc_btn", function(ev){
                ev.preventDefault();
                jQuery("#cc_emails_sec").toggle();
                jQuery("#cc_emails").val("");
                jQuery("#cc_emails").trigger("liszt:updated");
              });

            function lookup(searchString, callback) { 
                  new Ajax.Request(cc_metaobj.url+'?q='+encodeURIComponent(searchString), { 
                      method : "GET",
                      onSuccess: function(response) {
                            var choices = $A();
                            response.responseJSON.results.each(function(item){
                                if(item.value == "") {
                                   choices.push([item.details, item.details]);
                                } else {
                                    choices.push([item.details , item.details ]);
                                } 
                            });                                                
                            callback(choices);
                      }
                });
            }
            var cachedBackend = new Autocompleter.Cache(lookup, {searchKey: 0, choices: 10});
            var cachedLookup = cachedBackend.lookup.bind(cachedBackend);

              jQuery("body").on('click.newTicket', "[data-action='show-cc']", function(){
                  jQuery(this).addClass('muted');
                  jQuery('.cc-address').removeClass("hide");
                  
                });
                
                jQuery("body").on('click.newTicket',"[data-action='hide-cc']", function(){
                  jQuery("[data-action='show-cc']").removeClass('muted');
                  jQuery('.cc-address').addClass("hide");
                });

                if(cc_metaobj.isagent){
                    new Autocompleter.MultiValue("cc_emails", cachedLookup, $A(),{
                        frequency: 0.1, 
                        allowSpaces: true,
                        acceptNewValues: true,
                        separatorRegEx:/;|,/
                    });
                }

      }
}