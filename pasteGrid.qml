import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2

/**********************
/* Parking B - PasteGrid - Paste the selected Harmony texts (i.e. Chord grid) at the end of the score²
/* v1.0.0
/* ChangeLog:
/* 	- 1.0.0: Initial releasee
/**********************************************/


MuseScore {
    menuPath: "Plugins." + pluginName
    description: "Paste the selected grid at the end of the score."
    version: "1.0.0"
    readonly property var pluginName: "Paste Grid"

    requiresScore: true

    onRun: {
        if (curScore == null || curScore.selection == null)
            return [];
        var selection = curScore.selection;
        var el = selection.elements;

        if (el.length == 0) {
            warningDialog.text = "No selection.";
            warningDialog.open();
            return;
        }

        var cursor = curScore.newCursor();

        // 1) Combien de mesure à ajouter
        var measureCount = 0;
        var lastMTick = -1;

        var selFirstTick = tickOf(el[0]);
        var selLastTick = tickOf(el[el.length - 1]);

        //console.log("Looking from ticks: "+selFirstTick+" to "+selLastTick);
        for (var i = selFirstTick; i <= selLastTick; i++) {
            cursor.rewindToTick(i);
            //console.log("Looking at tick: "+i);
            var mTick = cursor.measure.firstSegment.tick;
            //console.log("Current measure starts at tick: "+mTick);
            if (mTick > lastMTick) {
                lastMTick = mTick;
                measureCount++;
            }
        }

        console.log("Measure count: " + measureCount);

        // 2) Extraire les accords de la sélection
        var harmonies = [];
        var hCount = 0;

        for (var i = 0; i < el.length; i++) {
            var element = el[i];
            if (element.type === Element.HARMONY) {
                harmonies.push(element);
                hCount++;
            }

        }

        if (hCount == 0) {
            warningDialog.text = "No harpmonies selected.";
            warningDialog.open();
            return;
        }

        // startCmd(curScore, "Paste Grid");
        // startCmd(curScore, "Select harmonies");

        curScore.selection.clear();
        for (var i = 0; i < harmonies.length; i++) {
            curScore.selection.select(harmonies[i], true);
        }

        // endCmd(curScore, "Select harmonies");

        // 3) Copier, Ajouter les mesures et Paste
        cmd("copy")

        var endTime = curScore.lastSegment.tick;

        startCmd(curScore, "Append measures");

        curScore.appendMeasures(measureCount);

        cursor.rewindToTick(endTime);

        endCmd(curScore, "Append measures");

        startCmd(curScore, "Selecting first added measure");

        curScore.selection.select(cursor.element);

        endCmd(curScore, "Selecting first added measure");

        cmd("paste");

        // endCmd(curScore, "Paste Grid");
        Qt.quit();

    }

    function tickOf(element) {
        var tick = null;
        while (element != null && tick == null) {
            //console.log("analyzing "+element.userName()+": "+((element.tick!==undefined)?element.tick:"undefined"));
            if (element.tick !== undefined) {
                tick = element.tick;
            } else {
                element = element.parent;
            }
        }

        return tick;
    }

    // === TEMPLATE =========================================================
    MessageDialog {
        id: warningDialog
        icon: StandardIcon.Warning
        standardButtons: StandardButton.Ok
        title: 'Warning' + (subtitle ? (" - " + subtitle) : "")
        property var subtitle
        text: "--"
        onAccepted: {
            subtitle = undefined;
            Qt.quit();
        }
    }

    function debugO(label, element, excludes) {

        if (typeof element === 'undefined') {
            console.log(label + ": undefined");
        } else if (element === null) {
            console.log(label + ": null");

        } else if (Array.isArray(element)) {
            for (var i = 0; i < element.length; i++) {
                debugO(label + "-" + i, element[i], excludes);
            }

        } else if (typeof element === 'object') {

            var kys = Object.keys(element);
            for (var i = 0; i < kys.length; i++) {
                if (!excludes || excludes.indexOf(kys[i]) == -1) {
                    debugO(label + ": " + kys[i], element[kys[i]], excludes);
                }
            }
        } else {
            console.log(label + ": " + element);
        }
    }

    function startCmd(score, comment) {
        score.startCmd();
        console.log(">>>>>>>>>> START CMD " + (comment ? ("(" + comment + ") ") : "") + ">>>>>>>>>>>>>>>>>");
    }

    function endCmd(score, comment) {
        score.endCmd();
        console.log("<<<<<<<<<< END CMD " + (comment ? ("(" + comment + ") ") : "") + "<<<<<<<<<<<<<<<<<");
    }

}