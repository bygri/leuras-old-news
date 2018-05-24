/*
I have a simple UI. There's a list of ARTICLES and a set of BUTTONS.
The user should click the article. Then we enter CROP MODE.
In crop mode, Jcrop engages and allows the user to select a crop region.
Crop mode can be 'paused' to allow the user to pan, and then 'resumed' to allow the user to continue the crop.
When the crop region is the right size, it is added to the list of crop regions, because there might be more than
one column to crop.
When that article is complete, all the crop regions are posted off to the server along with the article ID.

UI states:
- default: no buttons available. Article list available.
- crop engaged: pause, add region, and finalise buttons available. No article list.
- crop paused: resume, add region, and finalise buttons available. No article list.
*/

$(function() {

  var cropRegions = [];
  var articleId;
  var articleTitle;

  var savedCrop;

  var jcropApi;

  var State = {
    Default: 1,
    Cropping: 2,
    // CropWithSelection: 3,
    CropPaused: 4,
  };

  function setState(state) {
    // Default state: show articles, hide buttons
    if (state == State.Default) {
      $('li.article').show();
      $('li.article-header').hide();
      $('#cropRegions').hide();
      $('li.button').hide();
    }
    // Cropping
    else if (state == State.Cropping) {
      $('li.article').hide();
      $('li.article-header').show();
      $('#cropRegions').show();
      $('#pauseButton').show();
      $('#resumeButton').hide();
      $('#cancelButton').show();
      // If there is a selection, show add region button
      if (jcropApi && jcropApi.tellSelect().x !== 0) {
        $('#addCropRegionButton').show();
      } else {
        $('#addCropRegionButton').hide();
      }
    }
    // Crop Paused
    else if (state == State.CropPaused) {
      $('li.article').hide();
      $('li.article-header').show();
      $('#cropRegions').show();
      $('#pauseButton').hide();
      $('#resumeButton').show();
      $('#cancelButton').show();
      $('#addCropRegionButton').hide();
    }
    // Set the article title item
    if (articleTitle) {
      $('li.article-header').html(articleTitle + '<br><small>' + articleId + '</small>');
    } else {
      $('li.article-header').html('ARTICLE-TITLE');
    }
    // Fill out the cropRegions item
    if (cropRegions.length === 0) {
      $('#cropRegions').html('No regions defined.');
    } else {
      var html = '';
      for (var i = 0; i < cropRegions.length; i++) {
        var r = cropRegions[i];
        html += '('+r.x+','+r.y+') '+r.w+' x '+r.h+'<br>'
      }
      $('#cropRegions').html(html);
    }
    // If there are any crop regions added, show finish
    if (cropRegions.length > 0) {
      $('#finishButton').show();
    } else {
      $('#finishButton').hide();
    }
  }
  setState(State.Default);

  // Begin cropping an article. Save the article id and set up jcrop.
  function beginCrop() {
    cropRegions = [];
    articleId = $(this).data('id');
    articleTitle = $(this).html();
    $('#pageImage').Jcrop({
      handleSize: 25,
      onSelect: function() { setState(State.Cropping) },
    }, function() {
      jcropApi = this;
    });
    setState(State.Cropping);
  }
  $('.beginCrop').click(beginCrop);

  // Disable cropping so the user can pan.
  function pauseCrop() {
    savedCrop = jcropApi.tellSelect();
    jcropApi.destroy();
    setState(State.CropPaused);
  }
  $('#pauseButton').click(pauseCrop);

  // Re-enable cropping. Check there's an article ID set first.
  function resumeCrop() {
    if (articleId) {
      var options = {
        handleSize: 25,
        onSelect: function() { setState(State.Cropping) },
      }
      if (savedCrop && savedCrop.x !== 0) {
        options["setSelect"] = [savedCrop.x, savedCrop.y, savedCrop.x2, savedCrop.y2]
      }
      $('#pageImage').Jcrop(options, function() {
        jcropApi = this;
      });
      setState(State.Cropping);
    }
  }
  $('#resumeButton').click(resumeCrop);

  // Clear out cropping and return to default state.
  function cancelCrop() {
    jcropApi.destroy();
    jcropApi = null;
    setState(State.Default);
  }
  $('#cancelButton').click(cancelCrop);

  // Add the currently-selected region to the list of crop regions, and disable cropping
  // so the user can pan to the next section.
  function addCropRegion() {
    var c = jcropApi.tellSelect();
    cropRegions.push(c);
    jcropApi.destroy();
    jcropApi = null;
    setState(State.CropPaused);
  }
  $('#addCropRegionButton').click(addCropRegion);

  // Fire off the crop regions to the server.
  function finaliseCrop() {
    // convert these:
    // c.x, c.y, c.x2, c.y2, c.w, c.h
    // into a form action and post it off to the server. woot. also the article id.
    articleId = null;
    articleTitle = null;
  }
  $('#finishButton').click(finaliseCrop);
});
