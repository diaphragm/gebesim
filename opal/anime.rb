
require 'opal'
require 'native'
require 'math'
require 'bullet'
include Math

#$scene, $camera, $renderer = nil
#$geometry, $material, $mesh = nil



#$projector = nil
$mouse = {x: 0, y: 0}
$intersected = nil

$scale = 100
$winwidth = 640
$winheight = 480

$bullet_datas = {}
$bullet_cubes = {}
$bullet_lines = {}

def init_anime
  el_mc = $win.document.getElementById("module_container")
  if $win.innerWidth / $win.innerHeight > 1.2
    $winwidth = [$win.document.body.clientWidth - el_mc.clientWidth - 70, 320].max
    $winheight = [$win.innerHeight - 60, 240].max
  else
    $winwidth = [$win.document.body.clientWidth - 30, 320].max
    $winheight = [$win.innerHeight - 60, 240].max
  end


  $scene = Native(`new THREE.Scene()`)


  $camera = Native(`new THREE.PerspectiveCamera( 75, #{$winwidth / $winheight}, 1, 10000 )`)
  $camera.up.set(0, 0, 1) # toriaezu
  $camera.position.z = 500 # toriaezu
  $camera.position.x = -500
  $camera.position.y = -500


  $scene.add( Native(`new THREE.AmbientLight( 0xe0e0e0 )`).to_n )


  light = Native(`new THREE.DirectionalLight( 0xffffff, 1 )`)
  light.position.set( 0, 0, 1000 )
  light.castShadow = true
  light.shadowCameraLeft = -5*$scale;
  light.shadowCameraRight = 25*$scale;
  light.shadowCameraTop = 5*$scale;
  light.shadowCameraBottom = -5*$scale;
  # light.shadowCameraFov = 90
  light.shadowCameraNear = $camera.near
  light.shadowCameraFar = $camera.far
  light.shadowBias = 0.8
  light.shadowDarkness = 0.5
  light.shadowMapWidth = 1028*4
  light.shadowMapHeight = 1028*4
  $scene.add( light )


  plane_geometry = Native(`new THREE.PlaneGeometry(6000, 2000)`)
  plane_material = Native(`new THREE.MeshBasicMaterial( { color: 0xf0f0f0 } )`)
  plane_material.side = `THREE.DoubleSide`
  plane_geometry.translate(2000, 0, 0)

  plane_geometry_n = plane_geometry.to_n
  plane_material_n = plane_material.to_n
  plane = Native(`new THREE.Mesh( plane_geometry_n, plane_material_n )`)
  plane.position.z = -42.3 # 100 * sin(-25deg)
  plane.receiveShadow = true
  $scene.add(plane.to_n)

  grid_xz = Native(` new THREE.GridHelper( 20000, 100 )`)
  grid_xz.material.opacity = 0.1
  grid_xz.material.transparent = true
  $scene.add(grid_xz)

  grid_xy = Native(` new THREE.GridHelper( 20000, 100 )`)
  grid_xy.rotation.x = PI/2
  grid_xy.position.z = -42.2
  grid_xy.material.opacity = 0.15
  grid_xy.material.transparent = true
  $scene.add(grid_xy)


  lgeo = Native(`new THREE.Geometry()`)
  verts = [
    `new THREE.Vector3(-50, 0, 0)`, `new THREE.Vector3(50, 0, 0)`,
    `new THREE.Vector3(0, -50, 0)`, `new THREE.Vector3(0, 50, 0)`,
    `new THREE.Vector3(0, 0, -50)`, `new THREE.Vector3(0, 0, 50)`
  ]
  verts.each{|seg| lgeo.vertices.push(seg)}
  lmat = Native(`new THREE.LineBasicMaterial({color: 0x000000})`)
  lgeo_n, lmat_n = lgeo.to_n, lmat.to_n
  centerline = Native(`new THREE.LineSegments(lgeo_n, lmat_n)`)
  centerline.opacity = 0.8
  $scene.add(centerline)

#  geometry = Native(`new THREE.BoxGeometry( 10, 10, 10 )`)
#  material = Native(`new THREE.MeshBasicMaterial( { color: 0xffffff, wireframe: true } )`)
#  geometry_native = geometry.to_n
#  material_native = material.to_n
#  mesh = Native(`new THREE.Mesh( geometry_native, material_native )`)
#  $scene.add( mesh );

  $renderer = Native(`new THREE.WebGLRenderer()`)
  $renderer.setClearColor( 0xf0f0f0 )
  $renderer.setSize( $winwidth, $winheight)
  $renderer.shadowMap.enabled = true


  camera_native = $camera.to_n
  domelement_native = $renderer.domElement.to_n
  $controls = Native(`new THREE.OrbitControls(camera_native, domelement_native)`)



  $win.document.getElementById("anime_container").appendChild( $renderer.domElement.to_n )

  frame_controler = $win.document.getElementById("frame_controler")
  frame_controler.addEventListener(:input){|event|
    redraw(frame_controler.value)
  }

end

def animate
  $win.requestAnimationFrame( `Opal.Kernel.$animate` )

#  $mesh.rotation.x += 0.01
#  $mesh.rotation.y += 0.02

  $controls.update
  Kernel.tooltip_update

  $renderer.render( $scene, $camera )

end


def redraw(frame)
  $win.document.getElementById("frameview").innerText = "#{frame}/#{$max_frame}"
  frame = frame.to_i

  $bullet_lines.each do |no, line|
    flags = $bullet_datas[no].map(&:last)
    s = flags.index(true)
    e = flags.rindex(true)

    if frame < s
      line.geometry.setDrawRange(s, 0)
    elsif  e < frame
      line.geometry.setDrawRange(s, e-s+1)
    else
      line.geometry.setDrawRange(s, frame-s+1)
    end

    line.geometry.attributes.position.needsUpdate = true
  end

  $bullet_cubes.each do |no, cubes|
    flags = $bullet_datas[no].map(&:last)
    s = flags.index(true)
    e = flags.rindex(true)

    cubes.each do |cube|
      next if cube.nil?
      cube.material.visible = false
    end

    if s < frame
      cubes[s..([frame, e].min)].each do |cube|
        cube.material.visible = true
      end
    end
  end
end

def init_bullet

  # draw lines
  $bullet_lines = {}
  $bullet_datas.each do |no, bullet_data|
    vectors = bullet_data.map{|fd|
      matrix = fd[0]
      available = fd[1]

      v = Native(`new THREE.Vector3()`).setFromMatrixPosition(matrix)
      v_r = Native(`new THREE.Vector3()`).set(v.x, -v.y, -v.z) # convert left-handed to right-handed
      v_r.multiplyScalar($scale)
    }


    geometry = Native(`new THREE.BufferGeometry()`)

    maxpoints = vectors.size
    positions = `new Float32Array(maxpoints * 3)`
    geometry.addAttribute("position", `new THREE.BufferAttribute(positions, 3)`)

    vectors.each.with_index do |v, i|
      geometry.attributes.position.array[i*3+0] = v.x
      geometry.attributes.position.array[i*3+1] = v.y
      geometry.attributes.position.array[i*3+2] = v.z
    end
    geometry.setDrawRange(0, 0) # toriaezu

    co = COLOR_MAP[no]
    material = Native(`new THREE.LineBasicMaterial( { color: co, linewidth: 2 } )`)

    geometry_native = geometry.to_n
    material_native = material.to_n
    line = Native(`new THREE.Line(geometry_native, material_native)`)

    line.castShadow = true

    line.bullet_module_no = no

    $bullet_lines[no] = line
    $scene.add(line)
  end


  # draw line point cube
  $bullet_cubes = {}
  $bullet_datas.each do |no, bullet_data|
    ret = []
    bullet_data.each.with_index do |(matrix, available), i|
      unless available
        ret << nil
        next
      end


      # convert right-handed to left-handed
      m_zrev = Native(`new THREE.Matrix4()`).makeScale(1,1,-1)
      m_yzrev = Native(`new THREE.Matrix4()`).makeScale(1,-1,-1)
      matrix_r = m_yzrev.multiply(matrix).multiply(m_zrev)


      geometry = Native(`new THREE.CylinderGeometry(0, 0.05, 0.1, 3, 1)`)
      geometry.rotateZ(-PI/2)
      geometry.translate(-0.05, 0, 0)
      geometry.rotateY(Math.atan( 1/(2*Math.sqrt(3))))
      geometry.scale(1, 1, 0.5)
      geometry.applyMatrix(matrix_r)
      geometry.scale($scale, $scale, $scale)

      co = COLOR_MAP[no]
      material = Native(`new THREE.MeshLambertMaterial( {color: co} )`)

      geometry_native = geometry.to_n
      material_native = material.to_n

      cube = Native(`new THREE.Mesh( geometry_native, material_native )`)
      cube.castShadow = true

      cube.bullet_module_no = no
      cube.bullet_module_frame = i


      ret << cube
      $scene.add(cube.to_n)
    end
    $bullet_cubes[no] = ret
  end


  # set frame
  $max_frame = $bullet_datas.map{|k,fd| fd.size - 1}.max
  frame_controler = $win.document.getElementById("frame_controler")
  frame_controler.max = $max_frame || 0
  frame_controler.value = $max_frame || 0
  redraw($max_frame)

end

def init_tooltip
  $projector = Native(`new THREE.Projector()`)
  $win.document.addEventListener(:mousemove){|event|
    e = Native(event)

    rect = e.target.getBoundingClientRect
    $mouse[:x] =  ((e.clientX - rect.left) / $winwidth) * 2 - 1
    $mouse[:y] = -((e.clientY - rect.top) / $winheight) * 2 + 1
    $mouse[:left] =  e.clientX
    $mouse[:top] = e.clientY
  }

  $tooltip = $win.document.createElement("div")
  $tooltip.id = "tootlip"
  $tooltip.innerHTML = "陰陽神酒でねえ"
  $tooltip.style.position = "fixed"
  $tooltip.style.display = "none"

  $win.document.getElementById("anime_container").appendChild( $tooltip.to_n )


end

def tooltip_update
  mx, my = $mouse[:x], $mouse[:y]
  vector = Native(`new THREE.Vector3(mx, my, 1)`)
  vector.unproject($camera)
  camera_pos_n = $camera.position.to_n
  vector_n = vector.sub( $camera.position ).normalize.to_n
  ray = Native(`new THREE.Raycaster( camera_pos_n, vector_n )`)

  intersected_obj = $bullet_cubes.values.flatten.compact
  intersects = ray.intersectObjects(intersected_obj)

  if intersects.length > 0
    intersects_wrapped = Native(`intersects[0]`)

    if intersects_wrapped.object != $intersected
      # change color
      $intersected.material.color.setHex($intersected.currentHex) if $intersected
      $intersected = intersects_wrapped.object

      color = $intersected.material.color.clone

      $intersected.currentHex = $intersected.material.color.getHex
      $intersected.material.color.setHex(0x4040ff)


      # draw tooltip
      no = $intersected.bullet_module_no
      frame = $intersected.bullet_module_frame

      flags = $bullet_datas[no].map(&:last)
      s, e = flags.index(true), flags.rindex(true)
      age = frame - s
      life = e - s

      matrix = $bullet_datas[no][frame][0]
      translation = Native(`new THREE.Vector3()`)
      quaternion = Native(`new THREE.Quaternion()`)
      scale = Native(`new THREE.Vector3()`)
      matrix.decompose(translation, quaternion, scale)
      euler = Native(`new THREE.Euler()`)
      euler.setFromQuaternion(quaternion, "ZYX")

      x, y, z = [translation.x, translation.y, translation.z].map{|v| (v*$scale).round}
      a, b, g = [euler.x, euler.y, euler.z].map{|v| (v / PI * 180).round(1)}

      z = -z # 右手系と左手系の面倒くさいアレ

      if g > 120
        g = 180 - g
      elsif g < -120
        g = 180 + g
      end
      if b > 120
        b = 180 - b
      elsif b < -120
        b = 180 + b
      end

      $tooltip.innerText = "No.#{no} Age:#{age}/#{life}f Time:#{frame}/#{$max_frame}f\nx:#{x} y:#{y} z:#{z} Rot:[#{g}, #{b}, #{a}]"
      $tooltip.style.left = "#{$mouse[:left]+35}px"
      $tooltip.style.top = "#{$mouse[:top]+25}px"
      $tooltip.style["border-left-color"] = color.getStyle
      $tooltip.style.display = "block"
    end
  else
    $intersected.material.color.setHex($intersected.currentHex) if $intersected
    $intersected = nil

    $tooltip.style.display = "none" if $tooltip
  end
end

def clear_bullet
  $bullet_cubes.each do |no, cubes|
    cubes.each do |cube|
      next if cube.nil?
      $scene.remove(cube)
      cube.dispose
      cube.geometry.dispose
      cube.material.dispose
#      cube.texture.dispose
    end
  end

  $bullet_lines.each do |no, line|
    $scene.remove(line)
    line.dispose
    line.geometry.dispose
    line.material.dispose
  end

end


# init
# animate
