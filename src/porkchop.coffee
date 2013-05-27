PLOT_WIDTH = 300
PLOT_HEIGHT = 300
PLOT_X_OFFSET = 70
TIC_LENGTH = 5

originBody = null
originOrbit = null
destinationOrbit = null
initialOrbitalVelocity = null
finalOrbitalVelocity = null
earliestDeparture = null
earliestArrival = null
xScale = null
yScale = null
deltaVs = null

canvasContext = null
plotImageData = null

palette = []
palette.push([64, i, 255]) for i in [64...69]
palette.push([128, i, 255]) for i in [133..255]
palette.push([128, 255, i]) for i in [255..128]
palette.push([i, 255, 128]) for i in [128..255]
palette.push([255, i, 128]) for i in [255..128]

clamp = (n, min, max) -> Math.max(min, Math.min(n, max))

numberWithCommas = (n) ->
  n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")

hourMinSec = (t) ->
  hour = (t / 3600) | 0
  t %= 3600
  min = (t / 60) | 0
  min = "0#{min}" if min < 10
  sec = (t % 60).toFixed()
  sec = "0#{sec}" if sec < 10
  "#{hour}:#{min}:#{sec}"
  
kerbalDateString = (t) ->
  year = ((t / (365 * 24 * 3600)) | 0) + 1
  t %= (365 * 24 * 3600)
  day = ((t / (24 * 3600)) | 0) + 1
  t %= (24 * 3600)
  "Year #{year}, day #{day} at #{hourMinSec(t)}"

durationString = (t) ->
  result = ""
  if t >= 365 * 24 * 3600
    result += (t / (365 * 24 * 3600) | 0) + " years "
    t %= 365 * 24 * 3600
    result += "0d" if t < 24 * 3600
  result += (t / (24 * 3600) | 0) + " days " if t >= 24 * 3600
  t %= 24 * 3600
  result + hourMinSec(t)

distanceString = (d) ->
  if d > 1e12
    numberWithCommas((d / 1e9).toFixed()) + " Gm"
  else if d >= 1e9
    numberWithCommas((d / 1e6).toFixed()) + " Mm"
  else if d >= 1e6
    numberWithCommas((d / 1e3).toFixed()) + " km"
  else
    numberWithCommas(d.toFixed()) + " m"

angleString = (angle, precision = 0) ->
  (angle * 180 / Math.PI).toFixed(precision) + String.fromCharCode(0x00b0)

worker = new Worker("javascripts/porkchopworker.js")

worker.onmessage = (event) ->
  if 'progress' of event.data
    $('#porkchopProgress .bar').show().width((event.data.progress * 100 | 0) + "%")
  else if 'deltaVs' of event.data
    $('#porkchopProgress .bar').hide().width("0%")
    deltaVs = new Float64Array(event.data.deltaVs)
    minDeltaV = event.data.minDeltaV
    maxDeltaV = 4 * minDeltaV
    
    i = 0
    j = 0
    for y in [0...PLOT_HEIGHT]
      for x in [0...PLOT_WIDTH]
        deltaV = deltaVs[i++]
        relativeDeltaV = if isNaN(deltaV) then 1.0 else (clamp(deltaV, minDeltaV, maxDeltaV) - minDeltaV) / (maxDeltaV - minDeltaV)
        colorIndex = Math.min(relativeDeltaV * palette.length | 0, palette.length - 1)
        color = palette[colorIndex]
        plotImageData.data[j++] = color[0]
        plotImageData.data[j++] = color[1]
        plotImageData.data[j++] = color[2]
        plotImageData.data[j++] = 255
    
    ctx = canvasContext
    ctx.save()
    ctx.putImageData(plotImageData, PLOT_X_OFFSET, 0)
    ctx.font = '10pt "Helvetic Neue",Helvetica,Arial,sans serif'
    ctx.textAlign = 'left'
    ctx.fillStyle = 'black'
    ctx.textBaseline = 'alphabetic'
    for i in [0...1.0] by 0.25
      ctx.fillText(((minDeltaV + i * (maxDeltaV - minDeltaV)) | 0) + " m/s", PLOT_X_OFFSET + PLOT_WIDTH + 85, (1.0 - i) * PLOT_HEIGHT)
      ctx.textBaseline = 'middle'
    ctx.textBaseline = 'top'
    ctx.fillText((maxDeltaV | 0) + " m/s", PLOT_X_OFFSET + PLOT_WIDTH + 85, 0)
    ctx.restore()
    
    $('#porkchopSubmit').prop('disabled', false)
    

prepareCanvas = ->
  ctx = canvasContext
  
  ctx.save()
  ctx.lineWidth = 2
  ctx.strokeStyle = 'black'
  
  # Draw axes
  ctx.beginPath()
  ctx.moveTo(PLOT_X_OFFSET - 1, 0)
  ctx.lineTo(PLOT_X_OFFSET - 1, PLOT_HEIGHT + 1)
  ctx.lineTo(PLOT_X_OFFSET + PLOT_WIDTH, PLOT_HEIGHT + 1)
  ctx.stroke()
  
  # Draw tic marks
  ctx.beginPath()
  for i in [0..1.0] by 0.25
    y = PLOT_HEIGHT * i + 1
    ctx.moveTo(PLOT_X_OFFSET - 1, y)
    ctx.lineTo(PLOT_X_OFFSET - 1 - TIC_LENGTH, y)
    
    x = PLOT_X_OFFSET - 1 + PLOT_WIDTH * i
    ctx.moveTo(x, PLOT_HEIGHT + 1)
    ctx.lineTo(x, PLOT_HEIGHT + 1 + TIC_LENGTH)
  ctx.stroke()
  
  # Draw minor tic marks
  ctx.lineWidth = 0.5
  ctx.beginPath()
  for i in [0..1.0] by 0.05
    continue if i % 0.25 == 0
    y = PLOT_HEIGHT * i + 1
    ctx.moveTo(PLOT_X_OFFSET - 1, y)
    ctx.lineTo(PLOT_X_OFFSET - 1 - TIC_LENGTH, y)
    
    x = PLOT_X_OFFSET - 1 + PLOT_WIDTH * i
    ctx.moveTo(x, PLOT_HEIGHT + 1)
    ctx.lineTo(x, PLOT_HEIGHT + 1 + TIC_LENGTH)
  ctx.stroke()
  
  # Draw axis titles
  ctx.font = 'italic 12pt "Helvetic Neue",Helvetica,Arial,sans serif'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillStyle = 'black'
  ctx.fillText("Departure Date (days from epoch)", PLOT_X_OFFSET + PLOT_WIDTH / 2, PLOT_HEIGHT + 40)
  ctx.save()
  ctx.rotate(-Math.PI / 2)
  ctx.textBaseline = 'top'
  ctx.fillText("Arrival Date (days from epoch)", -PLOT_HEIGHT / 2, 0)
  ctx.restore()
  
  # Draw palette key
  paletteKey = ctx.createImageData(20, PLOT_HEIGHT)
  i = 0
  for y in [0...PLOT_HEIGHT]
    j = ((PLOT_HEIGHT - y - 1) * palette.length / PLOT_HEIGHT) | 0
    for x in [0...20]
      paletteKey.data[i++] = palette[j][0]
      paletteKey.data[i++] = palette[j][1]
      paletteKey.data[i++] = palette[j][2]
      paletteKey.data[i++] = 255
  
  ctx.putImageData(paletteKey, PLOT_X_OFFSET + PLOT_WIDTH + 60, 0)
  ctx.fillText(String.fromCharCode(0x2206) + "v", PLOT_X_OFFSET + PLOT_WIDTH + 45, PLOT_HEIGHT / 2)
  
  ctx.restore()
  
  
$(document).ready ->
  canvasContext = $('#porkchopCanvas')[0].getContext('2d')
  plotImageData = canvasContext.createImageData(PLOT_WIDTH, PLOT_HEIGHT)
  
  prepareCanvas()
  
  $('#porkchopCanvas').mousemove (event) ->
    if deltaVs?
      x = event.offsetX - PLOT_X_OFFSET
      y = event.offsetY
      ctx = canvasContext
      ctx.putImageData(plotImageData, PLOT_X_OFFSET, 0)
      if x >= 0 and x < PLOT_WIDTH and y < PLOT_HEIGHT
        ctx.save()
      
        ctx.beginPath()
        ctx.moveTo(PLOT_X_OFFSET + x, 0)
        ctx.lineTo(PLOT_X_OFFSET + x, PLOT_HEIGHT)
        ctx.moveTo(PLOT_X_OFFSET, y)
        ctx.lineTo(PLOT_X_OFFSET + PLOT_WIDTH, y)
        ctx.lineWidth = 1
        ctx.strokeStyle = 'rgba(255,255,255,0.75)'
        ctx.stroke()
      
        deltaV = deltaVs[(y * PLOT_WIDTH + x) | 0]
        unless isNaN(deltaV)
          tip = " " + String.fromCharCode(0x2206) + "v = " + deltaV.toFixed() + " m/s "
          ctx.font = '10pt "Helvetic Neue",Helvetica,Arial,sans serif'
          ctx.fillStyle = 'black'
          ctx.textAlign = if x < PLOT_WIDTH / 2 then 'left' else 'right'
          ctx.textBaseline = if y > 15 then 'bottom' else 'top'
          ctx.fillText(tip, event.offsetX, event.offsetY)
      
        ctx.restore()
      
  $('#porkchopCanvas').mouseleave (event) ->
    canvasContext.putImageData(plotImageData, PLOT_X_OFFSET, 0) if deltaVs?
  
  $('#porkchopCanvas').click (event) ->
    if deltaVs?
      x = event.offsetX - PLOT_X_OFFSET
      y = event.offsetY
      if x >= 0 and x < PLOT_WIDTH and y < PLOT_HEIGHT and !isNaN(deltaVs[(y * PLOT_WIDTH + x) | 0])
        t0 = earliestDeparture + x * xScale / PLOT_WIDTH
        t1 = earliestArrival + ((PLOT_HEIGHT-1) - y) * yScale / PLOT_HEIGHT
        
        trueAnomaly = originOrbit.trueAnomalyAt(t0)
        p0 = originOrbit.positionAtTrueAnomaly(trueAnomaly)
        v0 = originOrbit.velocityAtTrueAnomaly(trueAnomaly)
        n0 = originOrbit.normalVector()
        
        trueAnomaly = destinationOrbit.trueAnomalyAt(t1)
        p1 = destinationOrbit.positionAtTrueAnomaly(trueAnomaly)
        v1 = destinationOrbit.velocityAtTrueAnomaly(trueAnomaly)
        n1 = destinationOrbit.normalVector()
        
        transfer = Orbit.ballisticTransfer(originOrbit.referenceBody, t0, p0, v0, n0, t1, p1, v1, n1, initialOrbitalVelocity, finalOrbitalVelocity, originBody)
        
        $('#departureTime').text(kerbalDateString(t0))
        $('#arrivalTime').text(kerbalDateString(t1))
        $('#timeOfFlight').text(durationString(t1 - t0))
        $('#phaseAngle').text(angleString(originOrbit.phaseAngle(destinationOrbit, t0), 2))
        $('#transferPeriapsis').text(distanceString(transfer.orbit.periapsis()))
        $('#transferApoapsis').text(distanceString(transfer.orbit.apoapsis()))
        $('#transferInclination').text(angleString(transfer.orbit.inclination, 2))
        $('#transferAngle').text(angleString(transfer.angle))
        $('#ejectionAngle').text(angleString(transfer.ejectionAngle))
        $('#ejectionInclination').text(angleString(transfer.ejectionInclination, 2))
        $('#ejectionDeltaV').text(numberWithCommas(transfer.ejectionDeltaV.toFixed()) + " m/s")
        if finalOrbitalVelocity == 0
          $('#insertionInclination').text("N/A")
          $('#insertionDeltaV').text("N/A")
        else
          $('#insertionInclination').text(angleString(transfer.insertionInclination, 2))
          $('#insertionDeltaV').text(numberWithCommas(transfer.insertionDeltaV.toFixed()) + " m/s")
        $('#totalDeltaV').text(numberWithCommas(transfer.deltaV.toFixed()) + " m/s")
        
  $('#originSelect').change (event) ->
    origin = CelestialBody[$(this).val()]
    referenceBody = origin.orbit.referenceBody
    
    s = $('#destinationSelect')
    previousDestination = s.val()
    s.empty()
    s.append($('<option>').text(k)) for k, v of CelestialBody when v != origin and v?.orbit?.referenceBody == referenceBody
    s.val(previousDestination)
    s.val($('option:first', s).val()) unless s.val()?
    s.prop('disabled', s[0].childNodes.length == 0)
  
  $('#originSelect').change()
  $('#destinationSelect').val('Duna')
  
  $('#porkchopForm').submit (event) ->
    event.preventDefault()
    $('#porkchopSubmit').prop('disabled', true)
    
    originBodyName = $('#originSelect').val()
    destinationBodyName = $('#destinationSelect').val()
    initialOrbit = $('#initialOrbit').val().trim()
    finalOrbit = $('#finalOrbit').val().trim()
    
    originBody = CelestialBody[originBodyName]
    destinationBody = CelestialBody[destinationBodyName]
    
    initialOrbitalVelocity = originBody.circularOrbitVelocity(initialOrbit * 1e3)
        
    if finalOrbit
      finalOrbitalVelocity = destinationBody.circularOrbitVelocity(finalOrbit * 1e3)
    else
      finalOrbitalVelocity = null
    
    earliestDeparture = ($('#earliestDepartureYear').val() - 1) * 365 + ($('#earliestDepartureDay').val() - 1)
    earliestDeparture *= 24 * 3600
    earliestArrival = ($('#earliestArrivalYear').val() - 1) * 365 + ($('#earliestArrivalDay').val() - 1)
    earliestArrival *= 24 * 3600
    
    originOrbit = originBody.orbit
    destinationOrbit = destinationBody.orbit
    hohmannTransfer = Orbit.fromApoapsisAndPeriapsis(originOrbit.referenceBody, destinationOrbit.semiMajorAxis, originOrbit.semiMajorAxis, 0, 0, 0, 0)
    earliestArrival = earliestDeparture + hohmannTransfer.period() / 4
    xScale = 2 * Math.min(originOrbit.period(), destinationOrbit.period())
    if destinationOrbit.semiMajorAxis < originOrbit.semiMajorAxis
      yScale = 2 * destinationOrbit.period()
    else
      yScale = hohmannTransfer.period()
    
    ctx = canvasContext
    ctx.clearRect(PLOT_X_OFFSET, 0, PLOT_WIDTH, PLOT_HEIGHT)
    ctx.clearRect(PLOT_X_OFFSET + PLOT_WIDTH + 85, 0, 65, PLOT_HEIGHT + 10)
    ctx.clearRect(20, 0, PLOT_X_OFFSET - TIC_LENGTH - 21, PLOT_HEIGHT + TIC_LENGTH)
    ctx.clearRect(PLOT_X_OFFSET - 40, PLOT_HEIGHT + TIC_LENGTH, PLOT_WIDTH + 80, 20)
    
    ctx.font = '10pt "Helvetic Neue",Helvetica,Arial,sans serif'
    ctx.fillStyle = 'black'
    ctx.textAlign = 'right'
    ctx.textBaseline = 'middle'
    for i in [0..1.0] by 0.25
      ctx.textBaseline = 'top' if i == 1.0
      ctx.fillText(((earliestArrival + i * yScale) / 3600 / 24) | 0, PLOT_X_OFFSET - TIC_LENGTH - 3, (1.0 - i) * PLOT_HEIGHT)
    ctx.textAlign = 'center'
    for i in [0..1.0] by 0.25
      ctx.fillText(((earliestDeparture + i * xScale) / 3600 / 24) | 0, PLOT_X_OFFSET + i * PLOT_WIDTH, PLOT_HEIGHT + TIC_LENGTH + 3)
      
    deltaVs = null
    worker.postMessage(
      originOrbit: originOrbit, destinationOrbit: destinationOrbit,
      initialOrbitalVelocity: initialOrbitalVelocity, finalOrbitalVelocity: finalOrbitalVelocity,
      earliestDeparture: earliestDeparture, xScale: xScale,
      earliestArrival: earliestArrival, yScale: yScale)
