Momentum.registerPlugin 'keep-visible', (options) ->
  throw new Error "'selector' argument missing" unless options.selector

  insertElement: (node, next, done) ->
    next.parentNode.insertBefore node, next

    currentScrollStop = $(window).scrollTop()
    # We keep the element visible only if user is inside a selected part of the page.
    # TODO: Should we also check if user scrolled pass the selector and is outside it on the bottom?
    return done() if currentScrollStop <= $(options.selector).offset().top

    nodeHeight = $(node).outerHeight true
    # We first move scroll location based on the height which is
    # available immediately. This makes position not jump around.
    $(window).scrollTop currentScrollStop + nodeHeight
    Tracker.afterFlush ->
      # But after flush we check if anything has changed (templates can add more
      # content in their rendered callback) and move scroll location accordingly.
      newNodeHeight = $(node).outerHeight true
      $(window).scrollTop $(window).scrollTop() + (newNodeHeight - nodeHeight)
    done()

  moveElement: (node, next, done) ->
    next.parentNode.insertBefore node, next
    done()

  removeElement: (node, done) ->
    node.parentNode.removeChild node
    done()
