(function($){
$(document).ready(function(){
    var $clear_text = $('#tag-search-form .clear-text'),
        $tag_search = $("#tag-search");
    $tag_search.autocomplete({
        source: function( request, response ) {
            $.ajax({
                url: "/helpdesk/tags/autocomplete",
                data: { v: request.term },
                success: function(data) {
                    results =  data.results;
                    if (data.results.length==0)
                    {
                        data.results.push({"id":"0", "value": TAGS_INDEX.no_results })
                    }
                    response(
                        $.map( data.results, function( item ) {
                            return {
                                label: item.id,
                                value: item.value
                            }
                        })
                    )
                }
            });
        },
        minLength: 1,
        select: function( event, ui ) {
            if(ui["item"].label!="0")
            {
                var id = ui["item"].label.split("-")[0]
                window.location = "/helpdesk/tags?tag_id="+id;
            }
        },
        open: function(event, ui){
            $(this).removeClass('ui-corner-all');
            $(".ui-menu").addClass("tag-search-results");
            $clear_text.removeClass("hide").addClass("clear-search-results");

        }
    }).data( "autocomplete" )._renderItem = function( ul, item ) {
        return $( "<li></li>" )
            .data( "item.autocomplete", item )
            .append( "<a>" + item.value + "</a>" )
            .appendTo( ul );
    };

    $clear_text.on("click",function(e){

        if($(this).hasClass("clear-search-results"))
        {
            e.preventDefault();
            $tag_search.attr("value","");
            $clear_text.addClass('hide');
        }

    });


    var sort = TAGS_INDEX.sort.split("_");
    $("a[data-wf-order-type="+sort[1]+"]").attr("id","current_order_type");
    var order = $("a[data-wf-order="+sort[0]+"]")
    order.attr("id","current_order");
    $('.current_sort').html(order.html());
    $("#current_order_type").prepend('<span class="icon ticksymbol order"></span>');
    $("#current_order").prepend('<span class="icon ticksymbol ordertype"></span>');


    if($tag_search.attr("value").length==0){
        $(".clear-text").addClass("hide");
    }

    $('.tag-list').on('click.tag_index', '#tag-select-all', function(e) {
      $("#tags-expanded input[type=checkbox]")
            .prop("checked", $(this).prop("checked"))
            .trigger('change');
    });

    $('.tag-list').on('click.tag_index', '.tag_sort', function(e) {
        e.preventDefault();

        $("#tags-list").html("<div class='sloading loading-small loading-block'></div>");
        $('.current_sort').html($(this).html());
        $('#current_order').removeAttr("id");
        $(this).attr("id","current_order");
        if ($(this).data("wf-order") === "activity")
        {
            $("a[data-wf-order-type='desc']").trigger("click");
        }
        else
        {
            $("a[data-wf-order-type='asc']").trigger("click");
        }
    });

    $('.tag-list').on('click.tag_index', '.tag_sort_type', function(e) {
            e.preventDefault();
            $("#tags-list").html("<div class='sloading loading-small loading-block'></div>");
            $("#current_order_type").removeAttr("id");
            $(this).attr("id","current_order_type");
            tag_sort();
        }
    );

    $('.tag-list tbody tr :checkbox').live('change', function() {
        $("#tag-select-all").prop('checked', $('.table tbody tr :checkbox:checked').length == $('.table tbody tr :checkbox').length);
        $('#tag-delete').prop('disabled', $('.table tbody tr :checkbox:checked').length == 0);
    });


    $( "#tag-delete-confirm-submit" ).live('click', function(e) {
        $( "#tag-delete-confirm" ).modal('hide');
        $("#tags-expanded").submit();
    });

    var tag_sort = function(){

        $(".ticksymbol").remove();
        $("#current_order_type").prepend('<span class="icon ticksymbol order"></span>');
        $("#current_order").prepend('<span class="icon ticksymbol ordertype"></span>');
        $.ajax({
            url: "/helpdesk/tags",
            type: "GET",
            dataType: "script",
            data: {
                "sort" : $("#current_order").data("wf-order")+"_"+$("#current_order_type").data("wf-order-type"),
                "name": TAGS_INDEX.name
            }
        });

    }

    $('.tag-list').on('click.tag_index', '.tag_name', function(e) {
       e.preventDefault();

        var tag_id = $(this).parents("tr").data("tagId"),
            $tag_text = $("#tag_text_container_"+tag_id),
            tag_text = $tag_text.children(".textbox");

        $(this).addClass("hide");

        $tag_text.removeClass("hide");
        tag_text.focus();

    } );


    $('.tag-list').on('keydown.tag_index', '.tag_text', function(ev) {
        if(ev.keyCode == 13){
            ev.preventDefault();
            $(this).trigger("change");
        }
    });

    $('.tag-list').on('click.tag_index', '.edittag', function(e){
        var tag_id = $(this).parents("tr").data("tagId");

        var tag_text = $("#tag_text_container_"+tag_id);
        var $tag_name_id = $("#tag_name_"+tag_id)
        if(!$tag_name_id.hasClass("hide"))
        {
            $tag_name_id.addClass("hide");
            tag_text.removeClass("hide");
            tag_text.children(".textbox").focus();
        }
    })



    $('.tag-list').on('focusout.tag_index', '.tag_text', function(e){
        e.stopPropagation();
        var this_tag_text = $(this);
        var tag_id = this_tag_text.parents("tr").data("tagId");
        var tag_name_id = $("#tag_name_"+tag_id)

        if(this_tag_text.attr("value") == tag_name_id.data("tagName") || this_tag_text.attr("value") == "" || this_tag_text.attr("value")==null )
        {
            tag_name_id.removeClass("hide");
            $("#tag_text_container_"+tag_id).addClass("hide");
        }

    });

    $('.tag-list').on('change.tag_index', '.tag_text', function(e) {


        var this_tag_text = $(this)

        var tag_id = this_tag_text.parents("tr").data("tagId");
        var tag_name_id = $("#tag_name_"+tag_id)
        if(!(this_tag_text.attr("value") == tag_name_id.data("tagName") || this_tag_text.attr("value") == "" || this_tag_text.attr("value") == null))
        {
            change_tag_name(tag_id, this_tag_text.attr("value"));
        }

    });

    $('.tag-list').on('click.tag_index', '.removetag', function(ev) {

        var tag_association = $(this) ;
        //TODO:DIALOG remove dialog and convert to Bootstrap dialog
        $( "#tag-remove-confirm" ).dialog({
            resizable: false,
            height:150,
            modal: true,
            buttons: {

                Cancel: {
                    text:"Cancel",
                    class:"btn",
                    style:"margin: 5px;",
                    click:function() {
                        $( this ).dialog( "close" );
                    }
                },

            "Remove": {
                text:"Remove",
                class:"btn btn-primary",
                style:"margin: 5px",
                click:function() {
                    remove_association(tag_association);
                    $( this ).dialog( "close" );
                }
            }

            }
        });


    });

    var remove_association = function(tag_association){

        var count_id = tag_association.parents('td').attr("id")

        //Removing the active Twipsy
        $('.twipsy.in').remove();
        tag_association.remove();

        var this_count_id = $("#"+count_id);
        var tag_type = this_count_id.data("tag-type");
        var tag_id = this_count_id.parents("tr").data("tag-id");
        $.ajax({
            url: "/helpdesk/tags/remove_tag",
            type: "DELETE",
            data: { tag_id: tag_id, tag_type:tag_type  },
            success: function(status){
                this_count_id
                    .removeClass("count")
                    .addClass("muted disabled")
                    .find(".tag-label a ").replaceWith(count_id.split("_")[0]);
                this_count_id.find(".cnt-label").html("0");
                var tag_total = $("tr#helpdesk_tag_"+tag_id).find(".tags-total-counter").html()-status["tag_uses_removed_count"]
                $("tr#helpdesk_tag_"+tag_id).find(".tags-total-counter").html(tag_total);

            }
        });

    }

    var change_tag_name = function(tag_id,tag_name){
        $.ajax({
            url: "/helpdesk/tags/rename_tags",
            type: "PUT",
            data: {tag_id:tag_id, tag_name: tag_name  },
            success: function(status){

                if(status["status"] === "existing_tag" )
                {
                    //TODO:DIALOG remove dialog and convert to Bootstrap dialog
                    $( "#tag-dialog-confirm" ).dialog({
                        resizable: false,
                        height:150,
                        modal: true,
                        buttons: {


                            Cancel: {
                                text:"Cancel",
                                class:"btn",
                                style:"margin: 5px;",
                                click:function() {
                                    $("#tag_text_container_"+tag_id).addClass("hide")
                                        .children(".textbox").attr("value",$("#tag_name_"+tag_id).data("tagName"));
                                    $("#tag_name_"+tag_id).removeClass("hide");
                                    $( this ).dialog( "close" );
                                }
                            },

                            "Merge Tags": {
                                text:"Merge Tags",
                                class:"btn btn-primary",
                                style:"margin: 5px",
                                click:function() {
                                    merge_tags(tag_id,tag_name);
                                    $( this ).dialog( "close" );
                                }
                            }

                        }
                    });
                }
                else
                {
                    var tag_name_id = $("#tag_name_"+tag_id);
                    tag_name_id.data("tagName",status["name"]);
                    var name= status["name"]
                    if( status["name"].length>12)
                    {
                       name=status["name"].slice(0,10)+"..."
                       tag_name_id.addClass("tooltip").attr("title",status["name"]);

                    }
                    tag_name_id.html(name);
                    tag_name_id.removeClass("hide");
                    $("#tag_text_container_"+tag_id).addClass("hide");

                }


            }
        });
    }

    var merge_tags = function(tag_id,tag_name) {
        $.ajax({
            url: "/helpdesk/tags/merge_tags",
            type: "PUT",
            data: {tag_id: tag_id, tag_name: tag_name },
            success: function(status){
                location.replace("/helpdesk/tags");
            }
        });
    }

});
})(jQuery)
