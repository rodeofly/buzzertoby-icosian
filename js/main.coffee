#####################################################################
######### Globals !            ######################################
#####################################################################

chemin = []

#####################################################################
######### Empruntée à arborjs halfviz..sans le drag and drop ! ######
#####################################################################

Renderer = (canvas) ->
  canvas = $(canvas).get(0)
  ctx = canvas.getContext('2d')
  gfx = arbor.Graphics(canvas)
  particleSystem = null
  that = 
    
    init: (system) ->
      particleSystem = system
      particleSystem.screenSize canvas.width, canvas.height
      particleSystem.screenPadding 40
      that.initMouseHandling()
      return
    
    redraw: ->
      if !particleSystem
        return
      gfx.clear()
      # convenience ƒ: clears the whole canvas rect
      # draw the nodes & save their bounds for edge drawing
      nodeBoxes = {}
      particleSystem.eachNode (node, pt) ->
        # node: {mass:#, p:{x,y}, name:"", data:{}}
        # pt:   {x:#, y:#}  node position in screen coords
        # determine the box size and round off the coords if we'll be 
        # drawing a text label (awful alignment jitter otherwise...)
        label = node.data.label or ''
        w = ctx.measureText('' + label).width + 10
        if !('' + label).match(/^[ \t]*$/)
          pt.x = Math.floor(pt.x)
          pt.y = Math.floor(pt.y)
        else
          label = null
        # draw a rectangle centered at pt
        if node.data.color
          ctx.fillStyle = node.data.color
        else
          ctx.fillStyle = 'rgba(0,0,0,.2)'
        if node.data.color == 'none'
          ctx.fillStyle = 'white'
        if node.data.shape == 'dot'
          gfx.oval pt.x - (w / 2), pt.y - (w / 2), w, w, fill: ctx.fillStyle
          nodeBoxes[node.name] = [
            pt.x - (w / 2)
            pt.y - (w / 2)
            w
            w
          ]
        else
          gfx.rect pt.x - (w / 2), pt.y - 10, w, 20, 4, fill: ctx.fillStyle
          nodeBoxes[node.name] = [
            pt.x - (w / 2)
            pt.y - 11
            w
            22
          ]
        # draw the text
        if label
          ctx.font = '12px Helvetica'
          ctx.textAlign = 'center'
          ctx.fillStyle = 'white'
          if node.data.color == 'none'
            ctx.fillStyle = '#333333'
          ctx.fillText label or '', pt.x, pt.y + 4
          ctx.fillText label or '', pt.x, pt.y + 4
        return
      # draw the edges
      particleSystem.eachEdge (edge, pt1, pt2) ->
        # edge: {source:Node, target:Node, length:#, data:{}}
        # pt1:  {x:#, y:#}  source position in screen coords
        # pt2:  {x:#, y:#}  target position in screen coords
        weight = edge.data.weight
        color = edge.data.color
        if !color or ('' + color).match(/^[ \t]*$/)
          color = null
        # find the start point
        tail = intersect_line_box(pt1, pt2, nodeBoxes[edge.source.name])
        head = intersect_line_box(tail, pt2, nodeBoxes[edge.target.name])
        ctx.save()
        ctx.beginPath()
        ctx.lineWidth = if !isNaN(weight) then parseFloat(weight) else 1
        ctx.strokeStyle = if color then color else '#cccccc'
        ctx.fillStyle = null
        ctx.moveTo tail.x, tail.y
        ctx.lineTo head.x, head.y
        ctx.stroke()
        ctx.restore()
        # draw an arrowhead if this is a -> style edge
        if edge.data.directed
          ctx.save()
          # move to the head position of the edge we just drew
          wt = if !isNaN(weight) then parseFloat(weight) else 1
          arrowLength = 6 + wt
          arrowWidth = 2 + wt
          ctx.fillStyle = if color then color else '#cccccc'
          ctx.translate head.x, head.y
          ctx.rotate Math.atan2(head.y - (tail.y), head.x - (tail.x))
          # delete some of the edge that's already there (so the point isn't hidden)
          ctx.clearRect -arrowLength / 2, -wt / 2, arrowLength / 2, wt
          # draw the chevron
          ctx.beginPath()
          ctx.moveTo -arrowLength, arrowWidth
          ctx.lineTo 0, 0
          ctx.lineTo -arrowLength, -arrowWidth
          ctx.lineTo -arrowLength * 0.8, -0
          ctx.closePath()
          ctx.fill()
          ctx.restore()
        return
      return
    
    initMouseHandling: ->
      # no-nonsense drag and drop (thanks springy.js)
      selected = null
      nearest = null
      dragged = null
      oldmass = 1
      # set up a handler object that will initially listen for mousedowns then
      # for moves and mouseups while dragging
      handler = 
        clicked: (e) ->
          
          pos = $(canvas).offset()
          _mouseP = arbor.Point(e.pageX - (pos.left), e.pageY - (pos.top))
          selected = nearest = dragged = particleSystem.nearest(_mouseP)
          
          #####################################################################
          ######### La c'est pour nous ! ######################################
          #####################################################################
          
          console.log "clicked point :", selected.node
          particleSystem.tweenNode( selected.node , 0.5, {color: "blue"} ) 
          
          if chemin.length > 1
            last = chemin.pop()
            $("#sortie").text last.p.y
            edges = particleSystem.getEdges( last, selected.node)
            console.log "found edges :", edges
            # ce serait cool que les chemins qui mènent au sommet qu'on voit de quitter disparaissent
            # comme ça on ne pourrait pas tricher
            # mais pas pour le premier sommet, le 0, celui-là il faut qu'on puisse y retourner
#            particleSystem.pruneEdge edge for edge in particleSystem.getEdgesFrom last
#            particleSystem.pruneEdge edge for edge in particleSystem.getEdgesTo last
            particleSystem.tweenEdge(edges[0], 0.5, {weight : 4})
          chemin.push last
          chemin.push selected.node
          
          #####################################################################
          #####################################################################
          #####################################################################
        
      $(canvas).mousedown handler.clicked
      return
  # helpers for figuring out where to draw arrows (thanks springy.js)

  intersect_line_line = (p1, p2, p3, p4) ->
    denom = (p4.y - (p3.y)) * (p2.x - (p1.x)) - ((p4.x - (p3.x)) * (p2.y - (p1.y)))
    if denom == 0
      return false
    # lines are parallel
    ua = ((p4.x - (p3.x)) * (p1.y - (p3.y)) - ((p4.y - (p3.y)) * (p1.x - (p3.x)))) / denom
    ub = ((p2.x - (p1.x)) * (p1.y - (p3.y)) - ((p2.y - (p1.y)) * (p1.x - (p3.x)))) / denom
    if ua < 0 or ua > 1 or ub < 0 or ub > 1
      return false
    arbor.Point p1.x + ua * (p2.x - (p1.x)), p1.y + ua * (p2.y - (p1.y))

  intersect_line_box = (p1, p2, boxTuple) ->
    p3 = 
      x: boxTuple[0]
      y: boxTuple[1]
    w = boxTuple[2]
    h = boxTuple[3]
    tl = 
      x: p3.x
      y: p3.y
    tr = 
      x: p3.x + w
      y: p3.y
    bl = 
      x: p3.x
      y: p3.y + h
    br = 
      x: p3.x + w
      y: p3.y + h
    intersect_line_line(p1, p2, tl, tr) or intersect_line_line(p1, p2, tr, br) or intersect_line_line(p1, p2, br, bl) or intersect_line_line(p1, p2, bl, tl) or false
  that   

clear : () -> sys.eachNode (node) -> sys.pruneNode node
    
$ ->
  [repulsion, stiffness, friction ] = [ 400, 200, 0.2]

  sys = arbor.ParticleSystem()
  sys.parameters
    repulsion : 600
    stiffness : 400
    friction  : 0.5
    gravity   : false
    precision : 0.0005
  sys.renderer = Renderer("#viewport")
    
  home = sys.addNode 0, {'color' : "blue", 'shape' : 'square', 'label' : " #{0} ", 'mass' : "1" }
  home.p.x = -4620
  home.p.y = 6630
  for i in [1..19]
    noeud = sys.addNode i, {'color' : "red", 'shape' : 'dot', 'label' : " #{i} ", 'mass' : "1" }
    noeud.p.x = home.p.x+(10+2*i)*Math.sin 2*Math.PI/5*i
    noeud.p.y = home.p.y+(10+2*i)*Math.cos 2*Math.PI/5*i
  
  for i in [0..4]
      sys.addEdge i, (i+1)%5, {type : "arrow", directed : false, color : "blue", weight : 1,  length:4,}
      sys.addEdge i, 2*i+5, {type : "arrow", directed : false, color : "brown", weight : 1,  length:2,}
      sys.addEdge i+5, i+6, {type : "arrow", directed : false, color : "green", weight : 1,  length:4,}
      sys.addEdge i+10, (i+6)%10+5, {type : "arrow", directed : false, color : "green", weight : 1,  length:4,}
      sys.addEdge 2*i+6, i+15, {type : "arrow", directed : false, color : "cyan", weight : 1,  length:2,}
      sys.addEdge i+15, (i+1)%5+15, {type : "arrow", directed : false, color : "red", weight : 1,  length:5,}
      
  #####################################################################
  ######### Sliders              ######################################
  #####################################################################
      
  $( "#slider-repulsion" ).slider
    range: "max"
    min   : 1
    max   : 3000
    step  : 10
    value : repulsion
    slide : ( event, ui ) -> 
      $( "#amount-repulsion" ).html( ui.value )
      sys.parameters repulsion: ui.value          
  $( "#amount-repulsion" ).html(repulsion)

  
  $( "#slider-stiffness" ).slider
    range: "max"
    min   : 1
    max   : 3000
    step  : 10
    value : stiffness
    slide : ( event, ui ) -> 
      $( "#amount-stiffness" ).html( ui.value )
      sys.parameters stiffness: ui.value           
  $( "#amount-stiffness" ).html(stiffness)
  
  $( "#slider-friction" ).slider
    range: "max"
    min   : 0
    max   : 1
    step  : 0.1
    value : friction
    slide : ( event, ui ) -> 
      $( "#amount-friction" ).html( ui.value )
      sys.parameters friction: ui.value 
    $( "#amount-friction" ).html(friction) 
      

