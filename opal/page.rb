
require "opal"
require "native"
require "bullet"
require "anime"

$module_max = 12
$module_elements = {}

def page_setup

  # /?m=16 でモジュール数を指定する隠し機能
  m = $win.location.search[/[?&^]m=(\d+)/, 1]
  $module_max = m ? m.to_i : $module_max


  module_container = $win.document.getElementById("module_container")

  module_list_html = ""
  BulletModule::MODULE_LIST.each do |index, (id, type, following, *params)|
    module_list_html += %[<option value=#{index}>#{id}</option>\n]
  end

  parent_html = (1..$module_max).map{|i|
    color = "#"+COLOR_MAP[i].to_s(16).rjust(6,"0")
    %[<option style="background-color:#{color}" value=#{i}>No.#{i.to_s.rjust($module_max.to_s.length,"0")}</option>}]
  }.join("\n")


  (1..$module_max).each do |no|
    bullet_module = $win.document.createElement("div")
    bullet_module.id = "module:#{no}"
    bullet_module.classList.add("module")

    color = "#"+COLOR_MAP[no].to_s(16).rjust(6,"0")

    bullet_module.style["border-color"] = color

    bullet_module.innerHTML = <<-EOT
      <span class="bulletNo">No.#{no.to_s.rjust($module_max.to_s.length,"0")}</span>
      <!-- <span>モジュール：</span> -->
      <select type="listbox" id="index:#{no}">
        <option value="null">-</option>
        #{module_list_html}
      </select>
      <span>\u2220</span>
      <input type="number" style="width:3em" id="rotz:#{no}" value=0>,
      <input type="number" style="width:3em" id="roty:#{no}" value=0>,
      <input type="number" style="width:3em" id="rotx:#{no}" value=0>

      <span>└</span>
      <select type="listbox" id="parent:#{no}">
        <option value="null">ボタン</option>
        #{parent_html}
      </select>

      <select type="listbox" id="timing:#{no}">
        <option value="s">と同時に</option>
        <option value="v">の自然消滅時</option>
        <option value="d02">の0.2秒後</option>
        <option value="d05">の0.5秒後</option>
        <option value="d10">の1秒後</option>
        <option value="d20">の2秒後</option>
        <option value="d30">の3秒後</option>
        <option value="d50">の5秒後</option>
        <option value="d100">の10秒後</option>
      </select>
    EOT

    $module_elements[no] = bullet_module
    module_container.appendChild(bullet_module)
  end


  # set eventlisteners
  editor_container = $win.document.getElementById("editor_container")
  ["select", "input"].each do |tagname|
    elems = editor_container.getElementsByTagName(tagname)
    elems.length.times do |i|
      elem = elems[i]
      elem.addEventListener(:input){|event| fire}
    end
  end

  clear_module_button = $win.document.getElementById("clear_module_button")
  clear_module_button.addEventListener(:click){|event|
    clear_modules
    clear_bullet
  }

  editor_container = $win.document.getElementById("editor_container")
  editor_container.addEventListener(:focusout){|event|
    module_list = get_module_list
    $win.location.hash = compress(module_list)
  }


  # set query if url have query
  hsh = $win.location.hash
  unless hsh == ""
    query = hsh.sub(/^#/,"")
    set_module_list(decompress(query))
  end
end

def get_module_list
  module_list = {}
  $module_elements.each do |no, elem|
    index = $win.document.getElementById("index:#{no}").value
    rotz = $win.document.getElementById("rotz:#{no}").value
    roty = $win.document.getElementById("roty:#{no}").value
    rotx = $win.document.getElementById("rotx:#{no}").value
    parent = $win.document.getElementById("parent:#{no}").value
    timing = $win.document.getElementById("timing:#{no}").value

    unless index == "null"
      data = {}
      data[:index] = index.to_i
      data[:rot] = [rotz, roty, rotx]
      unless parent == "null"
        data[:parent] = parent.to_i
        data[:timing] = timing
      end
      module_list[no] = data
    end
  end
  module_list
end

def set_module_list(module_list)
  module_list.each do |no, data|
    next if no.to_i > $module_elements.size

    if no.to_s.to_i == no
      index = data[:index]
      rotz = data[:rot][0]
      roty = data[:rot][1]
      rotx = data[:rot][2]
      parent = data[:parent]
      timing = data[:timing]

      $win.document.getElementById("index:#{no}").value = index
      $win.document.getElementById("rotz:#{no}").value = rotz
      $win.document.getElementById("roty:#{no}").value = roty
      $win.document.getElementById("rotx:#{no}").value = rotx
      if parent
        $win.document.getElementById("parent:#{no}").value = parent
        $win.document.getElementById("timing:#{no}").value = timing
      end
    elsif no == "g"
      $win.document.getElementById("rotz:g").value = data[0]
      $win.document.getElementById("roty:g").value = data[1]
      $win.document.getElementById("rotx:g").value = data[2]
    end
  end

  $win.location.hash = compress(module_list)
end

def get_gun
  rotz = $win.document.getElementById("rotz:g").value
  roty = $win.document.getElementById("roty:g").value
  rotx = $win.document.getElementById("rotx:g").value

  [rotz, roty, rotx]
end

def compress(module_list)
  module_list.map{|no, data|
    index = data[:index]
    rot = data[:rot].join(".")
    parent = data[:parent]
    timing = data[:timing]
    "#{no}=#{index}:#{rot}" + (parent ? ":#{parent}:#{timing}" : "")
  }.join(";")
end

def decompress(query)
  # debug
  # query ||= "1=7:45.45.0;2=0:0.0.0;3=5:0.0.0:2:same;4=1:0.-90.0:3:same;5=5:0.0.90:2:d02;6=1:0.0.0:5:d02;7=4:0.0.0"
  module_list = {}
  query.split(";").each do |text|
    no, data = text.split("=")
    if no.to_i.to_s == no
      index, rot, parent, timing = data.split(":")
      rot = rot.split(".")

      d = {}
      d[:index] = index.to_i
      d[:rot] = rot
      if parent
        d[:parent] = parent.to_i
        d[:timing] = timing
      end

      module_list[no.to_i] = d
    elsif no == "g"
      rot = data.split(".")
      module_list["g"] = rot
    end
  end
  module_list
end


def clear_modules
  (1..$module_max).each do |no|
    $win.document.getElementById("index:#{no}").selectedIndex = 0
    $win.document.getElementById("rotz:#{no}").value = 0
    $win.document.getElementById("roty:#{no}").value = 0
    $win.document.getElementById("rotx:#{no}").value = 0
    $win.document.getElementById("parent:#{no}").selectedIndex = 0
    $win.document.getElementById("timing:#{no}").selectedIndex = 0
  end
  $win.document.getElementById("rotz:g").value = 0
  $win.document.getElementById("roty:g").value = 0
  $win.document.getElementById("rotx:g").value = 0

  $win.location.hash = ""
end

def fire
  clear_bullet

  module_list = get_module_list
  b = Bullet.new(module_list)
  $bullet_datas = b.fire(get_gun)

  init_bullet
  init_tooltip

end


def set_query(query)
  clear_modules
  set_module_list(decompress(query))
  fire
end

def set_sample
  set_query("1=1:45.45.0;2=0:0.0.0;3=5:0.0.0:2:same;4=1:0.-90.0:3:same;5=5:0.0.90:2:d02;6=1:0.0.0:5:d02;7=4:0.0.0")
end
