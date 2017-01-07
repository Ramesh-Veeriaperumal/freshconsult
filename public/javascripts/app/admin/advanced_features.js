/*jslint browser: true */
/*global  App */

window.App = window.App || {};
window.App.Admin = window.App.Admin || {};
(function ($) {
    "use strict";

    App.Admin.AdvancedFeatures = {
        onVisit: function () {
            this.bindHandlers();
        },

        bindHandlers: function () {
            this.bindToggleFeatureCheckbox();
            this.bindConfirmButton();
            this.bindCancelButton();
        },

        bindToggleFeatureCheckbox: function () {
            var $this = this;
            $('body').on('change.advanced_features', '.feature-switch', function () {
                $(this).val() === "true" ? $this.confirmAction(this) : $this.performAction(this, true);
            });
        },

        performAction: function (element, checked) {
            $.ajax({
                type: "PUT",
                url: $(element).data('url'),
                data: { feature_name: $(element).data('feature-name')}
            });
        },

        confirmAction: function (element) {
            var confirm_text = $(element).data('confirm'),
                data = {
                    targetId : '#confirm-action',
                    title : "Confirm",
                    submitLabel : "Confirm",
                    width : '500'
                };
            $.freshdialog(data);
            $('#confirm-action .modal-body').html(
                "<div id='modal-content' data-target='#confirm-action'>" + confirm_text + "</div><div class='hide' id='feature_name'>" + $(element).data('feature-name') + "</div>"
            );
        },

        bindConfirmButton: function () {
            var $this = this;
            $(document).on('click', '#confirm-action-submit', function () {
                var element = '#check_' + $('#feature_name').text();
                $this.performAction(element, false);
                $('.modal-header .close').trigger('click');
                $('#confirm-action').remove();
            });
        },

        bindCancelButton: function () {
            var $this = this;
            $(document).on('click', '#confirm-action-cancel', function () {
                var element = '#check_' + $('#feature_name').text();
                $(element).prop('checked', true).parent().find('.toggle-button').addClass('active');
                $('#confirm-action').remove();
            });
        },

        unbindHandlers: function () {
            $('body').off('.advanced_features');
        },

        onLeave: function () {
            this.unbindHandlers();
        }
    };
}(window.jQuery));
