# Flight deck printer

var myprops = {};
myprops.base = props.globals.getNode('instrumentation/printer', 1);
myprops.queue = myprops.base.getNode('job-queue', 1);
myprops.paper = myprops.base.getNode('paper', 1);
myprops.history = myprops.base.getNode('history', 1);
myprops.printing = myprops.base.getNode('printing', 1);
myprops.clipIndex = myprops.base.getNode('clipIndex', 1);
myprops.clipIndex.setValue(0);
myprops.printing.setBoolValue(0);

paperWidth = getprop('instrumentation/printer/config/paper-width') or 32;

var newJob = func(txt) {
    var job = myprops.queue.addChild('job');
    var rawLines = [];
    if (typeof(txt) == 'scalar')
        rawLines = split("\n", txt);
    elsif (typeof(txt) == 'vector')
        rawLines = txt;
    else
        rawLines = [debug.string(txt)];
    foreach (var rawLine; rawLines) {
        while (utf8.size(rawLine) > paperWidth) {
            var line = utf8.substr(rawLine, 0, paperWidth);
            job.addChild('line').setValue(line);
            rawLine = utf8.substr(rawLine, paperWidth);
        }
        job.addChild('line').setValue(rawLine);
    }
};

var discard = func (n) {
    var sheet = myprops.history.getNode('sheet[' ~ n ~ ']');
    if (sheet != nil)
        sheet.remove();
};

var paperCanvas = canvas.new({
    "name": "paper",
    "size": [1024, 1024],
    "view": [1024, 1024],
    "mipmapping": 1
});
paperCanvas.setColorBackground(1, 1, 1, 0);
var paperGroup = paperCanvas.createGroup('paper');
paperGroup.createChild('path')
    .rect(0, 0, 1024, 10240).setColorFill(1, 1, 1, 1);
var textGroup = paperGroup.createChild('group');
var feedStep = 48;
var feed = 1024 - feedStep;
var nextTxtY = 64;
var fontSize = 24;
paperGroup.setTranslation(0, feed);

var clipboardCanvas = canvas.new({
    "name": "clipboard",
    "size": [1024, 4096],
    "view": [1024, 4096],
    "mipmapping": 1
});
clipboardCanvas.setColorBackground(1, 1, 1, 0);
var clipboardGroup = clipboardCanvas.createGroup('clipboard');
var clipboardPaper = clipboardGroup.createChild('path').setColorFill(1, 1, 1, 1);
var clipTextGroup = clipboardGroup.createChild('group');

var updateClipboard = func {
    var index = myprops.clipIndex.getValue();
    var sheet = myprops.history.getNode('sheet[' ~ index ~ ']');
    clipboardPaper.reset();
    clipTextGroup.removeAllChildren();
    if (sheet != nil) {
        var lines = sheet.getValues()['line'];
        debug.dump(lines);
        if (lines != nil) {
            if (typeof(lines) == 'scalar') {
                lines = [lines];
            }
            var h = feedStep * (size(lines) + 4);
            clipboardPaper.rect(0, 0, 1024, h);
            var y = feedStep * 3;
            foreach (var line; lines) {
                clipTextGroup.createChild('text')
                    .setText(line)
                    .setFontSize(fontSize, 1)
                    .setTranslation(256, y)
                    .setColor(0, 0, 0, 1);
                y += feedStep;
            }
        }
    }
};

var clipboardNext = func {
    var sheets = myprops.history.getChildren('sheet');
    var index = myprops.clipIndex.getValue();
    index += 1;
    if (index >= size(sheets)) {
        index = 0;
    }
    myprops.clipIndex.setValue(index);
    me.updateClipboard();
};

var clipboardPrev = func {
    var sheets = myprops.history.getChildren('sheet');
    var index = myprops.clipIndex.getValue();
    index -= 1;
    if (index < 0) {
        index = math.max(size(sheets) - 1, 0);
    }
    myprops.clipIndex.setValue(index);
    me.updateClipboard();
};


var cutPaper = func {
    var values = myprops.paper.getValues();
    if (values != nil) {
        var sheet = myprops.history.addChild('sheet');
        sheet.setValues(myprops.paper.getValues());
        var index = sheet.getIndex();
        myprops.clipIndex.setValue(index);
        updateClipboard();
    }
    myprops.paper.removeAllChildren();
    feed = 1024 - feedStep;
    nextTxtY = 3 * feedStep;
    paperGroup.setTranslation(0, feed);
    textGroup.removeAllChildren();
};

var update = func {
    var jobs = myprops.queue.getChildren('job');
    if (size(jobs) == 0) {
        myprops.printing.setBoolValue(0);
        return;
    }
    else {
        myprops.printing.setBoolValue(1);
    }
    var job = jobs[0];
    var lines = job.getChildren('line');
    if (size(lines) == 0) {
        job.remove();
        return;
    }
    var line = lines[0].getValue();
    lines[0].remove();
    myprops.paper.addChild('line').setValue(line);

    textGroup.createChild('text')
        .setText(line)
        .setFontSize(fontSize, 1)
        .setTranslation(216, nextTxtY)
        .setColor(0, 0, 0, 1);
    nextTxtY += feedStep;
    feed -= feedStep;
    paperGroup.setTranslation(0, feed);
};

var printTimer = maketimer(0.5, update);
printTimer.simulatedTime = 1;

var initialized = 0;

setlistener("sim/signals/fdm-initialized", func {
    if (!initialized) {
        initialized = 1;
        paperCanvas.addPlacement({"node": "paper"});
        clipboardCanvas.addPlacement({"node": "clipPaper"});
        printTimer.start();
    }
});