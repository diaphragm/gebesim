# coding: utf-8

require 'opal'
require 'native'
require 'math'
include Math


class Bullet
  attr_reader :modules

  def initialize(module_list)
    @modules = {}
    module_list.each do |key, value|
      bm = BulletModule.new(value[:index], value[:rot], @modules[value[:parent]], value[:timing])
      @modules[key] = bm
    end
  end

  def dead?(frame)
    @modules.all?{|k, v| v.dead?(frame)}
  end

  def matrixes(frame, gun_rot_vector=[0, 0, 0])
    ret = {}

    gamma, beta, alpha = gun_rot_vector.map(&:to_f).map{|t| t*PI/180}
    euler = Native(`new THREE.Euler(alpha, beta, gamma, "ZYX")`)
    matrix_gun = Native(`new THREE.Matrix4()`).makeRotationFromEuler(euler)

    @modules.map{|key, bm|
      available = bm.born?(frame) && bm.dead?(frame).!
      ret[key] = [bm.matrix(frame, matrix_gun), available]
    }
    ret
  end

  def fire(rot_vector=[0, 0, 0])
    ret = @modules.each_with_object({}){|(k,v),s| s[k] = []}

    frame = 0
    until dead?(frame)
      matrixes(frame, rot_vector).each do |k, v|
        ret[k] << v
      end
      frame += 1
    end

    ret
  end
end



class BulletModule
  attr_reader :same_fire_delay, :life

  def initialize(index, init_rot_vector, parent=nil, timing=nil)
    gamma, beta, alpha = init_rot_vector.map(&:to_f).map{|t| t*PI/180}

    euler = Native(`new THREE.Euler(alpha, beta, gamma, "ZYX")`)
    @initial_matrix = Native(`new THREE.Matrix4()`).makeRotationFromEuler(euler)

    @parent = parent
    @timing = timing

    @log = []

    # to be defined by initialize methods
    @same_fire_delay = 1 # delay time when "fired at same time with xxx"
    @life = 0
    @formula_position = nil
    @formula_direction = nil
    @formula_gravity = nil
    @gravity = false

    name, following, type, *param = MODULE_LIST[index]
    @name = name
    @following = following
    __send__(type, *param)

  end

  def delay
    if @parent
      {
        s: @parent.same_fire_delay,
#        vanish: @life,
        v: @parent.life,
        d02: 6,
        d05: 15,
        d10: 30,
        d20: 60,
        d30: 90,
        d50: 150,
        d100: 300
      }[@timing]
    else
      0
    end
  end

  def age(frame)
    if @parent
      @parent.age(frame) - delay
    else
      frame
    end
  end

  def born?(frame)
    age(frame) >= 0
  end

  def dead?(frame)
    age(frame) > @life
  end

  def local_matrix(age)
    frame = [age, @life].min

    x, y, z = @formula_position[frame]
    gamma, beta, alpha = @formula_direction[frame]

    euler = Native(`new THREE.Euler(alpha, beta, gamma, "ZYX")`)
    mr = Native(`new THREE.Matrix4()`).makeRotationFromEuler(euler)
    mt = Native(`new THREE.Matrix4()`).makeTranslation(x, y, z)

    @initial_matrix.clone.multiply(mr).multiply(mt)
  end

  def matrix(frame, matrix_gun)
    m_tmp = if @parent
      parent_age = @following ? frame : frame - age(frame)

      m_p = @parent.matrix(parent_age, matrix_gun)
      m_l = local_matrix(age(frame))

      m_p.multiply(m_l)
    else
      matrix_gun.clone.multiply(local_matrix(frame))
    end

    if @gravity
      # この座標系では-zが上,+zが下
      xg, yg, zg = @formula_gravity[age(frame)]
#      xg, yg, zg = 0, 0, 0.25*(age(frame)**2) # TO BE FIXED
      mg = Native(`new THREE.Matrix4()`).makeTranslation(xg, yg, zg)
      mg.multiply(m_tmp)
    else
      m_tmp
    end
  end

  def straight(size, length)
    @life = {
      ss:{ss: 3, s: 15, l: 30},
      s: {ss: 4, s: 16, l: 33},
      m: {ss: 5, s: 20, l: 40},
      l: {ss: 6, s: 25, l: 50},
    }[size][length]
    speed = {ss: 1.5, s: 2/sqrt(3), m: 1, l: 0.8}[size]

    @formula_position = ->(x){[speed*x, 0, 0]}
    @formula_direction = ->(x){[0, 0, 0]}

    self
  end

  def straight_g(size)
    @life = {l: 93, ll: 93}[size] # l: 33+x = 90+30+6, ll: 30+20+x = 90+30+15+α よくわからんかった
    speed = {l: 0.5, ll: 2/sqrt(3)*2/6}[size]
    g = {l: 0.0104, ll: 0.0104}[size] # 0.01固定？微妙に違う気がする

    # L
    # z(6) = 1.5*sqrt(3) - 1.5*tan(55 deg)
    # +19degで射出 → 0.5s後 z=0ちょっと上
    # +38degで射出 → 1s後 z=0ちょっと下
    # LL
    # z(6) = 1.5*sqrt(3) - 1.5*tan(54 deg)
    # +24degで射出 → 0.5s後 z=0ちょっと上
    # +51degで射出 → 1s後 z=0ちょっと上

    @formula_position = ->(x){[speed*x, 0, 0]}
    @formula_direction = ->(x){[0, 0, 0]}
    @formula_gravity = ->(x){[0, 0, g*(x**2)]}
    @gravity = true

    self
  end

  def drilling(size, length)
    @life = {
      ss:{ss: 2, s: 15, l: 30},
      s: {ss: 2, s: 16, l: 33},
      m: {ss: 3, s: 20, l: 40},
      l: {ss: 3, s: 25, l: 50},
    }[size][length]
    speed = {ss: 1.3, s: 2/sqrt(3), m: 1, l: 0.8}[size]
    rot_speed = {
      # ss: {ss: -96*PI/180, s: 94*PI/180, l: 47*PI/180}, # 15がポイント？フレーム？
      ss: {ss: PI*22/15, s: PI*8/15, l: PI*4/15},
#      s: {ss: -0.8*PI or 144, s: 86*PI/180, l: 43*PI/180}
      s: {ss: 2.5, s: 1.5, l: 0.75},
      m: {ss: PI*2/3, s: PI*2/5, l:PI*1/5},
      l: {ss: PI*2/15, s: 4*2*PI/25, l: 4*2*PI/50}, # 1モジュールで4回転が基本っぽい？
    }[size][length]

    @formula_position = ->(x){[speed*x, 0, 0]}
    @formula_direction = ->(x){[0, 0, x*rot_speed]}

    self
  end

  def circle(size, dia)
    @life = {ss: 20, s: 24, m: 28, l: 32}[size] # サイズによらず2回転する

    rot_speed = {ss: -PI/5, s: -PI/6, m: -PI/7, l: -PI/8}[size]
    dia = {s: 1, m: 2, l: 3}[dia]

    @formula_position = ->(x){[dia, 0, 0]}
    @formula_direction = ->(x){[x*rot_speed, 0, 0]}
    @same_fire_delay = 2

    self
  end

  def ball(life)
    @life = {s: 60, m: 120, l: 240, ll: 960}[life] # maybe

    @formula_position = ->(x){[0,0,0]}
    @formula_direction = ->(x){[0,0,0]}

    self
  end

  def spinball(speed)
    @life = 60
    rot_speed = {fast: -PI*3/10, mid: -PI*3/20, slow: -PI*3/30}[speed] # 謎の回転速度

    @formula_position = ->(x){[0,0,0]}
    @formula_direction = ->(x){[x*rot_speed, 0, 0]}

    self
  end
end



class BulletModule
  MODULE_LIST = {
    # index =>  [name, following, type(method), params]
    0 => ["[SS]弾丸:直進/長", false, :straight, :ss, :l],
    1 => ["[SS]弾丸:直進/短", false, :straight, :ss, :s],
    2 => ["[SS]弾丸:直進/極短", false, :straight, :ss, :ss],
    3 => ["[SS]きりもみ弾/長", false, :drilling, :ss, :l],
    4 => ["[SS]きりもみ弾/短", false, :drilling, :ss, :s],
    5 => ["[SS]きりもみ弾/極短", false, :drilling, :ss, :ss],
    6 => ["[SS]弾丸:回転/通常", false, :circle, :ss, :m],
    7 => ["[SS]弾丸:回転/広", false, :circle, :ss, :l],
    8 => ["[SS]弾丸:回転/狭い", false, :circle, :ss, :s],
    9 => ["[SS]弾丸:追従回転/通常", true, :circle, :ss, :m],
    10 => ["[SS]弾丸:追従回転/広", true, :circle, :ss, :l],
    11 => ["[SS]弾丸:追従回転/狭い", true, :circle, :ss, :s],
    12 => ["[S]弾丸:直進/長", false, :straight, :s, :l],
    13 => ["[S]弾丸:直進/短", false, :straight, :s, :s],
    14 => ["[S]弾丸:直進/極短", false, :straight, :s, :ss],
    15 => ["[S]きりもみ弾/長", false, :drilling, :s, :l],
    16 => ["[S]きりもみ弾/短", false, :drilling, :s, :s],
    17 => ["[S]きりもみ弾/極短", false, :drilling, :s, :ss],
    18 => ["[S]弾丸:回転/通常", false, :circle, :s, :m],
    19 => ["[S]弾丸:回転/広", false, :circle, :s, :l],
    20 => ["[S]弾丸:回転/狭い", false, :circle, :s, :s],
    21 => ["[S]弾丸:追従回転/通常", true, :circle, :s, :m],
    22 => ["[S]弾丸:追従回転/広", true, :circle, :s, :l],
    23 => ["[S]弾丸:追従回転/狭い", true, :circle, :s, :s],
    24 => ["[M]弾丸:直進/長", false, :straight, :m, :l],
    25 => ["[M]弾丸:直進/短", false, :straight, :m, :s],
    26 => ["[M]弾丸:直進/極短", false, :straight, :m, :ss],
    27 => ["[M]きりもみ弾/長", false, :drilling, :m, :l],
    28 => ["[M]きりもみ弾/短", false, :drilling, :m, :s],
    29 => ["[M]きりもみ弾/極短", false, :drilling, :m, :ss],
    30 => ["[M]弾丸:回転/通常", false, :circle, :m, :m],
    31 => ["[M]弾丸:回転/広", false, :circle, :m, :l],
    32 => ["[M]弾丸:回転/狭い", false, :circle, :m, :s],
    33 => ["[M]弾丸:追従回転/通常", true, :circle, :m, :m],
    34 => ["[M]弾丸:追従回転/広", true, :circle, :m, :l],
    35 => ["[M]弾丸:追従回転/狭い", true, :circle, :m, :s],
    36 => ["[M]制御:静止/生存時間普通", false, :ball, :m, ],
    37 => ["[M]制御:静止/生存時間極長", false, :ball, :ll, ],
    38 => ["[M]制御:静止/生存時間長", false, :ball, :l, ],
    39 => ["[M]制御:静止/生存時間短", false, :ball, :s, ],
    40 => ["[M]制御:追従/生存時間普通", true, :ball, :m, ],
    41 => ["[M]制御:追従/生存時間短", true, :ball, :s, ],
    42 => ["[M]制御:回転/速度普通", false, :spinball, :mid, ],
    43 => ["[M]制御:回転/速度遅", false, :spinball, :slow, ],
    44 => ["[M]制御:回転/速度速", false, :spinball, :fast, ],
    45 => ["[L]弾丸:直進/長", false, :straight, :l, :l],
    46 => ["[L]弾丸:直進/短", false, :straight, :l, :s],
    47 => ["[L]弾丸:直進/極短", false, :straight, :l, :ss],
    48 => ["[L]きりもみ弾/長", false, :drilling, :l, :l],
    49 => ["[L]きりもみ弾/短", false, :drilling, :l, :s],
    50 => ["[L]きりもみ弾/極短", false, :drilling, :l, :ss],
    51 => ["[L]弾丸:回転/通常", false, :circle, :l, :m],
    52 => ["[L]弾丸:回転/広", false, :circle, :l, :l],
    53 => ["[L]弾丸:回転/狭い", false, :circle, :l, :s],
    54 => ["[L]弾丸:追従回転/通常", true, :circle, :l, :m],
    55 => ["[L]弾丸:追従回転/広", true, :circle, :l, :l],
    56 => ["[L]弾丸:追従回転/狭い", true, :circle, :l, :s],
    101 => ["[L]弾丸:重力/短", false, :straight_g, :l],
    102 => ["[LL]弾丸:重力/短", false, :straight_g, :ll],
  }
end


#def test(module_list=nil)
#  module_list ||= {
#    1 => {index: 7, rot: [45, 45, 0]},
#    2 => {index: 0, rot: [0, 0, 0]},
#    3 => {index: 5, rot: [0, 0, 0], parent: 2, timing: :same},
#    4 => {index: 1, rot: [0, -90, 0], parent: 3, timing: :same},
#    5 => {index: 5, rot: [0, 0, 90], parent: 2, timing: :d02},
#    6 => {index: 1, rot: [0, 0, 0], parent:5, timing: :d02},
#    7 => {index: 4, rot: [0, 0, 0]},
#
#  }
#
#  b = Bullet.new(module_list)
#  b.fire
#end
