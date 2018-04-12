/* ************************************************************************
   Copyright: 2018 Tobias Oetiker
   License:   ???
   Authors:   Tobias Oetiker <tobi@oetiker.ch>
 *********************************************************************** */

/**
 * Main application class.
 * @asset(bdass/*)
 *
 */
qx.Class.define("bdass.Application", {
    extend : callbackery.Application,
    members : {
        main : function() {
            // Call super class
            this.base(arguments);
        }
    }
});
