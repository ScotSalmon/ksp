G = 6.674e-11
TWO_PI = 2 * Math.PI
HALF_PI = 0.5 * Math.PI

(exports ? this).CelestialBody = class CelestialBody
  constructor: (@mass, @radius, @siderealRotation, @orbit, @atmPressure = 0, @atmScaleHeight = 0) ->
    @gravitationalParameter = G * @mass
    @sphereOfInfluence = @orbit.semiMajorAxis * Math.pow(@mass / @orbit.referenceBody.mass, 0.4) if @orbit?
    @atmRadius = -Math.log(1e-6) * @atmScaleHeight + @radius
  
  circularOrbitVelocity: (altitude) ->
    Math.sqrt(@gravitationalParameter / (altitude + @radius))
  
  siderealTimeAt: (longitude, time) ->
    result = ((time / @siderealRotation) * TWO_PI + HALF_PI + longitude) % TWO_PI
    if result < 0 then result + TWO_PI else result
  
  name: -> return k for k, v of CelestialBody when v == this
  
  children: ->
    result = {}
    result[k] = v for k, v of CelestialBody when v?.orbit?.referenceBody == this
    result

CelestialBody.fromJSON = (json) ->
  orbit = Orbit.fromJSON(json.orbit) if json.orbit?
  new CelestialBody(json.mass, json.radius, json.siderealRotation, orbit, json.atmPressure)

CelestialBody.Sun = Sun = new CelestialBody(1.988435e30, 696342000, 2.164e6, null)
CelestialBody.Mercury = Mercury = new CelestialBody(3.3022e23, 2439700, 5067031.68, new Orbit(Sun, 57908973645.88802, 0.2056187266319207, 28.60252108855048, 10.86541167564728, 66.90371044151551, 318.2162077814089))
CelestialBody.Venus = Venus = new CelestialBody(4.8676e+24, 6051800, 20996798.4, new Orbit(Sun, 108209548790.4671, 0.006810339650842032, 24.46397633556437, 7.981603378781639, 123.7121294282329, 311.2459947553124), 5, 7000)
CelestialBody.Earth = Earth = new CelestialBody(5.972e24, 6371000, 86164.098903691, new Orbit(Sun, 149494366257.0978, 0.01609636160505683, 23.44603795469773, 359.9965004168758, 102.9720683296131, 357.0607464120944), 1, 5000)
CelestialBody.Moon = Moon = new CelestialBody(7.34767309e+22, 1737100, 2360584.68479999, new Orbit(Earth, 384308437.7707066, 0.05328149353682574, 28.36267790798491, 2.296616161126016, 199.7640930160823, 222.7012350930954))
CelestialBody.Mars = Mars = new CelestialBody(639e21, 3380100, 88642.6848, new Orbit(Sun, 227949699961.9763, 0.09326110278323557, 24.69272426910055, 3.351911063089117, 332.1022655295414, 169.3913127942378), 0.2, 3000)
