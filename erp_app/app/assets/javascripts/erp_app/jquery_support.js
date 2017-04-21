// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require_self

if (jQuery) {
    Compass.ErpApp.Utility.createNamespace("Compass.ErpApp.JQuerySupport");

    jQuery(document).ready(function() {
        Compass.ErpApp.JQuerySupport.setupHtmlReplace();
        Compass.ErpApp.JQuerySupport.setupProgressBars();
    });

    Compass.ErpApp.JQuerySupport.setupHtmlReplace = function() {
        jQuery(document).unbind('ajaxSuccess', Compass.ErpApp.JQuerySupport.handleHtmlUpdateResponse).bind('ajaxSuccess', Compass.ErpApp.JQuerySupport.handleHtmlUpdateResponse);
    };

    Compass.ErpApp.JQuerySupport.handleHtmlUpdateResponse = function(e, xhr, options, data) {
        var utility = Compass.ErpApp.Utility;

        //reset SessionTimeout
        if (utility.SessionTimeout.enabled) {
            utility.SessionTimeout.reset();
        }
        if (!utility.isBlank(data) && !utility.isBlank(data.htmlId)) {

            var updateDiv = $('#' + data.htmlId);
            try {
                updateDiv.closest('div.compass_ae-widget').unmask();
            } catch (ex) {
                //messy catch for no update div
            }

            updateDiv.html(data.html);

            Compass.ErpApp.JQuerySupport.setupProgressBars();
        }
    };

    Compass.ErpApp.JQuerySupport.setupProgressBars = function() {
        Compass.ErpApp.JQuerySupport.removeProgressBar();

        $('[data-progress-bar="true"]').on('ajax:send', Compass.ErpApp.JQuerySupport.showProgressBar);
    };

    Compass.ErpApp.JQuerySupport.showProgressBar = function() {
        if ($('#progressBar').length === 0) {
            $(
                '<div class="modal fade" id="progressBar" data-backdrop="static" data-keyboard="false" tabindex="-1" role="dialog" aria-hidden="true" style="padding-top:15%; overflow-y:visible;">' +
                '<div class="modal-dialog modal-m" style="z-index:2000;">' +
                '<div class="modal-content">' +
                '<div class="modal-header"><h3 style="margin:0;">Loading ...</h3></div>' +
                '<div class="modal-body">' +
                '<div class="progress progress-striped active" style="margin-bottom:0;"><div class="progress-bar" style="width: 100%"></div></div>' +
                '</div>' +
                '</div></div></div>').appendTo(document.body);
        }

        $('#progressBar').modal();

        $(document).on('ajax:success', Compass.ErpApp.JQuerySupport.removeProgressBar);
    };

    Compass.ErpApp.JQuerySupport.removeProgressBar = function() {
        $('#progressBar').modal('hide');
        $(document).off('ajax:success', Compass.ErpApp.JQuerySupport.removeProgressBar);
    };

}