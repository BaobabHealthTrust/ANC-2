
function createMultipleSelectControl(){
    if(__$("keyboard")){

    //   __$("keyboard").style.display = "none";
    }

    if(__$("viewport")){
        __$("viewport").style.display = "none";
    }

    if(__$("touchscreenInput" + tstCurrentPage)){
        __$("touchscreenInput" + tstCurrentPage).style.display = "none";
    }

    var parent = document.createElement("div");
    parent.id = 'parent' + tstCurrentPage;
    parent.style.width = "100%";
    if (selectAll && selectAll == true){
        parent.style.height = 0.71 * screen.height + "px";
    }else{
        parent.style.height = 0.77 * screen.height + "px";
    }
    parent.style.borderRadius = "10px";
    parent.style.marginTop = "0px";
    parent.style.marginBottom = "0px";
    parent.style.overflow = "auto";
    __$("inputFrame" + tstCurrentPage).style.width = "96%";

    __$("inputFrame" + tstCurrentPage).appendChild(parent);

    var table = document.createElement("div");
    table.style.display = "table";
    table.style.width = "98.5%";
    table.style.margin = "10px";

    parent.appendChild(table);

    var row = document.createElement("div");
    row.style.display = "table-row";

    table.appendChild(row);

    var cell1 = document.createElement("div");
    cell1.style.display = "table-cell";
    cell1.border = "1px solid #666";
    cell1.style.minWidth = "50%";

    row.appendChild(cell1);

    var cell2 = document.createElement("div");
    cell2.style.display = "table-cell";
    cell2.border = "1px solid #666";
    cell2.style.minWidth = "50%";

    row.appendChild(cell2);

    var list1 = document.createElement("ul");
    list1.style.listStyle = "none";
    list1.style.padding = "0px";
    list1.margin = "0px";

    cell1.appendChild(list1);

    var list2 = document.createElement("ul");
    list2.style.listStyle = "none";
    list2.style.padding = "0px";
    list2.margin = "0px";

    cell2.appendChild(list2);

    var options = tstFormElements[tstCurrentPage].options;
   
    var j = 0;

    for(var i = 0; i < options.length; i++){
        if(options[i].text.trim().length > 0){
            var li = document.createElement("li");
            li.id = i;
            li.setAttribute("pos", i);
            li.setAttribute("source_id", tstFormElements[tstCurrentPage].id)

            li.onclick = function(){
                var img = this.getElementsByTagName("img")[0];

                if(img.getAttribute("src").toLowerCase().trim().match(/unticked/)){
                    img.setAttribute("src", "/touchscreentoolkit/lib/images/ticked.jpg");
                    this.setAttribute("class", "highlighted");

                    if(__$(this.getAttribute("source_id"))){
                        __$(this.getAttribute("source_id")).options[parseInt(this.getAttribute("pos"))].selected = true;

                        __$("touchscreenInput" + tstCurrentPage).value +=
                        __$(this.getAttribute("source_id")).options[parseInt(this.getAttribute("pos"))].value + tstMultipleSplitChar;
                    }
                } else {
                    img.setAttribute("src", "/touchscreentoolkit/lib/images/unticked.jpg");
                    this.setAttribute("class", this.getAttribute("group"));

                    if(__$(this.getAttribute("source_id"))){
                        __$(this.getAttribute("source_id")).options[parseInt(this.getAttribute("pos"))].selected = false;

                        if(__$(this.getAttribute("source_id")).options[parseInt(this.getAttribute("pos"))].value + tstMultipleSplitChar){
                            __$("touchscreenInput" + tstCurrentPage).value =
                            __$("touchscreenInput" + tstCurrentPage).value.replace(__$(this.getAttribute("source_id")).options[parseInt(this.getAttribute("pos"))].value + tstMultipleSplitChar, "");
                        }
                    }
                }
            }

            if(i % 2 == 0){
                list1.appendChild(li);

                if(j % 2 == 0){
                    li.className = "even";
                    li.setAttribute("group", "even");
                } else {
                    li.className = "odd";
                    li.setAttribute("group", "odd");
                }
            } else {
                list2.appendChild(li);

                if(j % 2 == 0){
                    li.className = "even";
                    li.setAttribute("group", "even");
                } else {
                    li.className = "odd";
                    li.setAttribute("group", "odd");
                }

                j++;

            }

            var innerTable = document.createElement("div");
            innerTable.style.display = "table";
            innerTable.style.width = "100%";

            li.appendChild(innerTable);

            var innerRow = document.createElement("div")          ;
            innerRow.style.display = "table-row";

            innerTable.appendChild(innerRow);

            var innerCell1 = document.createElement("div");
            innerCell1.style.display = "table-cell";
            innerCell1.style.width = "30px";

            innerCell1.innerHTML = "<img src='/touchscreentoolkit/lib/images/unticked.jpg' height='45' />";

            innerRow.appendChild(innerCell1);

            var innerCell2 = document.createElement("div");
            innerCell2.style.display = "table-cell";
            innerCell2.style.verticalAlign = "middle";
            innerCell2.style.paddingLeft = "20px";

            innerCell2.innerHTML = options[i].innerHTML;

            innerRow.appendChild(innerCell2);

            if(options[i].selected){
                innerCell1.innerHTML = "<img src='/touchscreentoolkit/lib/images/ticked.jpg' height='45' />";
                li.setAttribute("class", "highlighted");
            }
        }
    }

    if(__$("touchscreenInput" + tstCurrentPage).value.trim().length > 0){
        setTimeout("__$('touchscreenInput' + tstCurrentPage).value += tstMultipleSplitChar", 200);
    }
    setTimeout(function(){
        __$("lblSelectAll").onmousedown = function(){
            checkAllItems();
        }

        __$("chkSelectAll").onmousedown = function(){
            checkAllItems();
        }
    }, 500)
}

function createSingleSelectControl(options_div){

    var options = tstFormElements[tstCurrentPage].options;

    if (typeof(options) == undefined){

        options = tstFormElements[tstCurrentPage].children;
    }
   
    if(__$("keyboard")){
    // setTimeout("__$('keyboard').style.display = 'none'", 10);
    }

    if(__$("viewport")){
        __$("viewport").style.display = "none";
        __$("viewport").innerHTML = "";
    }

    if(__$("touchscreenInput" + tstCurrentPage)){
        __$("touchscreenInput" + tstCurrentPage).style.display = "none";
    }

    var parent = document.createElement("div");
    parent.id = 'parent' + tstCurrentPage;
    parent.style.width = "100%";
    parent.style.marginTop = "10px";
    parent.style.overflow = "auto";

    if (selectAll && selectAll == true){
        parent.style.height = 0.71 * screen.height + "px";
    }else{
        parent.style.height = 0.77 * screen.height + "px";
    }

    __$("inputFrame" + tstCurrentPage).style.width = "96%";

    __$("inputFrame" + tstCurrentPage).appendChild(parent);

    var table = document.createElement("div");
    table.style.display = "table";
    table.style.width = "98.5%";
    table.style.margin = "10px";

    parent.appendChild(table);

    var row = document.createElement("div");
    row.style.display = "table-row";

    table.appendChild(row);

    var cell1 = document.createElement("div");
    cell1.style.display = "table-cell";
    cell1.border = "1px solid #666";
    cell1.style.minWidth = "50%";

    row.appendChild(cell1);

    var cell2 = document.createElement("div");
    cell2.style.display = "table-cell";
    cell2.border = "1px solid #666";
    cell2.style.minWidth = "50%";

    row.appendChild(cell2);

    var list1 = document.createElement("ul");
    list1.style.listStyle = "none";
    list1.style.padding = "0px";
    list1.margin = "0px";

    cell1.appendChild(list1);

    var list2 = document.createElement("ul");
    list2.style.listStyle = "none";
    list2.style.padding = "0px";
    list2.margin = "0px";

    cell2.appendChild(list2);
   
    
    var j = 0;

    for(var i = 0; i < options.length; i++){
        var li = document.createElement("li");
        li.id = i;

        if (tstFormElements[tstCurrentPage][i].innerHTML == "")
            li.style.display = "none";
        
        li.setAttribute("pos", i);
        li.setAttribute("source_id", tstFormElements[tstCurrentPage].id)

        li.onclick = function(){
            
            var img = this.getElementsByTagName("img")[0];

            if(__$(this.getAttribute("source_id"))){
                var opts = __$(this.getAttribute("source_id")).options;

                for(var k = 0; k < opts.length; k++){
                    var image = __$(k).getElementsByTagName("img")[0];

                    image.setAttribute("src", "/touchscreentoolkit/lib/images/unchecked.png");
                    __$(k).setAttribute("class", __$(k).getAttribute("group"));
                }
            }

            if(img.getAttribute("src").toLowerCase().trim().match(/unchecked/)){
                img.setAttribute("src", "/touchscreentoolkit/lib/images/checked.png");
                this.setAttribute( "class", "highlighted");

                if(__$(this.getAttribute("source_id"))){
                    __$(this.getAttribute("source_id")).options[parseInt(this.getAttribute("pos"))].selected = true;
                    updateTouchscreenInput(__$(this.getAttribute("source_id")).options[parseInt(this.getAttribute("pos"))])
                }
            }
        }

        if(i % 2 == 1){
            list1.appendChild(li);

            if(j % 2 == 0){
                li.className = "odd";
                li.setAttribute("group", "odd");
            } else {
                li.className = "even";
                li.setAttribute("group", "even");
            }
        } else {
            list2.appendChild(li);

            if(j % 2 == 0){
                li.className = "odd";
                li.setAttribute("group", "odd");
            } else {
                li.className = "even";
                li.setAttribute("group", "even");
            }

            j++;

        }

        var innerTable = document.createElement("div");
        innerTable.style.display = "table";
        innerTable.style.width = "100%";

        li.appendChild(innerTable);

        var innerRow = document.createElement("div")          ;
        innerRow.style.display = "table-row";

        innerTable.appendChild(innerRow);

        var innerCell1 = document.createElement("div");
        innerCell1.style.display = "table-cell";
        innerCell1.style.width = "30px";

        innerCell1.innerHTML = "<img src='/touchscreentoolkit/lib/images/unchecked.png' height='45' />";

        innerRow.appendChild(innerCell1);

        var innerCell2 = document.createElement("div");
        innerCell2.style.display = "table-cell";
        innerCell2.style.verticalAlign = "middle";
        innerCell2.style.paddingLeft = "20px";

        innerCell2.innerHTML = options[i].innerHTML;

        innerRow.appendChild(innerCell2);

        if(options[i].selected){
            innerCell1.innerHTML = "<img src='/touchscreentoolkit/lib/images/checked.png' height='45' />";
            li.setAttribute("class", "highlighted");
        }
    }
// __$("clearButton").onclick = function(){
//   var elements = __$("parent" + tstCurrentPage).getElementsByTagName("li");
//  elements[0].click();
//}
}

function checkAllItems(){

    var elements = __$("parent" + tstCurrentPage).getElementsByTagName("li");
    var btnText = __$("lblSelectAll").innerHTML;

    for(var i = 0; i < elements.length; i++){

        var imgs = elements[i].getElementsByTagName("img")

        if ( btnText == "Select All" && imgs.length > 0 && imgs[0].src.match(/\/touchscreentoolkit\/lib\/images\/unticked.jpg/)){

            elements[i].click();
        }else if ( btnText == "Deselect All" && imgs.length > 0 && imgs[0].src.match(/\/touchscreentoolkit\/lib\/images\/ticked.jpg/)){
            elements[i].click();
        }

    }
}

function checkSelections(){
    var elements = []
    try{
        elements = __$("parent" + tstCurrentPage).getElementsByTagName("li");
    }catch(e){
        elements = []
    }
    var checked = 0;
    var unchecked = 0;
    var btnText = __$("lblSelectAll").innerHTML;
    for(var i = 0; i < elements.length; i++){
        var imgs = elements[i].getElementsByTagName("img");
        if (imgs.length > 0 && imgs[0].src.match(/\/touchscreentoolkit\/lib\/images\/ticked.jpg/)){
            checked ++
        }else if (imgs.length > 0 && imgs[0].src.match(/\/touchscreentoolkit\/lib\/images\/unticked.jpg/)) {
            unchecked ++
        }
    }

    if ((btnText == "Select All" && unchecked == 0) || (btnText == "Deselect All" && checked == 0)){
        __$("lblSelectAll").click();
    }

    setTimeout( 'checkSelections()', 200);
}
try{
    if (selectAll){
        setTimeout( 'checkSelections()', 700);
    }
}catch(e){

}