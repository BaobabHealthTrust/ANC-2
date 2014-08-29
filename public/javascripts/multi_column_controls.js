
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

function ajaxify(cat, selected){

    if (cat.trim() == "region" && selected != "Other" && !selected.match(/region/)){
        var url = "/people/districts_for?filter_value=" + selected + "&search_string=";
        ajaxCustomRequest(cat, url);
    }else if (cat.trim() == "district"){
        var url = "/people/traditional_authority_for?filter_value=" + tstInputTarget.value + "&search_string=";
        ajaxCustomRequest(cat, url);
    }
}

function ajaxCustomRequest(cat, aUrl) {

    var httpRequest = new XMLHttpRequest();
    httpRequest.onreadystatechange = function() {
        handleCustomResult(cat, httpRequest);
    };
    try {
        httpRequest.open('GET', aUrl, true);
        httpRequest.send(null);
    } catch(e){
    }
}

function handleCustomResult(cat, aXMLHttpRequest) {
    if (!aXMLHttpRequest) return;

    if (aXMLHttpRequest.readyState == 4 && (aXMLHttpRequest.status == 200 ||
        aXMLHttpRequest.status == 304)) {

        var result = aXMLHttpRequest.responseText;
        values_hash["region"] = tstInputTarget.value;
        values_hash["district"] = '';

        if (cat == "region"){

            var data = result.split("|");

            var ul = document.createElement("ul");

            for(var i = 0; i < data.length; i ++){

                var li = document.createElement("li")
                li.setAttribute("class", "district");
                li.value = data[i]
                li.innerHTML = data[i]
                li.onmousedown = function(){
                    updateCustomTouchscreenInput(this);
                }

                ul.appendChild(li);
            }
            __$("sc2").innerHTML = ""
            __$("sc2").appendChild(ul);
        }
    }
}

function verifyFields(num){

    if (values_hash['district'] == ''){
        values_hash["temp_region"] = values_hash["region"];
        values_hash["region"] = "";
        region_terminal = false;
    }else{
        values_hash["temp_region"] = "";
        region_terminal = true;
    }

    if (num == 1){

        __$("address2").value = values_hash["district"];
        __$("region_region_name").value = values_hash["region"];
    }else if (num == 2){

        __$("state_province").value = values_hash["district"];
        __$("filter_region").value = values_hash["region"];
    }
    tstInputTarget.value = values_hash["region"];
    values_hash["region"] = values_hash["temp_region"];

}


function showNext(){
    __$("nextButton").style.display = "block";
}

function hideNext(){
    __$("nextButton").style.display = "none";
}

function updateCustomTouchscreenInput(element){

    values_hash["district"] = element.innerHTML;
    var inputTarget = tstInputTarget;

    if (element.value.length>1)
        inputTarget.value = element.value;
    else if (element.innerHTML.length>1)
        inputTarget.value = element.innerHTML;

    highlightSelection(element.parentNode.childNodes, inputTarget);
    tt_update(inputTarget);
}

function updateInputFields(){
    if (value.trim() != tstInputTarget.value.trim()){

        value = tstInputTarget.value;
        if (value.length > 0 && value.match(/region|Foreign/i)) {
            ajaxify("region", value);
        }
    }

    if (region_terminal == false){
        setTimeout("updateInputFields()", 100);
    }
}

function ajaxifyDistricts(){
    value = tstInputTarget.value
    region_terminal = false;

    //clear previous selections
    __$("clearButton").onmousedown.apply(__$("clearButton"));
    setTimeout("updateInputFields()", 30)

    __$("viewport").style.width = "48%";
    __$("viewport").style.borderStyle = "solid";
    __$("viewport").style.borderWidth = "2px";
    __$("viewport").style.borderTop = "hidden";
    __$("viewport").style.borderLeft = "hidden";
    __$("viewport").style.borderBottom = "hidden";

    var view2 = document.createElement("div");
    view2.id = "viewport2"
    view2.setAttribute("class", "options");
    view2.style.position = "absolute";
    view2.style.top = "15.35%";
    view2.style.left = "50%";
    view2.style.width = "48%";
    view2.style.borderStyle = "solid";
    view2.style.borderWidth = "2px";
    view2.style.borderTop = "hidden";
    view2.style.borderLeft = "hidden";
    view2.style.borderBottom = "hidden";
    view2.style.borderRight = "hidden";

    var sc2 = document.createElement("div");
    sc2.setAttribute("class", "scrollable");
    sc2.setAttribute("referstotouchscreeninputid", tstCurrentPage + 1);
    sc2.id = "sc2";
    view2.appendChild(sc2);
    __$("inputFrame" + tstCurrentPage).appendChild(view2);
}

function showSummary(field){
    var div = document.createElement("div");
    div.id = "status";
    div.className = "statusLabel";

    if(field == "year"){

        div.style.marginTop = "-4%";
        div.style.textAlign = "center";
        div.innerHTML = "<i>Year   =   "  + __$("person_birth_year").value + "</i>"
        __$("inputFrame" + tstCurrentPage).appendChild(div);

    }else if (field == "day"){

        var months = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December", "Unknown"];
        div.style.textAlign = "center";
        div.innerHTML = "<i>Year   =  " + __$("person_birth_year").value + "; Month = " + months[__$("person_birth_month").value] + "</i>";
        __$("inputFrame" + tstCurrentPage).appendChild(div);
    }
}

try{
    if (selectAll){
        setTimeout( 'checkSelections()', 700);
    }
}catch(e){

}