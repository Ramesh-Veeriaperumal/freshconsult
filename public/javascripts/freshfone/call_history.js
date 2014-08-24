var setCallDuration;
var setLocationIfUnknown,
	blockNumber;
(function ($) {
	"use strict";
	var $freshfoneCallHistory = $('.fresfone-call-history'),
		$filterSortForm = $('#SortFilterCalls'),
		$add_to_blacklist = $('.add_to_blacklist'),
		$filterCondition = $filterSortForm.find('[rel=filter]'),
		$callHistoryBody = $freshfoneCallHistory.find(".list-page-body"),
		$currentPageNumber = $filterSortForm.find("input[name=page]"),
		$filterContainer = $freshfoneCallHistory.find(".ff_item"),
		$currentNumber = $filterSortForm.find("input[name=number_id]"),
		$data_hash = $filterSortForm.find("input[name=data_hash]"),
		$callFilter = $('.call-history-left-filter'),
		$requesterName = $callFilter.find('#requesterName'),
		$callerName = $callFilter.find('#callerName'),
		$requesterId_ffitem = $callFilter.find('#requesterName_choices'),
		$callerId_ffitem = $callFilter.find('#callerName_choices'),
		$groupName = $callFilter.find("#groupName"),
		$groupId_ffitem = $callFilter.find('#groupName_choices'),
		$filterDetails = $freshfoneCallHistory.find("#filterdetails"),
		$fNumberSelect2 = $callFilter.find("#ff_number"),
		$fCallStatusSelect2 = $callFilter.find("#ff_call_status"),
		$filterFreshfoneNumberLabel = $freshfoneCallHistory.find(".filter_freshfone_number"),
		filterString, bindChangeEventForSelect2, data_hash = [];
	
	setLocationIfUnknown = function () {
		$(".location_unknown").each(function () {
			var country = countryForE164Number("+" + $(this).data('number'));
			$(this).html(country);
		});
	};

	$fNumberSelect2.select2({
		dropdownCssClass : 'no-search',
		data: {
			text: 'value',
			results: freshfone.freshfone_number_list},
		formatResult: function (result) {
			if (result.deleted){
				return result.value+"<i class='muted'> (Deleted)</i>"
			} 
			return result.value;
		},
		formatSelection: function (result) {
			$fNumberSelect2.attr('fnumber',result.value);
			$currentNumber.val(result.id);
			return result.value;
		}
	});

	$fCallStatusSelect2.select2({
		dropdownCssClass : 'no-search',
		data:{
			text: 'value',
			results:freshfone.call_status_list
		},
		formatResult: function (result) {
			return result.value;
		},
		formatSelection: function (result) {
			$fCallStatusSelect2.attr('values',result.call_type)
												 .data('value',result.value);
			return result.value;
		}
	});


	$('#requesterName').select2({
			placeholder: 'Agent',
			minimumInputLength: 1,
			multiple: false,
			allowClear: true,
			ajax: {
				url: freshfone.requester_autocomplete_path,
				method: 'GET',
				quietMillis: 1000,
				data: function (term) {
					return {
						q: term
					};
				},
				results: function (data, page, query) {
					if (!data.results.length) {
						return { results: [ { value: query.term, id: ""} ] }
					}
					return {results: data.results};
				}
			},
			formatResult: function (result) {
				var userDetails = result.email || result.mobile || result.phone;
				if(userDetails && $(userDetails).trim != "") {
					userDetails = "(" + userDetails + ")" ;
				}
				return "<b>"+ result.value + "</b><br><span class='select2_list_detail'>" + 
								(userDetails||'') + "</span>"; 
			},
			formatSelection: function (result) {
				$requesterName.val(result.value);
				if(result.id){
					$requesterId_ffitem.attr('values',result.id);
					$requesterId_ffitem.data('value',result.value);
				}
				return result.value;
			}
	});
	
	$requesterName.bind("change", function () {
		if(this.value) { return }
		bindChangeEventForSelect2($requesterId_ffitem);
	});

	$callerName.select2({
				placeholder: 'Caller',
				minimumInputLength: 1,
				multiple: false,
				allowClear: true,
				ajax: {
					url: freshfone.customer_autocomplete_path,
					method: 'GET',
					quietMillis: 1000,
					data: function (term) {
						return {
							q: term
						};
					},
					results: function (data, page, query) {
						if (!data.results.length) {
							return { results: [ { value: query.term, id: ""} ] }
						}
						return {results: data.results};
					}
				},
				formatResult: function (result) {
					var userDetails = result.mobile || result.phone;
					if(userDetails && $(userDetails).trim != "") {
						userDetails = "(" + userDetails + ")";
					}
					return "<b>"+ result.value + "</b><br><span class='select2_list_detail'>" + 
									(userDetails||'') + "</span>"; 
				},
				formatSelection: function (result) {
					$callerName.val(result.value);
					var condition = (result.user_result == undefined) ? 'caller_number_id' : 'customer_id' 
					$callerId_ffitem.attr('condition', condition);
					$callerId_ffitem.attr('values',result.id);
					$callerId_ffitem.data('value',result.value);
					if(!result.id){
						$callerId_ffitem.attr('values',result.value);
					}
					//getFilterData();
					//$filterSortForm.trigger('change');
					return result.value;
				}
		});

	$groupName.select2({
		placeholder: 'Group',
		allowClear: true,
		data: {
			text: 'value',
			results: freshfone.group_list },
		formatResult: function (result) {
			return result.value;
		},
		formatSelection: function (result) {
			$groupName.attr('values',result.id);
			$groupName.data('value', result.value);
			return result.value;
		}
	});

	$callerName.bind("change", function () {
		if(this.value) { return }
		bindChangeEventForSelect2($callerId_ffitem);
	});

	$groupName.bind("change", function () {
		if(this.value) { return }
		bindChangeEventForSelect2($groupName);
	});

	bindChangeEventForSelect2 = function (dataElement) {
		dataElement.data('value','');
		dataElement.attr('values','');
	}
	
	blockNumber = function (number) {
		var $blockedNumbers = $freshfoneCallHistory.find('.blacklist[data-number="' + number + '"]')
			.removeClass('blacklist')
			.addClass('blacklisted');
		$blockedNumbers.attr('title', freshfone.unblockNumberText);
	}

	function getFilterData() {
		setFilterData();
		$currentPageNumber.val(1);
		$filterSortForm.trigger('change');
	}
  
  function setFilterData() {
		var fcondition, container, foperator, fvalues,
		 filterString, data_hash=[], i = 0;
		$filterCondition.empty();
	 	filterString = " Filtered by:  ";
		$filterContainer.map(function (index, ele) {
			fcondition = this.getAttribute("condition");
			container = this.getAttribute("container");
			foperator  = this.getAttribute("operator");
			fvalues  = this.getAttribute("values");
			if(!$(this).data("value").blank()) {
					filterString +="<li>"+$(this).data("filtername") + " : <strong>" + $(this).data("value")+ "</strong></li>   ";
			}
			if (fvalues.blank() || (fvalues == 0) ) { return true; }
			data_hash.push({
				condition : fcondition,
				operator  : foperator,
				value     : fvalues 
			});
			i++;
		});
		$data_hash.val(data_hash.toJSON());
  }

	function setDropdownValue(obj) {
		$(obj)
			.parents('.dropdown:first').find('.filter-name')
			.text($(obj).text());
	}

	// Ordering
	$freshfoneCallHistory.on("click", ".wf_order_type, .wf_order", function (ev) {
		ev.preventDefault();
		$filterSortForm.find("input[name=" + this.className + "]")
			.val(this.getAttribute(this.className))
			.trigger("change");

		$freshfoneCallHistory
			.find("." + this.className + " .ticksymbol").remove();
		$(this).prepend($('<span class="icon ticksymbol"></span>'));

		if (this.className !== 'wf_order_type') { setDropdownValue(this); }
	});
	
	$freshfoneCallHistory.on("click", ".show_delete_number", function (ev) {
		ev.preventDefault();
		ev.stopPropagation();
		$freshfoneCallHistory.find(".deleted_numbers").slideDown();
		$(this).hide();
	});
	// Filtering
	$freshfoneCallHistory.on("click", ".wf_filter", function (ev) {
		ev.preventDefault();
		$($filterContainer[this.getAttribute('data-type')]).attr("values", this.getAttribute(this.className));
		$freshfoneCallHistory
			.find("." + this.className + " .ticksymbol").remove();
		$(this).prepend($('<span class="icon ticksymbol"></span>'));

		setDropdownValue(this);
		$($filterContainer[this.getAttribute('data-type')]).data("value",$(this).data("livalue"));
		//getFilterData();
	});

	$freshfoneCallHistory.on("click","#submitfilter",function(ev) {
		ev.preventDefault();
		getFilterData();
		$("#sliding").trigger("click");
	});

	// Pagination
	$freshfoneCallHistory.on("click", ".pagination a", function (ev) {
		ev.preventDefault();
		$.scrollTo('#calls');
		$filterSortForm.find("input[name=page]")
			.val(getParameterByName("page", this.href))
			.trigger("change");
	});

	$filterSortForm.change(function () {
		$callHistoryBody.html("<div class='loading-box sloading loading-tiny'></div>");
		$.ajax({
			url: freshfone.CALL_HISTORY_CUSTOM_SEARCH_PATH,
			dataType: "script",
			data: $(this).serializeArray(),
			success: function (script) { 
        setFilterDetails();
       }
		});
	});

	$freshfoneCallHistory.on('click', '.child_calls', function () {
		var parent = $(this).parents('tr');
		if ($(this).data('fetch') === undefined) {
			$(this).data('fetch', true);
			parent
				.after("<tr rel='loadingtr'><td colspan='8'><div class='loading-box sloading loading-tiny'></div></td></tr>")
				.addClass('transfer_call');
			$.ajax({
				url: freshfone.CALL_HISTORY_CHILDREN_PATH,
				dataType: "script",
				data: {
					id : $(this).data('id'),
					number_id : $currentNumber.val()  },
				success: function (script) {
					$("[rel='loadingtr']").remove();
				},
				error: function (data) {
					$("[rel='loadingtr']").remove();
					$(this).removeData('fetch');
				}
			});
		} else {
			var children_class = parent.attr('id');
			parent.toggleClass('transfer_call');
			$('.' + children_class).toggle();
		}
	});

	$freshfoneCallHistory.on('click', '.create_freshfone_ticket', function (ev) {
		ev.preventDefault();

		if (freshfoneendcall === undefined) { return false; }
		freshfoneendcall.id = $(this).data("id");
		freshfoneendcall.inCall = false;
		freshfoneendcall.callerId = $(this).data("customer-id");
		freshfoneendcall.callerName = $(this).data("customer-name");
		freshfoneendcall.number = "+" + $(this).data("number");
		freshfoneendcall.date = $(this).data("date");
		freshfoneendcall.showEndCallForm();
	});


	$freshfoneCallHistory.on('click', '.blacklist', function (ev) {
		$('#open-blacklist-confirmation').trigger('click');
		$('#blacklist-confirmation .number')
			.text('+' + $(this).data('number'));
		$('#blacklist_number_number').val($(this).data('number'));
	});

	$freshfoneCallHistory.on('click', '.blacklisted', function (ev) {
		var number = $(this).data('number');
		$freshfoneCallHistory.find('.blacklisted[data-number="' + number + '"]')
			.removeClass('blacklisted')
			.addClass('blacklisting sloading loading-tiny');
		$.ajax({
			url: '/freshfone/blacklist_number/destroy/' + number,
			method: 'POST',
			async: true,
			success: function (data) {
				$freshfoneCallHistory
					.find('.blacklist-toggle.blacklisting[data-number="' + number + '"]')
					.addClass('blacklist')
					.removeClass('sloading loading-tiny blacklisting')
					.attr('title', freshfone.blockNumberText);
			},
			error: function (data) {
				$freshfoneCallHistory
					.find('.blacklist[data-number="' + number + '"]')
					.addClass('blacklisted')
					.removeClass('blacklist')
					.removeClass('sloading loading-tiny');
			}
		});
	});

	$(".list-page-header").ready(function() {
		$("#sliding").slide();
	});

  function setFilterDetails() {
    $filterFreshfoneNumberLabel.text($fNumberSelect2.attr('fnumber'));
    $filterDetails.html(filterString);
  }

	function initSelect2Values() {
		var cached_ffone_number = getCookie('fone_number_id');
		if (cached_ffone_number != undefined){
			var number_object = $.grep(freshfone.freshfone_number_list, function (ele) { return ele.id == cached_ffone_number; })[0];
		}
		number_object = number_object || freshfone.freshfone_number_list[0];
		$fNumberSelect2.select2('data',number_object);
		$fCallStatusSelect2.select2('data',freshfone.call_status_list[0]);
		$("#date_range").val('Today');
	}

	function settingsForDatePicker() {
		var datePickerLabels = freshfone.date_picker_labels[0];
		$("#date_range").attr("values",Date.today().toString("dddd, MMMM dd yyyy"));
		$("#date_range").daterangepicker({
			earliestDate: Date.parse('04/01/2013'),
			latestDate: Date.parse('Today'),
			presetRanges: [
				{text: datePickerLabels['today'], dateStart: 'Today', dateEnd: 'Today' },
				{text: datePickerLabels['yesterday'], dateStart: 'Yesterday', dateEnd: 'Yesterday' },
				{text: datePickerLabels['this_week'], dateStart: 'Today-7', dateEnd: 'Today-1' },
				{text: datePickerLabels['this_month'], dateStart: 'Today-30', dateEnd: 'Today-1'}
			],
			presets: {
				dateRange: datePickerLabels['custom']
			},
			rangeStartTitle: 'From',
			rangeEndTitle: 'To',
			dateFormat: 'dd MM yy',
			closeOnSelect: true,
			onChange: function() {
				$("#date_range").attr("values",$("#date_range").val());
				$("#date_range").data("value",$("#date_range").val());
			}
		});
		$("#date_range").bind('keypress keyup keydown', function(ev) {
			ev.preventDefault();
			return false;
		});
	}

	$(document).ready(function () {
		setLocationIfUnknown();
		initSelect2Values();
		setFilterData();
		setFilterDetails();
		settingsForDatePicker();
	});
}(jQuery));