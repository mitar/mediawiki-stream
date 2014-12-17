Momentum.registerPlugin 'keep-visible', (options) ->
  insertElement: (node, next, done) ->
    console.log "insertElement"
    next.parentNode.insertBefore node, next
    done()

  moveElement: (node, next, done) ->
    console.log "moveElement"
    next.parentNode.insertBefore node, next
    done()

  removeElement: (node, done) ->
    console.log "removeElement"
    node.parentNode.removeChild node
    done()
