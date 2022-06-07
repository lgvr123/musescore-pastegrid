import QtQuick 2.9
import QtQuick.Controls 2.2
import MuseScore 3.0
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.2

/**********************
/* Parking B - PasteGrid - Paste the selected Harmony texts (i.e. Chord grid) at the end of the score²
/* v1.1.0
/* ChangeLog:
/* 	- 1.0.0: Initial releasee
/* 	- 1.1.0: Paste line breaks too
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

        var harmonies = [];
        var infos = [];
        var linebreaks = [];

        // 1) Combien de mesure à ajouter
        var cursor = curScore.newCursor();
        var measureCount = 0;
        var hCount = 0;
        var lastMTick = -1;

        var selFirstTick = tickOf(el[0]);
        var selLastTick = tickOf(el[el.length - 1]);

        cursor.rewindToTick(selFirstTick);
        var segment = cursor.segment;
        while (segment && (segment.tick <= selLastTick)) {
            // 1) Searching for texts
            var annotations = segment.annotations;
            //console.log(annotations.length + " annotations");
            if (annotations && (annotations.length > 0)) {
                for (var j = 0; j < annotations.length; j++) {
                    var ann = annotations[j];
                    //console.log("  (" + i + ") " + ann.userName() + " / " + ann.text + " / " + ann.harmonyType);
                    if (ann.type === Element.HARMONY) {
                        harmonies.push(ann);
                        hCount++;
                        console.log("found " + ann.text + " at " + segment.tick + "/" + ann.track);
                    } else if (ann.type === Element.STAFF_TEXT || ann.type === Element.SYSTEM_TEXT) {
                        infos.push(ann);
                    }
                }
            }

            // 2) counting the measures and searching for line breaks
            var measure = segment.parent;
            var mTick = measure.firstSegment.tick; // segment.parent = measure
            //console.log("Current measure starts at tick: "+mTick);
            if (mTick > lastMTick) {
                lastMTick = mTick;
                measureCount++;

                var melements = measure.elements;

                for (var j = 0; j < melements.length; j++) {
                    var mel = melements[j];
                    if (mel.type === Element.LAYOUT_BREAK) {
                        linebreaks[measureCount - 1] = mel.layoutBreakType;
                        console.log("linebreak found at measure " + (measureCount));
                    }
                }
            }

            segment = segment.next;

        }

        console.log("Measure count: " + measureCount);
        console.log("Harmonies count: " + harmonies.length);
        console.log("Linebreaks count: " + linebreaks.filter(function (e) {
                return e !== undefined
            }).length);
        console.log("Misc. elements count: " + infos.length);

        if (hCount == 0) {
            warningDialog.text = "No harmonies selected.";
            warningDialog.open();
            return;
        }

        // 2) reselectiong what can be copy/pasted
        curScore.selection.clear();
        for (var i = 0; i < harmonies.length; i++) {
            curScore.selection.select(harmonies[i], true);
        }
        for (var i = 0; i < infos.length; i++) {
            console.log("selecting " + infos[i].userName());
            // Rem: Throws a warning when dealing with linebreaks "Cannot select element of type LayoutBreak"
            curScore.selection.select(infos[i], true);
        }

        // 3) Copier, Ajouter les mesures et Paste
        cmd("copy")

        var endTime = curScore.lastSegment.tick;

        startCmd(curScore, "Append measures");

        // -- a linebreak at the end, before the new measures
        cursor.rewindToTick(endTime - 1);
        var lbreak = newElement(Element.LAYOUT_BREAK);
        lbreak.layoutBreakType = 1;
        cursor.add(lbreak);

        // -- empty measures
        curScore.appendMeasures(measureCount);

        endCmd(curScore, "Append measures");

        startCmd(curScore, "Paste Grid");

        // -- a double bar
        var bar = cursor.measure.lastSegment.elementAt(0);
        if (bar.type == Element.BAR_LINE) {
            console.log(Object.keys(bar).filter(function (e) {
                    return e.charAt(0) === 'b'
                }));
            bar.barlineType = 2;
            console.log("Last element is a barline (type=" + bar.userName() + ")");
        } else {
            console.log("Last element is not a barline (type=" + bar.userName() + ")");
        }

        // -- pasting the re-selection
        cursor.rewindToTick(endTime);
        curScore.selection.select(cursor.element);

        cmd("paste");

        cursor.rewindToTick(endTime);

        // -- copying the line breaks
        var measure = cursor.measure;
        for (var i = 0; (i < linebreaks.length) && measure; i++) {
            var lbt = linebreaks[i];
            console.log("layoutBreakType at measure " + i + ": " + lbt);
            if (lbt !== undefined) {
                console.log("adding a break at measure " + i);
                cursor.rewindToTick(measure.lastSegment.tick);
                var lbreak = newElement(Element.LAYOUT_BREAK);
                lbreak.layoutBreakType = lbt;
                cursor.add(lbreak);
            }
            measure = measure.nextMeasure;
        }

        endCmd(curScore, "Paste Grid");
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