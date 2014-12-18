Momentum.registerPlugin 'keep-visible', (options) ->
  throw new Error "'selector' argument missing" unless options.selector

  options = _.defaults options,
    duration: 500
    easing: 'ease-in-out'

  insertElement: (node, next, done) ->
    $node = $(node)
    currentScrollStop = $(window).scrollTop()

    # If outside a selected part of the page we add the element with a nice animation.
    # TODO: Should we also check if user scrolled pass the selector and is outside it on the bottom?
    if currentScrollStop <= $(options.selector).offset().top
      $node.insertBefore(next).velocity 'slideDown',
        easing: options.easing
        duration: options.duration
        queue: false
        complete: ->
          done()
      return

    # Otherwise we insert it directly and keep the currently visible element visible by scrolling.
    $node.insertBefore(next)

    nodeHeight = $node.outerHeight true
    # We first move scroll location based on the height which is
    # available immediately. This makes position not jump around.
    $(window).scrollTop currentScrollStop + nodeHeight
    Tracker.afterFlush ->
      # But after flush we check if anything has changed (templates can add more
      # content in their rendered callback) and move scroll location accordingly.
      newNodeHeight = $node.outerHeight true
      $(window).scrollTop $(window).scrollTop() + (newNodeHeight - nodeHeight)
      done()

  removeElement: (node, done) ->
    $node = $(node)
    $node.velocity 'slideUp',
      easing: options.easing
      duration: options.duration
      complete: ->
        $node.remove()
        done()
