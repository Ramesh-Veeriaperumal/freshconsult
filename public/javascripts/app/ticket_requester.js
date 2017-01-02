/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Tickets = window.App.Tickets || {};
(function ($) {
	"use strict";

	var invalidCompanyName = false,
				      companyErrorMessage,
				      company_changed = false;

	 App.Tickets.TicketRequester = {
    current_module: '',
    init: function(){
    	this.bindEvents();
    	$("input[name='contact[tag_names]']").data('allowCreate',TICKET_DETAILS_DATA['create_tag_privilege']).attr('rel','remote-tag');
    },
    initPopup: function(){
    	var _this = this;
    	this.bindPopupEvents();

    	var $requiredEle = '<span class="required_star">*</span>',tooltipText;
		      $(".requester-widget-user-fields .field-set label").each(function(){
		      	tooltipText = ($(this).text()).replace(/\w\S*/g, function(txt){return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});;
		        if(tooltipText.length > 14){
		          $(this).attr('title',tooltipText);
		          $(this).addClass('tooltip');
		        }
		      });

		      $(document).find('#company_section .required_star').remove();

		      $('#company_section input.compare-required,#company_section select.compare-required,#company_section textarea.compare-required,#company_name').not('.checkbox').data('compare','company_name')
			    .closest('li')
			    .find('.control-label')
			    .append($requiredEle);

			    $('#company_section input.checkbox.compare-required+label').append($requiredEle)


    	var cachedBackend = new Autocompleter.Cache(this.lookup, {choices: 20});
			 var cachedLookup = cachedBackend.lookup.bind(cachedBackend);

			  if($('#company_name').length) {
			    new Autocompleter.Json("company_name", "company_name_choices", cachedLookup, {
			      afterUpdateElement: function(element, choice){
			        var _partial_list = $("#company_name").data("partialCompanyList");
			        _this.companyNameChanged();
			        element.blur();
			      }
			    });
			  }

			  // requester widget form validation
				  $('#requester-widget-user-edit-dialog form').validate({
				    ignore: ':hidden:not(:checkbox)',
				    errorPlacement:function(error,ele){
				        if(ele.hasClass('checkbox')){
				          ele.find('+label').find(error).remove();
				          error.addClass('checkbox-error-message').insertAfter(ele.find('+label'));
				        }else{
				          error.insertAfter(ele);
				        }
				      }
				  });


    },
		bindErrorMessage : function(ele,message){ // bind company name message 
			var companyErrorField = $('.company-error-msg');
	    if(companyErrorField.length === 0){
	      companyErrorField = $('<span class="company-error-msg">' + message + '</span>');
	    }else{
	      companyErrorField.text(message);
	    }
	      ele.after(companyErrorField);
	  },
	  toggleLoadingSymbol : function(show,for_elt) {
	  	var elements = (for_elt == "") ? $(".requester-widget-user-edit-dialog [id$='_loading']").not("#company_name_loading,#company_domains_loading") : $(".requester-widget-user-edit-dialog [id='" + for_elt + "_loading']");
      elements.toggleClass('sloading loading-small');

    	this.companyFieldsExceptName().each(function(){
    		jQuery(this).prop('disabled',show);
    	});
	  },
	  lookup : function(searchString, callback) {
	  	var _this = App.Tickets.TicketRequester;
	    _this.toggleLoadingSymbol(true, 'company_name');
	    new Ajax.Request(TICKET_DETAILS_DATA['companies_autocomplete_path'] + encodeURIComponent(searchString),
	    {
	      method:'GET',
	      onSuccess:  function(response) {
          var choices = [],
            $companyName = $("#company_name");
          response.responseJSON.results
            .each(function(item){
              choices.push(item.value);
            });

          var _partial_list = $companyName.data("partialCompanyList") || [];

          $companyName.data("partialCompanyList", _partial_list.concat(response.responseJSON.results));

          callback(choices);
          _this.toggleLoadingSymbol(false, 'company_name');
          if(response.responseJSON.results.length === 0){
              _this.bindErrorMessage($('#company_name'),TICKET_DETAILS_DATA['new_company_message']);
          }else{
            invalidCompanyName=false;
          }
        }
	    });

	  },
	  companyNameChanged : function() {
	    if(!invalidCompanyName){
	      company_changed = true;
	    }
	  },
	  toggleRequesterEdit : function(enable){
	    if(enable) {
	      $('#requester-widget-user-edit-dialog-submit').removeAttr('disabled');
	      $('.requester-widget-user-edit-dialog .controls label.error').not('.company-error-msg').remove();
	    }
      else {
        $('#requester-widget-user-edit-dialog-submit').attr('disabled', 'true');
      }
	  },
	  companyFieldsExceptName : function() {
	    return $('.requester-widget-user-edit-dialog :input[id^="company"]').not('#company_name');
	  },
	  clearCompanyFieldValues : function(){
	    var modified_fields = [],
	    	old_value;
	    this.companyFieldsExceptName().each(function(){
	        if($(this).is(':checkbox')) {
	          $(this).removeAttr("checked");
          }
	      else {
	        old_value = $(this).val();
          if($(this).hasClass('date')) {
            $(this).val("").datepicker().trigger('change');
          }
          else {
          	$(this).val("").trigger('change');
          }
	        if(old_value != "") {
            if($(this).hasClass('select2')) {
              modified_fields.push($(this).parent('.controls').children(".select2-container")[0]);
            }
            else {
              modified_fields.push(this);
            }
	        }
	      }
	    });
	    this.highlightModifiedFields(modified_fields);
	  },
	  fetchCompanyDetails : function(company_name) {
	  	var _this = this;
	    this.toggleLoadingSymbol(true,"");
	    new Ajax.Request('/helpdesk/commons/fetch_company_by_name?name=' + encodeURIComponent(company_name),
	      {
	          method: 'GET',
	          onSuccess: function(response) {
	            if(company_name == $('#company_name').val()) { // to prevent DOM change between consecutive blur events
	              var company_JSON = response.responseJSON.company,
	              	company_details,
	              	item_id,
	              	item_name,
	              	old_value,
	              	modified_fields;
	              if(company_JSON) {
	                company_details = JSON.flatten(company_JSON),
	                	modified_fields = [];
	                _this.companyFieldsExceptName().each(function(){
	                    item_id = this.id;
	                  item_name = item_id.substring(item_id.indexOf('_')+1, item_id.length);
	                  if($(this).is(':checkbox')){
	                    company_details[item_name] ? $(this).attr("checked", "checked") : $(this).removeAttr("checked");
	                  }
	                  else {
	                    old_value = $(this).val();
	                    if($(this).hasClass('date')){
	                      company_details[item_name] ? $(this).datepicker('setDate', new Date(company_details[item_name])).trigger('change') : $(this).val("").datepicker().trigger('change');
	                    }
	                    else{
	                      $(this).val(company_details[item_name]).trigger('change');
	                    }
	                    if(old_value != $(this).val()) {
	                      if($(this).hasClass('select2')) {
	                        modified_fields.push($(this).parent('.controls').children(".select2-container")[0]);
	                      }
	                      else{
	                        modified_fields.push(this);
	                      }
	                    }
	                  }
	                });
	                _this.highlightModifiedFields(modified_fields);
	                _this.bindErrorMessage($('#company_name'),TICKET_DETAILS_DATA['company_message']);
	              } else {
	                _this.bindErrorMessage($('#company_name'),TICKET_DETAILS_DATA['new_company_message']);
	                _this.clearCompanyFieldValues();  
	              }
	              _this.toggleRequesterEdit(true);
	              _this.toggleLoadingSymbol(false,"");
	            }
	          }
	      });
	  },
	  highlightModifiedFields : function(fields) {
	    $(fields).stop().animate({
	      backgroundColor: "#FFFBCC"
	      }, 200, function(){
	      $(fields).stop().animate({
	        backgroundColor: "#fff"
	      }, 800);
	    });
	  },
	  openCompanySection : function(){
	  	var $companyName = $('#company_name'),
			 		$companySection = $('.company-field-section'),
			 		_this = this;
			 	if($('#add-company').is(':checked')){
			 		$companySection.slideDown(200,function(){
			 			$companyName.focus();
			 		});	
			 	}else{
			 		$companySection.slideUp(200, function(){
			 			_this.clearCompanyFieldValues();
				 		$('.company-error-msg').remove();
				 		$companyName.val('').blur();
			 		});
			 	}
	  },
	  bindPopupEvents: function(){
	  	var $doc = $(document), 
					_this = this;
			
			 /* requester widget contact edit bindevents start */

			 $doc.on('change.popuprequester', '#add-company' ,function(){
			 	_this.openCompanySection();
			 });

			 $doc.on('click.popuprequester','.add-company-title',function(){
			 	var $addCompany = $('#add-company');
			 	$addCompany.prop('checked',!($addCompany.is(':checked'))).trigger('change');
			 });

			  $doc.on('focus.popuprequester', '#company_name' ,function(){
			    company_changed = false;
			    _this.toggleRequesterEdit(false);
			  });

			  $doc.on('input.popuprequester', '#company_name' , function(e){
			   	company_changed = true;
			  });

			  $doc.on('blur.popuprequester', '#company_name' , function(){
			    if(company_changed){
			      var company_name = $('#company_name').val();
			      if(company_name.length > 0) {
			        _this.fetchCompanyDetails(company_name);
			          return;
			      }
			      else {
			        _this.clearCompanyFieldValues();
			        $('.company-error-msg').remove();
			      }
			    }
			    _this.toggleRequesterEdit(true);
			  });

			  $doc.on('change.popuprequester', '#requester-widget-user-edit-dialog .controls input.date' , function(){
			      if($(this).val() == "undefined" || $(this).val() == null || $(this).val() == "") {
			          $(this).parent('.controls').children('span.dateClear').hide();
            }
			      else {
			          $(this).parent('.controls').children('span.dateClear').show();
            }
			  });
			 /* requester widget contact edit bindevents end */
	  },
	  bindEvents: function(){
			var $doc = $(document), 
					_this = this;

	  	/* requester info start */
	  	$doc.on('click.requester','.requester_widget span.widget-more-toggle',function(){
        var $ele = $(this);
        if($ele.hasClass('condensed')){
          $ele.parents('.requester_widget').find('div.widget-more-content').slideDown('fast','easeInQuad');
          $ele.removeClass('condensed').text(TICKET_DETAILS_DATA['less_requester']);
        } else {
          $ele.addClass('condensed').parents('.requester_widget').find('div.widget-more-content').slideUp('fast','easeOutQuad');
            $ele.text(TICKET_DETAILS_DATA['more_requester']);
        }
      });

	    $doc.on('click.requester','.requester_widget span.more-toggle',function(){
	      var toggle = $(this).parent();
	      if(toggle.hasClass('expanded')){
	        toggle.find('.hidden-text').hide();
	        toggle.removeClass('expanded');
	      }else{
	        toggle.addClass('expanded');
	        toggle.find('.hidden-text').fadeIn("slow");
	      }
	    });

	    $doc.on("show.requester", "#requester-widget-user-edit-dialog", function(e){
	    	_this.unBindPopupEvents();
		    _this.initPopup();
	    });

	    $doc.on("hidden.requester", "#requester-widget-user-edit-dialog", function(e){
		    _this.unBindPopupEvents();
	    });
	    /* requester info end */
		},
    unBindEvents: function(){
    	$(document).off(".popuprequester.requester");
    },
    unBindPopupEvents: function(){
    	$(document).off(".popuprequester")
    }
	};

	  // utility to flatten JSON data to enable easier DOM manipulation
  JSON.flatten = function(data) {
    var result = {};
    function recurse (cur, prop) {
      if (Object(cur) !== cur) {
        result[prop] = cur;
      } else if (Array.isArray(cur)) {
        for(var i=0, l=cur.length; i<l; i++)
          recurse(cur[i], prop + "[" + i + "]");
        if (l == 0)
          result[prop] = [];
      } else {
        var isEmpty = true;
        for (var p in cur) {
          isEmpty = false;
          recurse(cur[p], prop ? prop+"_"+p : p);
        }
        if (isEmpty && prop)
          result[prop] = {};
      }
    }
    recurse(data, "");
    return result;
  }; 
}(jQuery));
