# Dwemthy's Array: why the lucky stiff's little Ruby adventure, drawn.
#
# You are a Rabbit. Before you stands an Array of six monsters, each worse than the last,
# and you have a boomerang, a sword, some lettuce and three bombs. It is not a fair fight.
# It was never meant to be one.
#
# But the Rabbit's source is right there on the right, in rabbit.rb. Change it, press
# Recompile, and the next Rabbit is born from what you wrote. That is not cheating. That is
# the game. Every message in the log is what the Ruby printed; the pictures only act it out.
#
# Keys: ^ / % * attack (while the editor does not have focus), M mutes.
#
# After _why's Dwemthy's Array (2004), a lesson in metaprogramming dressed up as a
# role-playing game. When you win, the foxes have something to say.

require "json"
require "fileutils"
require "tmpdir"

# ------------------------------------------------------------------------------ the Ruby
#
# The game is a real Ruby program. Everything a creature `puts` lands in Dwemthy.said,
# along with a note of who was standing at the front of the Array when it was said,
# and the stage reads that list to know what to draw.

module Dwemthy
  @said = []

  class << self
    attr_accessor :rabbit, :array

    def say(text)
      front = array&.first
      @said << { text: text.to_s, monster: front, monster_life: front&.life }
      nil
    end

    def drain
      @said.slice!(0..)
    end
  end

  # Creatures and the Array print through this rather than to the terminal.
  module Speaks
    private

    def puts(*lines)
      lines = [""] if lines.empty?
      lines.flatten.each { |line| Dwemthy.say(line) }
      nil
    end

    def print(*bits)
      Dwemthy.say(bits.join)
    end

    def p(*things)
      things.each { |thing| Dwemthy.say(thing.inspect) }
      things.size <= 1 ? things.first : things
    end
  end

  CREATURE = <<~'RUBY'
    # The whole engine. A creature is a handful of numbers
    # and two methods; `traits` writes the methods that
    # remember the numbers.
    class Creature
      include Speaks

      # Every class has a secret class of its own, its
      # metaclass, and class methods live there.
      def self.metaclass
        class << self; self; end
      end

      # `traits :life` gives every creature a `life`, and
      # gives its class a `life 10` to write the number down.
      def self.traits( *names )
        return @traits ||= {} if names.empty?
        attr_accessor( *names )
        names.each do |name|
          metaclass.send( :define_method, name ) do |number|
            traits[name] = number
          end
        end
      end

      # A new creature starts out with its class's numbers.
      def initialize
        self.class.traits.each do |name, number|
          instance_variable_set( "@#{ name }", number )
        end
      end

      traits :life, :strength, :charisma, :weapon

      # Taking a hit. Now and then, charm turns into magick.
      def hit( damage )
        p_up = roll( charisma )
        if p_up % 9 == 7
          @life += p_up / 4
          puts "[#{ self.class } magick powers up #{ p_up }!]"
        end
        @life -= damage
        puts "[#{ self.class } has died.]" if @life <= 0
      end

      # One round: you swing, and if it still stands, it swings back.
      def fight( enemy, weapon )
        if life <= 0
          puts "[#{ self.class } is too dead to fight!]"
          return
        end
        your_hit = roll( strength + weapon )
        puts "[You hit with #{ your_hit } points of damage!]"
        enemy.hit( your_hit )
        if enemy.life > 0
          enemy_hit = roll( enemy.strength + enemy.weapon )
          puts "[Your enemy hit with #{ enemy_hit } points of damage!]"
          self.hit( enemy_hit )
        end
      end

      # A dice roll from 0 up to (not including) n.
      def roll( n )
        n.to_i > 0 ? rand( n.to_i ) : 0
      end

      # Rabbit, not Dwemthy::Hutch::Rabbit.
      def self.to_s
        name.to_s.split( "::" ).last
      end

      def inspect
        stats = self.class.traits.keys.map { |t| "#{ t }=#{ send( t ) }" }
        "#<#{ self.class } #{ stats.join( ' ' ) }>"
      end
    end
  RUBY

  ARRAY = <<~'RUBY'
    # The Array itself. Whatever you do to it, you do to the
    # monster at the front, and when that one falls the next
    # steps up.
    class DwemthysArray < Array
      include Speaks

      def method_missing( name, *args, &block )
        return super if empty? || !first.respond_to?( name )
        answer = first.send( name, *args, &block )
        if first.life <= 0
          shift
          if empty?
            puts "[Whoa.  You decimated Dwemthy's Array!]"
          else
            puts "[Get ready. #{ first.class } has emerged.]"
          end
        end
        answer || 0
      end

      def respond_to_missing?( name, include_private = false )
        ( !empty? && first.respond_to?( name ) ) || super
      end
    end
  RUBY

  MONSTERS = {
    "IndustrialRaverMonkey" => <<~'RUBY',
      class IndustrialRaverMonkey < Creature
        life 46        # mostly glowsticks
        strength 35    # has danced since 1996
        charisma 91    # the headphones help
        weapon 2       # a stick that glows
      end
    RUBY
    "DwarvenAngel" => <<~'RUBY',
      class DwarvenAngel < Creature
        life 540       # halos are sturdy
        strength 6     # very short arms
        charisma 144   # sings a low baritone
        weapon 50      # a blessed axe
      end
    RUBY
    "AssistantViceTentacleAndOmbudsman" => <<~'RUBY',
      class AssistantViceTentacleAndOmbudsman < Creature
        life 320       # has filed a complaint
        strength 6     # mostly damp
        charisma 144   # went to a workshop
        weapon 50      # form 27-B, in triplicate
      end
    RUBY
    "TeethDeer" => <<~'RUBY',
      class TeethDeer < Creature
        life 655       # so many teeth
        strength 192   # the antlers are for show
        charisma 19    # it is the teeth
        weapon 109     # teeth
      end
    RUBY
    "IntrepidDecomposedCyclist" => <<~'RUBY',
      class IntrepidDecomposedCyclist < Creature
        life 901       # has already died once
        strength 560   # calves of iron
        charisma 422   # rides with no hands
        weapon 105     # the bell. ding ding.
      end
    RUBY
    "Dragon" => <<~'RUBY',
      class Dragon < Creature
        life 1340      # scales like roof tiles
        strength 451   # bristling
        charisma 1020  # a winning smile
        weapon 939     # fire, obviously
      end
    RUBY
  }

  RABBIT = <<~'RUBY'
    class Rabbit < Creature
      traits :bombs

      life 10
      strength 2
      charisma 44
      weapon 4
      bombs 3

      # the boomerang: small, loyal,
      # always comes back
      def ^( enemy )
        fight( enemy, 13 )
      end

      # the sword never runs out, and cuts
      # deepest when their life ends in 9
      def /( enemy )
        cut = ( enemy.life % 10 ) ** 2
        fight( enemy, rand( 4 + cut ) )
      end

      # lettuce: crunchy life for you, and
      # a leaf in the enemy's face
      def %( enemy )
        lettuce = rand( charisma )
        puts "[Healthy lettuce gives you #{ lettuce } life points!!]"
        @life += lettuce
        fight( enemy, 0 )
      end

      # three bombs. only three.
      def *( enemy )
        if @bombs.zero?
          puts "[UHN!! You're out of bombs!!]"
          return
        end
        @bombs -= 1
        fight( enemy, 86 )
      end
    end
  RUBY

  module_eval(CREATURE, "creature.rb", 1)
  module_eval(ARRAY, "dwemthys_array.rb", 1)
  MONSTERS.each_value { |source| module_eval(source, "monsters.rb", 1) }

  # Where each new rabbit.rb is compiled. Its Rabbit is thrown away and made again every
  # time, so you may change anything, the superclass included.
  module Hutch
    Creature = Dwemthy::Creature
  end

  # The weapons a Rabbit can carry: any of these it defines becomes a button.
  WEAPONS = %w[^ / % * + - & | ** << >>]

  def self.compile(source)
    Hutch.send(:remove_const, :Rabbit) if Hutch.const_defined?(:Rabbit, false)
    Hutch.module_eval(source, "rabbit.rb", 1)
    raise NameError, "rabbit.rb has to define a class called Rabbit" unless Hutch.const_defined?(:Rabbit, false)

    klass = Hutch.const_get(:Rabbit, false)
    raise TypeError, "Rabbit has to be a Creature (class Rabbit < Creature)" unless klass.is_a?(Class) && klass < Creature

    klass.new
  end

  def self.weapons(rabbit)
    WEAPONS.select { |op| rabbit.class.public_method_defined?(op) }
  end

  def self.fresh_array
    DwemthysArray[*MONSTERS.keys.map { |name| const_get(name).new }]
  end
end

# A beat is one step of the show the stage puts on: some frames long, with something to
# do as it starts, on each frame (t runs from 0 to 1), and as it ends.
StageBeat = Struct.new(:frames, :start, :tick, :finish, :age)

# Bacon, for the end.
Rasher = Struct.new(:slot, :x, :y, :vx, :vy, :sway, :phase)

# ------------------------------------------------------------------------------ the look

W, H = 960, 640
HEAD = 56              # the bar across the top
ARENA_W, ARENA_H = 600, 370
FLOOR = 326            # where the creatures stand, in the arena
FPS = 30

INK = "#2b1d17"
PAPER = "#fbf3e4"
PAPER_DEEP = "#efdcbc"
NIGHT = "#2a1f3d"
TERM = "#1d1925"
TERM_TEXT = "#efe3cc"
FOX = "#e8743b"
BACON = "#c0392b"
LEAF = "#6ab04c"
GOLD = "#f7c948"
MONO = "monospace"

FONT_DIRS = %w[fonts . ../../kids/_fonts ../../../../fonts]
def dwemthy_font(file, fallback)
  path = FONT_DIRS.map { |dir| File.expand_path("#{dir}/#{file}", __dir__) }.find { |f| File.exist?(f) }
  (path && font(path)&.first) || fallback
end
ROUND = dwemthy_font("Fredoka.ttf", "Arial Rounded MT Bold, Helvetica, sans-serif")
SCRIPT = dwemthy_font("Pacifico.ttf", "Georgia, serif")

# Where the rabbit's source, and the count of fallen rabbits, are kept between runs.
DATA_DIR = if RUBY_PLATFORM.include?("darwin")
  File.join(Dir.home, "Library", "Application Support", "Dwemthy's Array")
else
  File.join(ENV.fetch("XDG_DATA_HOME", File.join(Dir.home, ".local", "share")), "dwemthys_array")
end
SAVE = File.join(DATA_DIR, "rabbit.json")

# ------------------------------------------------------------------------------ the sound
#
# Each sound is written once as a WAV and handed to afplay (macOS) in the background.
# Where there is no afplay the game is silent.
module Chime
  RATE = 22_050
  DIR = Dir.mktmpdir("dwemthy-sounds")
  at_exit { FileUtils.rm_rf(DIR) }

  class << self
    attr_accessor :muted

    # notes: [[hz, seconds], ...] played one after another; hz 0 is a rest, :noise a thump
    def play(name, notes, volume = 0.22)
      return if muted

      path = File.join(DIR, "#{name}.wav")
      write(path, notes, volume) unless File.exist?(path)
      Process.detach(spawn("afplay", path, out: File::NULL, err: File::NULL))
    rescue SystemCallError
      # no afplay here: stay silent
    end

    private

    def write(path, notes, volume)
      rng = Random.new(7)
      samples = notes.flat_map do |hz, seconds|
        n = (RATE * seconds).round
        Array.new(n) do |i|
          t = i.fdiv(RATE)
          fade = [t / 0.004, (seconds - t) / 0.03, 1].min
          wave = case hz
          when 0 then 0
          when :noise then (rng.rand * 2 - 1) * Math.exp(-t * 9)
          else Math.sin(2 * Math::PI * hz * t) * 0.8 + Math.sin(4 * Math::PI * hz * t) * 0.2
          end
          (wave * volume * fade * 32_767).round
        end
      end
      data = samples.pack("s<*")
      header = ["RIFF", 36 + data.bytesize, "WAVE", "fmt ", 16, 1, 1, RATE, RATE * 2, 2, 16, "data", data.bytesize]
      File.binwrite(path, header.pack("a4Va4a4VvvVVvva4V") + data)
    end
  end
end

SOUNDS = {
  boomerang: [[660, 0.05], [880, 0.05], [660, 0.05]],
  sword: [[1320, 0.04], [990, 0.08]],
  lettuce: [[392, 0.05], [523, 0.05], [659, 0.08]],
  bomb: [[:noise, 0.45]],
  thump: [[147, 0.09]],
  magick: [[784, 0.05], [988, 0.05], [1175, 0.05], [1568, 0.1]],
  fall: [[392, 0.09], [330, 0.09], [262, 0.09], [196, 0.2]],
  emerge: [[110, 0.12], [0, 0.04], [110, 0.12], [147, 0.2]],
  reborn: [[523, 0.06], [659, 0.06], [784, 0.06], [1047, 0.14]],
  oops: [[220, 0.08], [208, 0.14]],
  bacon: [[523, 0.1], [659, 0.1], [784, 0.1], [1047, 0.1], [0, 0.05], [784, 0.08], [1047, 0.3]],
}

Shoes.app(title: "Dwemthy's Array", width: W, height: H, resizable: false) do
  # ---------------------------------------------------------------- saving

  def load_state
    data = JSON.parse(File.read(SAVE))
    data.is_a?(Hash) ? data : {}
  rescue Errno::ENOENT, JSON::ParserError
    {}
  end

  def save_state
    FileUtils.mkdir_p(DATA_DIR)
    data = { "source" => @source, "rabbits_lost" => @rabbits_lost, "wins" => @wins, "muted" => Chime.muted }
    File.write("#{SAVE}.tmp", JSON.pretty_generate(data))
    File.rename("#{SAVE}.tmp", SAVE)
  rescue SystemCallError
    # a full disk should not stop the fight
  end

  def sound(name)
    Chime.play(name, SOUNDS.fetch(name))
  end

  # What the last run left behind: the rabbit.rb you wrote, and how many rabbits it cost.
  saved = load_state
  @rabbits_lost = saved["rabbits_lost"].to_i
  @wins = saved["wins"].to_i
  Chime.muted = saved["muted"] == true
  @source = saved["source"].is_a?(String) ? saved["source"] : Dwemthy::RABBIT

  # ---------------------------------------------------------------- drawing kit
  #
  # Every creature is drawn in a 100 x 100 box and scaled by @k, so the same drawing
  # serves the Array in the header, the line-up on the title page and the arena.

  def kk(v)
    (v * @k).round(2)
  end

  # The x of a point, turned round when the creature faces the other way.
  def kx(x)
    kk(@flip ? 100 - x : x)
  end

  def ink(width = 1.1, color = INK)
    stroke color
    strokewidth [width * @k, 0.6].max.round(2)
  end

  def ov(x, y, w, h = w)
    oval(kx(x), kk(y), kk(w), kk(h), center: true)
  end

  def rc(x, y, w, h, curve = 0)
    rect(kx(@flip ? x + w : x), kk(y), kk(w), kk(h), kk(curve))
  end

  def ln(x1, y1, x2, y2)
    line(kx(x1), kk(y1), kx(x2), kk(y2))
  end

  # A path from steps like [:m, x, y], [:l, x, y] and [:c, x1, y1, x2, y2, x, y].
  def trace(*steps)
    shape do
      steps.each do |cmd, *xy|
        xy = xy.each_slice(2).flat_map { |x, y| [kx(x), kk(y)] }
        case cmd
        when :m then move_to(*xy)
        when :l then line_to(*xy)
        when :c then curve_to(*xy)
        end
      end
    end
  end

  # The same path, flipped left to right across the box.
  def mirrored(*steps)
    steps.map do |cmd, *xy|
      [cmd, *xy.each_slice(2).flat_map { |x, y| [100 - x, y] }]
    end
  end

  # A limb, an antler, a tentacle: a thick line with an ink outline.
  def tube(color, width, *steps)
    nofill
    cap :curve
    ink(width + 2.2)
    trace(*steps)
    ink(width, color)
    trace(*steps)
    cap :rect
  end

  def eye_glint(x, y, size)
    nostroke
    fill white
    ov(x, y, size)
  end

  # ---------------------------------------------------------------- the bestiary

  def draw_rabbit
    tube("#fffaf2", 3, [:m, 26, 92], [:c, 22, 86, 24, 80, 30, 78]) # a hind leg, tucked
    ink
    fill "#efe3dc"
    trace [:m, 52, 42], [:c, 52, 24, 62, 4, 70, 6], [:c, 78, 8, 68, 30, 60, 46], [:l, 52, 42]
    fill "#fffaf2"
    trace [:m, 42, 44], [:c, 32, 30, 28, 6, 36, 4], [:c, 44, 2, 50, 26, 52, 42], [:l, 42, 44]
    nostroke
    fill "#f6a5b4"
    trace [:m, 43, 38], [:c, 37, 28, 35, 12, 38, 10], [:c, 42, 10, 46, 26, 48, 38], [:l, 43, 38]
    ink
    fill white
    ov 20, 72, 16
    fill "#fffaf2"
    ov 46, 74, 50, 40
    ov 38, 94, 20, 8
    ov 62, 94, 20, 8
    ov 60, 52, 40, 34
    fill "#d64541"
    trace [:m, 46, 64], [:c, 38, 60, 30, 66, 22, 58], [:l, 24, 68], [:c, 32, 72, 40, 71, 48, 70]
    trace [:m, 45, 63], [:c, 55, 70, 67, 70, 76, 63], [:l, 76, 68], [:c, 67, 76, 53, 76, 45, 69], [:l, 45, 63]
    nostroke
    fill INK
    ov 68, 48, 6, 7
    eye_glint(69.2, 46.4, 2.2)
    fill rgb(246, 140, 160, 0.5)
    ov 66, 58, 9, 5
    fill "#f08a9c"
    ov 79, 52, 5, 4
    ink(0.7)
    nofill
    trace [:m, 75, 56], [:c, 76, 58.5, 78.5, 58.5, 79, 55]
    ln 82, 53, 94, 50
    ln 82, 55, 94, 57
  end

  def draw_monkey
    tube("#7a4b2e", 4, [:m, 66, 84], [:c, 84, 88, 92, 70, 82, 64], [:c, 76, 60, 74, 70, 80, 72])
    tube("#8a5a3b", 7, [:m, 36, 62], [:c, 28, 54, 22, 44, 20, 34])
    tube("#8a5a3b", 7, [:m, 64, 62], [:c, 72, 54, 78, 44, 80, 34])
    nostroke
    fill rgb(124, 255, 79, 0.28)
    ov 18, 22, 20, 28
    fill rgb(255, 79, 216, 0.28)
    ov 82, 22, 20, 28
    tube("#9dff6e", 3.5, [:m, 16, 34], [:l, 21, 12])
    tube("#ff6ee0", 3.5, [:m, 84, 34], [:l, 79, 12])
    ink
    fill "#e6c39b"
    ov 20, 33, 9
    ov 80, 33, 9
    fill "#8a5a3b"
    ov 40, 92, 16, 10
    ov 60, 92, 16, 10
    ov 50, 72, 40, 40
    fill "#e6c39b"
    ov 50, 76, 24, 26
    tube("#ff3b6b", 2.6, [:m, 31, 38], [:c, 30, 12, 70, 12, 69, 38])
    ink
    fill "#8a5a3b"
    ov 50, 40, 36, 34
    fill "#ff3b6b"
    rc 25, 32, 9, 15, 3
    rc 66, 32, 9, 15, 3
    fill "#e6c39b"
    ov 50, 46, 28, 22
    fill "#1b1b2f"
    rc 37, 33, 11, 7, 2
    rc 52, 33, 11, 7, 2
    ln 48, 35.5, 52, 35.5
    nostroke
    fill rgb(255, 255, 255, 0.55)
    rc 39, 34.2, 4, 2, 1
    rc 54, 34.2, 4, 2, 1
    ink(0.8)
    fill white
    trace [:m, 42, 47], [:c, 45, 56, 55, 56, 58, 47], [:c, 54, 49.5, 46, 49.5, 42, 47]
    nostroke
    fill INK
    ov 47.5, 43, 1.6
    ov 52.5, 43, 1.6
  end

  def draw_angel
    wing = [[:m, 38, 54], [:c, 22, 30, 4, 32, 6, 44], [:c, 12, 46, 8, 54, 14, 56], [:c, 18, 60, 16, 66, 24, 66], [:c, 30, 64, 34, 62, 38, 60]]
    ink(0.9, "#9aa7b8")
    fill "#ffffff"
    trace(*wing)
    trace(*mirrored(*wing))
    nostroke
    fill rgb(247, 201, 72, 0.25)
    ov 50, 12, 38, 14
    nofill
    stroke GOLD
    strokewidth [3 * @k, 1].max
    ov 50, 12, 28, 7
    tube("#9fc2f5", 6, [:m, 64, 60], [:l, 80, 66])
    tube("#7a4b2e", 2.4, [:m, 80, 40], [:l, 85, 92])
    ink
    fill "#c9d1d9".."#8d99a6"
    trace [:m, 80, 42], [:c, 90, 32, 98, 42, 94, 54], [:c, 90, 50, 86, 50, 82, 50], [:l, 80, 42]
    fill "#cfe3ff".."#9fc2f5"
    trace [:m, 34, 54], [:l, 66, 54], [:c, 72, 70, 76, 86, 78, 96], [:l, 22, 96], [:c, 24, 86, 28, 70, 34, 54]
    fill "#7a4b2e"
    rc 29, 72, 42, 5
    fill GOLD
    rc 47, 71, 6, 7, 1
    fill "#5a3a22"
    ov 38, 96, 14, 6
    ov 62, 96, 14, 6
    fill "#f2c29b"
    ov 82, 66, 8
    fill "#e0702b"
    ov 40, 26, 9
    ov 50, 23, 10
    ov 60, 26, 9
    fill "#f2c29b"
    ov 50, 36, 28, 26
    fill "#e0702b".."#b4501c"
    trace [:m, 36, 38], [:c, 34, 56, 42, 74, 50, 80], [:c, 58, 74, 66, 56, 64, 38], [:c, 58, 47, 42, 47, 36, 38]
    fill "#c25a20"
    ov 45, 44, 11, 5
    ov 55, 44, 11, 5
    fill "#e8907a"
    ov 50, 40, 7, 6
    nostroke
    fill INK
    ov 44, 33, 3
    ov 56, 33, 3
    ink(1.6)
    ln 40, 29, 47, 31
    ln 53, 31, 60, 29
  end

  def draw_tentacle
    purple = "#7d4cc9"
    tube(purple, 7, [:m, 36, 60], [:c, 26, 72, 34, 86, 22, 94])
    tube(purple, 7, [:m, 44, 64], [:c, 42, 80, 48, 88, 40, 96])
    tube(purple, 7, [:m, 56, 64], [:c, 58, 80, 52, 88, 62, 96])
    ink
    fill "#a0703c"
    rc 76, 50, 20, 26, 2
    fill white
    rc 78.5, 54, 15, 19
    fill "#9aa7b8"
    rc 82, 48, 8, 4, 1
    ink(0.5, "#9aa7b8")
    [58, 62, 66, 70].each { |y| ln 80.5, y, 91.5, y }
    tube(purple, 7, [:m, 64, 60], [:c, 74, 70, 76, 60, 84, 64])
    ink
    fill "#9a6be0".."#6a3fb0"
    ov 50, 38, 54, 50
    nostroke
    fill rgb(255, 255, 255, 0.18)
    ov 36, 24, 10, 7
    ov 64, 22, 7, 5
    ov 30, 42, 6
    ink(0.8)
    fill white
    trace [:m, 40, 58], [:l, 50, 63], [:l, 44, 69], [:l, 40, 58]
    trace [:m, 60, 58], [:l, 50, 63], [:l, 56, 69], [:l, 60, 58]
    fill "#d64541"
    trace [:m, 48, 63], [:l, 52, 63], [:l, 54, 80], [:l, 50, 86], [:l, 46, 80], [:l, 48, 63]
    fill white
    rc 28, 60, 12, 7, 1
    nostroke
    fill BACON
    rc 30, 62, 8, 1.2
    nofill
    ink(1.2)
    ov 41, 37, 14
    ov 59, 37, 14
    ln 48, 37, 52, 37
    ln 27, 36, 34, 37
    ln 73, 36, 66, 37
    nostroke
    fill INK
    ov 41, 39, 3.4
    ov 59, 39, 3.4
    ink(1)
    ln 35, 36, 47, 36
    ln 53, 36, 65, 36
    ln 45, 50, 55, 50
  end

  def draw_deer
    tube("#9a5f2e", 3.5, [:m, 46, 78], [:l, 44, 95])
    tube("#9a5f2e", 3.5, [:m, 54, 80], [:l, 56, 95])
    tube("#9a5f2e", 3.5, [:m, 74, 78], [:l, 72, 95])
    tube("#9a5f2e", 3.5, [:m, 82, 78], [:l, 84, 95])
    ink
    fill white
    ov 89, 60, 8, 11
    fill "#c98a4b".."#a8682f"
    ov 65, 67, 48, 28
    trace [:m, 40, 68], [:c, 36, 58, 32, 50, 28, 44], [:l, 42, 38], [:c, 46, 50, 52, 56, 58, 60], [:l, 40, 68]
    nostroke
    fill rgb(255, 255, 255, 0.7)
    [[60, 58], [68, 60], [76, 58], [72, 64], [64, 64]].each { |x, y| ov x, y, 3.5 }
    tube("#ead7a8", 2.4, [:m, 30, 31], [:c, 26, 22, 22, 14, 18, 6])
    tube("#ead7a8", 2.4, [:m, 24, 18], [:l, 13, 15])
    tube("#ead7a8", 2.4, [:m, 21, 11], [:l, 26, 3])
    tube("#ead7a8", 2.4, [:m, 40, 30], [:c, 44, 22, 48, 14, 53, 6])
    tube("#ead7a8", 2.4, [:m, 46, 18], [:l, 57, 16])
    tube("#ead7a8", 2.4, [:m, 49, 11], [:l, 45, 3])
    ink
    fill "#b5773f"
    ov 22, 34, 13, 6
    ov 47, 32, 13, 6
    ov 34, 42, 26, 22
    fill "#e3b07d"
    ov 21, 50, 24, 17
    fill INK
    ov 10, 46, 6, 5
    fill white
    ink(1)
    rc 6, 51, 30, 12, 3
    ink(0.7)
    [10.5, 15, 19.5, 24, 28.5, 33].each { |x| ln x, 51, x, 63 }
    ln 6, 57, 36, 57
    ink
    fill white
    ov 37, 37, 11, 12
    nostroke
    fill INK
    ov 35, 38, 3.6
  end

  def draw_cyclist
    nofill
    ink(3.2, "#2f2a2a")
    ov 22, 80, 30
    ov 78, 80, 30
    @spokes = []
    ink(0.6, "#8a8f98")
    transform :center
    [22, 78].each do |cx|
      4.times do |i|
        a = i * Math::PI / 4
        @spokes << ln(cx - 13 * Math.cos(a), 80 - 13 * Math.sin(a), cx + 13 * Math.cos(a), 80 + 13 * Math.sin(a))
      end
    end
    transform :corner
    red = "#d64541"
    tube(red, 1.8, [:m, 22, 80], [:l, 32, 58])
    tube(red, 1.8, [:m, 33, 61], [:l, 52, 80], [:l, 78, 80], [:l, 60, 61], [:l, 33, 61])
    tube(red, 1.8, [:m, 52, 80], [:l, 60, 58])
    tube("#3a3a3a", 1.8, [:m, 32, 58], [:l, 30, 50], [:l, 25, 51])
    ink
    fill "#3a3a3a"
    rc 55, 54, 11, 4, 2
    tube("#5dade2", 3, [:m, 52, 36], [:c, 60, 34, 66, 40, 74, 32], [:c, 76, 30, 80, 34, 84, 30])
    tube("#5b6b8a", 4.5, [:m, 60, 57], [:l, 46, 68], [:l, 52, 81])
    tube("#7e8aa8", 4.5, [:m, 60, 58], [:l, 54, 70], [:l, 58, 82])
    tube("#8a7f5b", 9, [:m, 59, 55], [:l, 47, 39])
    tube("#9ccc65", 3.4, [:m, 47, 40], [:c, 40, 46, 34, 48, 28, 50])
    ink
    fill "#9ccc65"
    ov 27, 50, 6
    ov 41, 29, 20, 21
    fill GOLD
    trace [:m, 30, 27], [:c, 30, 14, 50, 12, 52, 25], [:l, 30, 27]
    ink(0.7)
    ln 38, 17, 39, 25
    ln 44, 16, 44, 24
    ink(1)
    ln 33, 30, 37, 34
    ln 37, 30, 33, 34
    fill white
    ov 43, 32, 7
    nostroke
    fill INK
    ov 42, 32.5, 2.6
    ink(0.9)
    ln 34, 37.5, 44, 38.5
    [36, 39, 42].each { |x| ln x, 36, x, 40 }
    nostroke
    fill INK
    [[56, 14], [62, 21], [50, 9]].each { |x, y| ov x, y, 1.8 }
  end

  def draw_dragon
    green = "#4caf50"
    ink
    fill green
    trace [:m, 74, 76], [:c, 90, 82, 98, 68, 92, 56], [:c, 98, 62, 96, 76, 82, 84], [:l, 74, 76]
    fill "#ff8f3a"
    trace [:m, 92, 56], [:l, 98, 46], [:l, 99, 60], [:l, 92, 56]
    fill "#2e7d32"
    trace [:m, 58, 56], [:c, 60, 32, 72, 14, 92, 6], [:c, 90, 18, 94, 26, 97, 32], [:c, 89, 32, 86, 40, 90, 46],
      [:c, 82, 44, 78, 50, 80, 58], [:c, 72, 54, 66, 56, 60, 62], [:l, 58, 56]
    fill green
    ov 74, 90, 16, 13
    ov 47, 90, 16, 13
    fill "#66bb6a".."#2e7d32"
    ov 62, 72, 46, 34
    fill "#fff3c4".."#ffd77a"
    ov 55, 79, 26, 20
    ink(0.6)
    ln 46, 75, 64, 75
    ln 45, 80, 65, 80
    ln 47, 85, 63, 85
    ink
    fill "#ff8f3a"
    [[56, 56], [64, 55.5], [72, 57], [80, 60]].each do |x, y|
      trace [:m, x - 3.5, y + 1], [:l, x, y - 6], [:l, x + 3.5, y + 1], [:l, x - 3.5, y + 1]
    end
    fill green
    trace [:m, 46, 64], [:c, 40, 52, 36, 46, 34, 40], [:l, 46, 34], [:c, 48, 42, 54, 50, 62, 58], [:l, 46, 64]
    fill "#f5e6c8"
    trace [:m, 34, 24], [:c, 38, 12, 44, 8, 50, 6], [:c, 46, 14, 42, 20, 40, 26], [:l, 34, 24]
    trace [:m, 40, 26], [:c, 46, 18, 52, 16, 56, 15], [:c, 52, 20, 48, 24, 45, 28], [:l, 40, 26]
    fill green
    ov 32, 33, 28, 22
    trace [:m, 26, 26], [:c, 14, 24, 4, 28, 3, 35], [:c, 3, 42, 16, 44, 30, 42], [:l, 26, 26]
    fill white
    [[10, 39.4], [15, 40.4], [20, 40.6], [25, 40]].each do |x, y|
      trace [:m, x - 2, y], [:l, x, y + 3.6], [:l, x + 2, y], [:l, x - 2, y]
    end
    nofill
    ink(1)
    trace [:m, 5, 38], [:c, 14, 42, 24, 41.5, 30, 37]
    fill "#ffe14d"
    ink(0.8)
    ov 32, 29, 8, 6
    nostroke
    fill INK
    ov 32, 29, 1.8, 5
    ov 8, 31, 2.2
    fill rgb(160, 160, 160, 0.35)
    ov 4, 24, 6
    ov 0, 18, 4
  end

  # Foxes, who have one thing to say.
  def draw_fox
    ink
    fill FOX
    trace [:m, 34, 82], [:c, 8, 88, 0, 62, 8, 50], [:c, 16, 62, 24, 70, 36, 72], [:l, 34, 82]
    fill white
    trace [:m, 8, 50], [:c, 4, 58, 6, 66, 10, 70], [:c, 12, 62, 12, 56, 8, 50]
    fill "#5a3a22"
    ov 42, 95, 9, 6
    ov 56, 95, 9, 6
    fill FOX
    ov 48, 78, 34, 30
    fill white
    ov 52, 81, 16, 20
    fill FOX
    trace [:m, 36, 42], [:l, 33, 16], [:l, 50, 34], [:l, 36, 42]
    trace [:m, 58, 34], [:l, 71, 16], [:l, 68, 42], [:l, 58, 34]
    nostroke
    fill "#5a3a22"
    trace [:m, 36.5, 30], [:l, 34.2, 18.5], [:l, 43, 27], [:l, 36.5, 30]
    trace [:m, 63, 27], [:l, 69.8, 18.5], [:l, 67.8, 30], [:l, 63, 27]
    ink
    fill FOX
    ov 52, 48, 40, 32
    fill "#7a1f1f"
    trace [:m, 45, 60], [:c, 45, 72, 59, 72, 59, 60], [:l, 45, 60]
    nostroke
    fill "#e86f6f"
    ov 52, 67, 7, 4
    ink
    fill white
    ov 43.5, 56, 15, 10
    ov 60.5, 56, 15, 10
    fill INK
    ov 52, 52.5, 6, 4.5
    nofill
    ink(1.4)
    trace [:m, 39, 46], [:c, 41, 41, 45, 41, 47, 46]
    trace [:m, 57, 46], [:c, 59, 41, 63, 41, 65, 46]
  end

  BESTIARY = {
    "Rabbit" => :draw_rabbit, "IndustrialRaverMonkey" => :draw_monkey, "DwarvenAngel" => :draw_angel,
    "AssistantViceTentacleAndOmbudsman" => :draw_tentacle, "TeethDeer" => :draw_deer,
    "IntrepidDecomposedCyclist" => :draw_cyclist, "Dragon" => :draw_dragon, "Fox" => :draw_fox
  }
  # How big each one stands in the arena, as a scale on its 100 px box.
  STATURE = {
    "Rabbit" => 1.55, "IndustrialRaverMonkey" => 2.0, "DwarvenAngel" => 1.95, "AssistantViceTentacleAndOmbudsman" => 2.1,
    "TeethDeer" => 2.3, "IntrepidDecomposedCyclist" => 2.3, "Dragon" => 2.65
  }
  NICKNAMES = {
    "IndustrialRaverMonkey" => "the Industrial Raver Monkey", "DwarvenAngel" => "the Dwarven Angel",
    "AssistantViceTentacleAndOmbudsman" => "the Assistant Vice Tentacle and Ombudsman", "TeethDeer" => "the Teeth Deer",
    "IntrepidDecomposedCyclist" => "the Intrepid Decomposed Cyclist", "Dragon" => "the Dragon"
  }

  # A creature drawn into a placed slot of its own, so it moves as one piece.
  def creature(kind, left, top, scale, flip: false)
    size = (100 * scale).round
    stack(left: left, top: top, width: size, height: size) do
      @k = scale
      @flip = flip
      send(BESTIARY.fetch(kind, :draw_rabbit))
      @flip = false
      transform :corner
    end
  end

  # ---------------------------------------------------------------- bits of UI

  # A chunky button: a rounded card that does something when pressed. Its words are a link
  # without the underline, so a screen reader finds something it can press.
  def chunky(label, width:, color: FOX, text: white, size: 16, &action)
    stack(width: width, margin: 4) do
      background color, curve: 12
      border INK, strokewidth: 2, curve: 12
      para quiet_link(label, text, &action), font: ROUND, size: size, align: "center", margin: [0, 8, 0, 8]
      click { action.call }
    end
  end

  def quiet_link(label, color, &action)
    link(label, stroke: color, underline: "none") { action.call }
  end

  SYNTAX = {
    comment: "#9b8fb0", keyword: "#ff8fb1", string: "#b6f09c", number: "#ffc66d",
    symbol: "#8fd3ff", ivar: "#f6b26b", const: "#f7e08a", plain: TERM_TEXT,
  }
  KEYWORDS = %w[class def end if else elsif unless return do include self super yield rescue while case when then]

  # Ruby, coloured the way an editor would: one para per line, a span per run of colour.
  def code_lines(source, size: 11)
    source.lines.map(&:chomp).each do |line|
      bits = ruby_bits(line)
      bits = [[" ", :plain]] if bits.empty?
      para(*bits.map { |text, kind| span(text, stroke: SYNTAX[kind]) }, font: MONO, size: size, margin: 0)
    end
  end

  def ruby_bits(line)
    code, comment = split_comment(line)
    bits = code.scan(/"(?:[^"\\]|\\.)*"?|:\w+|@\w+|\b\d+\b|\b[A-Z]\w*|\b\w+[?!]?|\s+|./).map do |token|
      kind = case token
      when /\A"/ then :string
      when /\A:\w/ then :symbol
      when /\A@/ then :ivar
      when /\A\d/ then :number
      when /\A[A-Z]/ then :const
      when *KEYWORDS then :keyword
      else :plain
      end
      [token, kind]
    end
    bits << [comment, :comment] if comment
    # neighbours of one colour share a span
    bits.chunk_while { |a, b| a[1] == b[1] || b[0].strip.empty? }.map { |run| [run.map(&:first).join, run.first[1]] }
  end

  # Splits "code # comment" at the first # outside a string.
  def split_comment(line)
    quoted = false
    line.each_char.with_index do |ch, i|
      quoted = !quoted if ch == '"' && (i.zero? || line[i - 1] != "\\")
      return [line[0...i], line[i..]] if ch == "#" && !quoted && line[i + 1] != "{"
    end
    [line, nil]
  end

  def dusk(width, height, clear: nil)
    background "#33265a".."#e9926b"
    nostroke
    fill rgb(255, 244, 214, 0.9)
    oval width - 120, 40, 46
    fill "#33265a"
    oval width - 108, 34, 44
    fill rgb(255, 255, 255, 0.8)
    srand_sky = Random.new(2004)
    50.times do
      x = srand_sky.rand(width)
      y = srand_sky.rand(height * 0.45)
      size = srand_sky.rand(1.0..2.6)
      next if clear&.any? { |l, t, r, b| x.between?(l, r) && y.between?(t, b) }

      oval x, y, size
    end
  end

  def hills(width, floor)
    nostroke
    fill "#59406e"
    shape do
      move_to 0, floor - 40
      curve_to width * 0.2, floor - 120, width * 0.35, floor - 70, width * 0.5, floor - 90
      curve_to width * 0.65, floor - 110, width * 0.85, floor - 50, width, floor - 100
      line_to width, floor + 10
      line_to 0, floor + 10
    end
    fill "#3e2c52"
    shape do
      move_to 0, floor - 10
      curve_to width * 0.25, floor - 60, width * 0.55, floor - 20, width * 0.7, floor - 45
      curve_to width * 0.85, floor - 60, width * 0.95, floor - 30, width, floor - 40
      line_to width, floor + 10
      line_to 0, floor + 10
    end
  end

  # ---------------------------------------------------------------- the game's state

  def new_game
    @array = Dwemthy.fresh_array
    Dwemthy.array = @array
    @turns = 0
    @deaths_this_run = 0
    # a rabbit.rb saved last time that no longer compiles gives way to _why's
    compile(Dwemthy::RABBIT) if compile(@source)
  end

  # Builds a Rabbit from rabbit.rb. Returns an error message, or nil when it worked.
  def compile(source)
    rabbit = Dwemthy.compile(source)
    @source = source
    @rabbit = rabbit
    @rabbit_max = [@rabbit.life.to_i, 1].max
    Dwemthy.rabbit = @rabbit
    save_state
    nil
  rescue ScriptError, StandardError, SystemStackError => e
    first = e.message.lines.first.to_s.strip
    first.empty? ? e.class.name : first
  end

  # ---------------------------------------------------------------- the title page

  url "/", :home
  url "/fight", :arena
  url "/creature", :engine
  url "/victory", :victory

  def home
    @on_sound = nil
    dusk(W, H, clear: [[150, 20, 810, 140], [60, 150, 900, 330]])
    hills(W, 520)
    nostroke
    fill "#2d2140"
    rect 0, 510, W, H - 510

    stack(left: 0, top: 22, width: W) do
      para "Dwemthy's Array", font: SCRIPT, size: 64, stroke: PAPER, align: "center", margin: 0
      para "a little adventure in Ruby, after why the lucky stiff", font: ROUND, size: 17, stroke: "#f6d6b8", align: "center", margin: [0, 12, 0, 0]
    end

    # The Array, literally: six monsters between square brackets.
    names = Dwemthy::MONSTERS.keys
    span = 116
    left = (W - names.size * span) / 2 + 6
    para "[", font: MONO, size: 120, stroke: PAPER, left: left - 62, top: 150, margin: 0
    para "]", font: MONO, size: 120, stroke: PAPER, left: left + names.size * span - 14, top: 150, margin: 0
    @lineup = names.each_with_index.map do |name, i|
      x = left + i * span
      para ",", font: MONO, size: 60, stroke: PAPER, left: x + 98, top: 236, margin: 0 if i < names.size - 1
      { slot: creature(name, x, 196, 1.02), x: x, y: 196, phase: i * 0.9 }
    end

    @hero = creature("Rabbit", 120, 412, 1.05)
    stack(left: 196, top: 392, width: 72) do
      background PAPER, curve: 10
      border INK, strokewidth: 1.5, curve: 10
      para "...oh.", font: ROUND, size: 14, stroke: INK, align: "center", margin: [0, 6, 0, 6]
    end

    stack(left: 300, top: 368, width: 600) do
      para "You are a Rabbit. You have a boomerang, a sword, some lettuce and three bombs. ",
        "Ahead of you stands an Array of six monsters, each worse than the last. It is not a fair fight.",
        font: ROUND, size: 15, stroke: PAPER, margin: [0, 0, 0, 6]
      para "But you also have the Rabbit's source code, and nobody said you couldn't change it.",
        font: ROUND, size: 15, stroke: GOLD, margin: [0, 0, 0, 14]
      flow do
        chunky(@array && !@array.empty? && @turns.to_i > 0 ? "Back to the Array" : "Enter the Array", width: 210, size: 18) { start_run }
        chunky("Read creature.rb", width: 190, color: PAPER, text: INK) { visit "/creature" }
        toggle = chunky(sound_label, width: 130, color: "#4a3a63", text: PAPER, size: 14) { toggle_sound }
        @on_sound = -> { toggle.contents.grep(Shoes::Para).each { |c| c.replace quiet_link(sound_label, PAPER) { toggle_sound } } }
      end
    end

    # Every rabbit that fell is remembered.
    lost = @rabbits_lost.to_i
    if lost > 0
      lost.clamp(0, 14).times do |i|
        x = 26 + i * 24
        stroke "#1b1426"
        strokewidth 1.5
        fill "#8d8399".."#6a6077"
        rect x, 572 + (i.odd? ? 3 : 0), 18, 24, 7
        stroke "#4a4157"
        line x + 9, 577 + (i.odd? ? 3 : 0), x + 9, 587 + (i.odd? ? 3 : 0)
        line x + 5, 580 + (i.odd? ? 3 : 0), x + 13, 580 + (i.odd? ? 3 : 0)
      end
      words = lost == 1 ? "1 rabbit has fallen in the Array." : "#{lost} rabbits have fallen in the Array."
      para words, " They are remembered.", font: ROUND, size: 12, stroke: "#bfa9d6",
        left: 26 + [lost, 14].min * 24 + 8, top: 580, margin: 0
    end
    para "^ / % * attack  ·  M mutes", font: ROUND, size: 12, stroke: "#bfa9d6", left: W - 196, top: 612, margin: 0

    keypress do |key|
      toggle_sound if key == "m" || key == "M"
      start_run if key == "\n"
    end

    animate(FPS) do |frame|
      @lineup.each do |m|
        m[:slot].move(m[:x], (m[:y] + Math.sin(frame / 9.0 + m[:phase]) * 4).round)
      end
      @hero.move(120, (412 - (Math.sin(frame / 6.0).abs * 8)).round)
    end
  end

  def start_run
    new_game if @array.nil? || @array.empty? || @rabbit.nil?
    visit "/fight"
  end

  def sound_label
    Chime.muted ? "sound: off" : "sound: on"
  end

  def toggle_sound
    Chime.muted = !Chime.muted
    @on_sound&.call
    save_state
  end

  # ---------------------------------------------------------------- creature.rb

  def engine
    @on_sound = nil
    background PAPER
    stack(left: 0, top: 0, width: W, height: 64) do
      background NIGHT
      para "creature.rb", font: MONO, size: 22, stroke: PAPER, left: 24, top: 16, margin: 0
      para "the engine under every monster, and under you", font: ROUND, size: 15, stroke: "#bfa9d6", left: 210, top: 22, margin: 0
      para link("back to the Array", click: "/"), font: ROUND, size: 15, left: W - 170, top: 22, margin: 0
    end
    stack(left: 24, top: 80, width: 430, height: 544, scroll: true) do
      background TERM, curve: 10
      stack(margin: 14) do
        code_lines(Dwemthy::CREATURE, size: 11)
        para " ", font: MONO, size: 11, margin: 0
        code_lines(Dwemthy::ARRAY, size: 11)
      end
    end
    stack(left: 474, top: 80, width: 462) do
      para "How a monster is made", font: ROUND, size: 22, stroke: INK, margin: [0, 0, 0, 6]
      para "A monster is a class with four numbers in it. ", code("traits"), " is a class method that ",
        "writes more methods: after ", code("traits :life"), ", any creature class can say ", code("life 46"),
        ", and every creature it makes starts out with 46 life. That is metaprogramming: code that writes code.",
        font: ROUND, size: 14, stroke: INK, margin: [0, 0, 0, 12]
      stack(margin: 0) do
        background TERM, curve: 10
        stack(margin: 12) { code_lines(Dwemthy::MONSTERS["TeethDeer"], size: 11) }
      end
      para "The Array forwards whatever you throw at it to the monster at the front, and when that ",
        "one falls, it shifts it off and the next one emerges. So ", code("rabbit ^ dwemthy"),
        " always hits whoever is standing there.",
        font: ROUND, size: 14, stroke: INK, margin: [0, 12, 0, 12]
      para "Your Rabbit is the same kind of thing. Its numbers are yours to change.",
        font: ROUND, size: 14, stroke: BACON, margin: [0, 0, 0, 14]
      chunky("To the Array", width: 180) { start_run }
    end
    creature("TeethDeer", 760, 456, 1.6)
    para "this one", font: ROUND, size: 13, stroke: "#6b5a48", left: 712, top: 590, margin: 0
    keypress { |key| visit "/" if key == :escape }
  end

  # ---------------------------------------------------------------- the fight

  def arena
    new_game if @array.nil? || @rabbit.nil?
    @beats = []
    @rabbit_off = [0, 0]
    @monster_off = [0, 0]
    @flash = 0
    @floats = []
    @overlay_up = false
    @status = nil
    @shown = { rabbit: @rabbit.life.to_i, monster: @array.first&.life.to_i }
    @shown_monster = @array.first

    background PAPER

    # The bar across the top: the name, and the Array as it stands.
    stack(left: 0, top: 0, width: W, height: HEAD) do
      background NIGHT
      para "Dwemthy's Array", font: SCRIPT, size: 22, stroke: PAPER, left: 18, top: 6, margin: 0
      @tokens = stack(left: 250, top: 0, width: 470, height: HEAD) {}
      note = para link(sound_label) { toggle_sound }, font: ROUND, size: 13, left: W - 200, top: 19, margin: 0
      @on_sound = -> { note.replace link(sound_label) { toggle_sound } }
      para link("menu", click: "/"), font: ROUND, size: 13, left: W - 90, top: 19, margin: 0
    end
    draw_tokens

    # The arena: the creatures, what they throw, and how they are doing.
    @stage = stack(left: 0, top: HEAD, width: ARENA_W, height: ARENA_H) do
      dusk(ARENA_W, ARENA_H)
      hills(ARENA_W, FLOOR)
      nostroke
      fill "#5a4636".."#2f241c"
      rect 0, FLOOR - 4, ARENA_W, ARENA_H - FLOOR + 4
      stroke rgb(0, 0, 0, 0.25)
      strokewidth 1
      [FLOOR + 10, FLOOR + 24].each { |y| line 0, y, ARENA_W, y }
      # the Array's own brackets, holding everything in
      nostroke
      fill rgb(251, 243, 228, 0.85)
      [[10, 14], [ARENA_W - 24, ARENA_W - 48]].each do |post, arm|
        rect post, 76, 14, ARENA_H - 92, 2
        rect [post, arm].min, 76, 38, 12, 2
        rect [post, arm].min, ARENA_H - 28, 38, 12, 2
      end
      @cast = stack(left: 0, top: 0, width: ARENA_W, height: ARENA_H) {}
      @fx = stack(left: 0, top: 0, width: ARENA_W, height: ARENA_H) {}
      @floaty = stack(left: 0, top: 0, width: ARENA_W, height: ARENA_H) {}
      @rabbit_card = life_card(16, 12)
      @monster_card = life_card(ARENA_W - 296, 12)
      @overlay = stack(left: 0, top: 0, width: ARENA_W, height: ARENA_H, hidden: true) {}
    end
    @cast.append { @rabbit_slot = creature("Rabbit", 80, rabbit_home_y, STATURE["Rabbit"]) }
    show_monster(@shown_monster)

    # The weapons, then the log of everything the Ruby said.
    @armory = flow(left: 0, top: HEAD + ARENA_H, width: ARENA_W, height: 82) {}
    stack(left: 0, top: HEAD + ARENA_H + 82, width: ARENA_W, height: H - HEAD - ARENA_H - 82) do
      background TERM
      @log = stack(left: 12, top: 6, width: ARENA_W - 18, height: H - HEAD - ARENA_H - 92, scroll: true) {}
    end

    # rabbit.rb, which you may edit, and the next monster's source, which you may not.
    stack(left: ARENA_W, top: HEAD, width: W - ARENA_W, height: H - HEAD) do
      background PAPER_DEEP
      stroke INK
      strokewidth 2
      line 1, 0, 1, H - HEAD
      stack(margin: [16, 10, 14, 0]) do
        flow do
          para "rabbit.rb", font: MONO, size: 17, stroke: INK, margin: [0, 0, 8, 0]
          para "you may edit this. you should.", font: ROUND, size: 13, stroke: BACON, margin: [0, 4, 0, 0]
        end
        @editor = edit_box(@source, width: 328, height: 290, font: "#{MONO} 11px", margin: [0, 6, 0, 6]) do
          @status.replace "changed. press Recompile to make a new Rabbit from it." if @status && @editor.text != @source
        end
        flow do
          chunky("Recompile the Rabbit", width: 200, size: 14) { recompile }
          stack(width: 128, margin: [6, 10, 0, 0]) do
            para link("restore _why's rabbit") { restore_rabbit }, font: ROUND, size: 12, margin: 0
          end
        end
        @status = para "", font: ROUND, size: 12, stroke: "#5a4636", margin: [2, 2, 0, 8]
        @wanted = stack(margin: 0) {}
      end
    end

    build_armory
    show_wanted
    refresh_cards
    if @rabbit.life.to_i <= 0
      show_overlay
    end
    if @turns.zero?
      count = @array.size == 1 ? "1 monster" : "#{@array.size} monsters"
      log_line("# #{count} in the Array. Pick a weapon, or press ^ / % *", :comment)
    end

    keypress do |key|
      case key
      when *Dwemthy.weapons(@rabbit) then attack(key)
      when "m", "M" then toggle_sound
      end
    end

    animate(FPS) do |frame|
      run_beats
      idle(frame)
      drift_floats
    end
  end

  def rabbit_home_y
    FLOOR - (100 * STATURE["Rabbit"]).round + 6
  end

  def monster_home(monster)
    kind = monster.class.to_s
    size = (100 * STATURE.fetch(kind, 2.0)).round
    [ARENA_W - 60 - size, FLOOR - size + 6]
  end

  def show_monster(monster, entering: false)
    @monster_slot&.remove
    @monster_slot = nil
    return unless monster

    kind = monster.class.to_s
    x, y = monster_home(monster)
    @cast.append { @monster_slot = creature(kind, entering ? ARENA_W + 20 : x, y, STATURE.fetch(kind, 2.0)) }
    @monster_spokes = kind == "IntrepidDecomposedCyclist" ? @spokes : nil
  end

  # Both cards across the top of the arena: a name, the life left, and a bar.
  def life_card(left, top)
    card = {}
    card[:slot] = stack(left: left, top: top, width: 280, height: 58) do
      background rgb(251, 243, 228, 0.94), curve: 10
      border INK, strokewidth: 2, curve: 10
      card[:name] = para "", font: ROUND, size: 14, stroke: INK, left: 12, top: 6, margin: 0
      card[:life] = para "", font: MONO, size: 12, stroke: INK, left: 120, top: 8, width: 148, align: "right", margin: 0
      nostroke
      fill "#d9c7a6"
      rect 12, 28, 256, 9, 4
      fill LEAF
      card[:bar] = rect 12, 28, 256, 9, 4
      card[:stats] = para "", font: MONO, size: 10, stroke: "#6b5a48", left: 12, top: 40, margin: 0
    end
    card
  end

  def refresh_cards
    rabbit_stats = @rabbit.class.traits.keys.reject { |t| t == :life }.map { |t| "#{t} #{@rabbit.send(t)}" }
    fill_card(@rabbit_card, "Rabbit", @shown[:rabbit], @rabbit_max, rabbit_stats.join("  "))
    if @shown_monster
      m = @shown_monster
      @monster_max = m.class.traits[:life].to_i
      fill_card(@monster_card, short_name(m.class.to_s), @shown[:monster], @monster_max,
        "strength #{m.strength}  charisma #{m.charisma}  weapon #{m.weapon}")
      @monster_card[:slot].show
    else
      @monster_card[:slot].hide
    end
  end

  def short_name(kind)
    kind.length > 24 ? "#{kind[0, 22]}…" : kind
  end

  def fill_card(card, name, life, max, stats)
    max = [max, life, 1].max
    card[:name].text = name
    card[:life].text = "life #{life}"
    share = (life.to_f / max).clamp(0.0, 1.0)
    width = (256 * share).round
    card[:bar].style(width: [width, 1].max, fill: share > 0.5 ? LEAF : share > 0.2 ? GOLD : BACON)
    card[:bar].send(width.zero? ? :hide : :show)
    card[:stats].text = stats.length > 44 ? stats.gsub("strength", "str").gsub("charisma", "cha").gsub("weapon", "wpn")[0, 44] : stats
  end

  # The Array in the header: the six of them, the fallen crossed out.
  def draw_tokens
    standing = @array.map { |m| m.class.to_s }
    front = standing.first
    @tokens.clear do
      para "DwemthysArray[", font: MONO, size: 13, stroke: "#bfa9d6", left: 0, top: 19, margin: 0
      Dwemthy::MONSTERS.keys.each_with_index do |name, i|
        x = 118 + i * 50
        if name == front
          nostroke
          fill rgb(247, 201, 72, 0.35)
          oval x + 19, 27, 46, center: true
        end
        creature(name, x, 6, 0.4)
        unless standing.include?(name)
          fill rgb(42, 31, 61, 0.6)
          nostroke
          rect x - 2, 4, 44, 46
          stroke BACON
          strokewidth 3
          line x + 4, 12, x + 34, 42
          line x + 34, 12, x + 4, 42
        end
      end
      para "]", font: MONO, size: 13, stroke: "#bfa9d6", left: 118 + 6 * 50, top: 19, margin: 0
    end
  end

  WEAPON_NAMES = { "^" => "boomerang", "/" => "sword", "%" => "lettuce", "*" => "bomb" }
  WEAPON_COLORS = { "^" => "#f4d58d", "/" => "#cfe3ff", "%" => "#c8e6a0", "*" => "#f6b7a8" }

  # A weapon the Rabbit grew itself is named by the comment above its def.
  def weapon_name(op)
    return WEAPON_NAMES[op] if WEAPON_NAMES.key?(op)

    lines = @source.lines
    at = lines.index { |l| l =~ /\bdef\s+#{Regexp.escape(op)}\s*\(/ }
    note = at && at > 0 && lines[at - 1][/^\s*#\s*(.+)$/, 1]
    note ? note.strip[0, 14] : "mystery"
  end

  def build_armory
    ops = Dwemthy.weapons(@rabbit)
    width = ops.empty? ? ARENA_W : [(ARENA_W - 16) / ops.size, 150].min
    @armory.clear do
      background "#e7d3b0"
      stack(width: 8) {}
      if ops.empty?
        para "This Rabbit has no weapons. Give it a def ^( enemy ) or two.", font: ROUND, size: 15, stroke: INK, margin: [8, 28, 0, 0]
      end
      ops.each do |op|
        stack(width: width, height: 76, margin: [4, 8, 4, 6]) do
          background WEAPON_COLORS.fetch(op, "#e3d0f5"), curve: 12
          border INK, strokewidth: 2, curve: 12
          para op, font: MONO, size: 26, stroke: INK, left: 12, top: 8, margin: 0
          para quiet_link(weapon_name(op), INK) { attack(op) }, font: ROUND, size: 15, left: 50, top: 10, margin: 0
          para weapon_note(op), font: ROUND, size: 11, stroke: "#6b5a48", left: 50, top: 32, margin: 0
          click { attack(op) }
        end
      end
    end
  end

  def weapon_note(op)
    if op == "*" && @rabbit.respond_to?(:bombs)
      "#{@rabbit.bombs} left · key *"
    elsif op.length == 1
      "key #{op}"
    else
      "rabbit #{op} dwemthy"
    end
  end

  def show_wanted
    m = @array.first
    @wanted.clear do
      next unless m

      para "at the front of the Array:", font: ROUND, size: 13, stroke: INK, margin: [0, 2, 0, 4]
      stack(margin: 0) do
        background TERM, curve: 8
        stack(margin: [10, 8, 8, 8]) { code_lines(Dwemthy::MONSTERS.fetch(m.class.to_s, ""), size: 10) }
      end
    end
  end

  # ---------------------------------------------------------------- the log

  LOG_COLORS = {
    prompt: "#9dff6e", comment: "#9b8fb0", plain: TERM_TEXT, hurt: "#ff8a7a", good: "#b6f09c",
    magick: GOLD, death: "#ff5f56", news: "#8fd3ff", error: "#ff5f56",
  }

  def log_line(text, kind = :plain)
    @log.append do
      para text, font: MONO, size: 11, stroke: LOG_COLORS.fetch(kind, TERM_TEXT), margin: [0, 1, 0, 1]
    end
    @log.contents.first.remove while @log.contents.size > 80
    timer(0) { @log.scroll_top = @log.scroll_max }
  end

  # ---------------------------------------------------------------- a turn

  def busy?
    !@beats.empty?
  end

  def attack(op)
    return if busy? || @array.empty?

    @turns += 1
    Dwemthy.drain
    Dwemthy.say(">> rabbit #{op} dwemthy")
    begin
      @rabbit.public_send(op, @array)
    rescue ScriptError, StandardError, SystemStackError => e
      Dwemthy.say("!! #{e.class}: #{e.message.lines.first.to_s.strip[0, 90]}")
    end
    stage_turn(op, Dwemthy.drain)
  end

  # Turns what the Ruby said into a little play, one beat per line.
  def stage_turn(op, said)
    died = false
    said.each do |entry|
      text = entry[:text]
      case text
      when /\A>> /
        beat(4, start: -> { log_line(text, :prompt) })
      when /\A!! /
        beat(14, start: -> { log_line(text.sub("!! ", "# "), :error); sound(:oops) }, tick: ->(t) { wobble(:rabbit, t) })
      when /You hit with (-?\d+) points? of damage/
        hit_beats(op, Regexp.last_match(1).to_i, text)
      when /\[(\w+) magick powers up (-?\d+)!\]/
        who = Regexp.last_match(1)
        gain = Regexp.last_match(2).to_i / 4
        beat(16, start: lambda {
          log_line(text, :magick)
          sound(:magick)
          side = who == @rabbit.class.to_s ? :rabbit : :monster
          @shown[side] += gain
          sparkle(side)
          float_number(side, "+#{gain} magick", GOLD)
          refresh_cards
        })
      when /\[Healthy lettuce gives you (-?\d+) life points/
        gain = Regexp.last_match(1).to_i
        beat(16, start: lambda {
          log_line(text, :good)
          @shown[:rabbit] += gain
          @rabbit_max = [@rabbit_max, @shown[:rabbit]].max
          float_number(:rabbit, "+#{gain}", LEAF)
          munch
          refresh_cards
        })
      when /Your enemy hit with (-?\d+) points? of damage/
        damage = Regexp.last_match(1).to_i
        retaliate_beats(damage, text)
      when /\[(\w+) has died\.\]/
        if Regexp.last_match(1) == @rabbit.class.to_s
          died = true
          rabbit_falls(text)
        else
          monster_falls(text)
        end
      when /has emerged/
        monster = entry[:monster]
        life = entry[:monster_life].to_i
        emerge_beats(monster, life, text)
      when /decimated Dwemthy's Array/
        beat(40, start: -> { log_line(text, :magick); sound(:bacon) }, finish: lambda {
          @wins = @wins.to_i + 1
          save_state
          visit "/victory"
        })
      when /too dead to fight/
        beat(14, start: -> { log_line(text, :death); sound(:oops) }, tick: ->(t) { wobble(:rabbit, t) })
      when /out of bombs/
        beat(18, start: -> { log_line(text, :hurt); fizzle; sound(:oops) })
      else
        beat(6, start: -> { log_line(text, text.start_with?("#<") ? :comment : :plain) })
      end
    end
    beat(1, start: lambda {
      @shown[:rabbit] = @rabbit.life.to_i
      @shown[:monster] = @array.first&.life.to_i
      refresh_cards
      build_armory if Dwemthy.weapons(@rabbit).include?("*")
      if @rabbit.life.to_i > 0 && @overlay_up
        # lettuce, or something stranger, brought it back
        @overlay.hide
        @overlay_up = false
        @rabbit_slot.show
        log_line("# the Rabbit is back on its feet. Nobody can say exactly how.", :good)
      elsif died || @rabbit.life.to_i <= 0
        if died
          @rabbits_lost = @rabbits_lost.to_i + 1
          @deaths_this_run = @deaths_this_run.to_i + 1
        end
        save_state
        show_overlay
      end
    })
  end

  def beat(frames, start: nil, tick: nil, finish: nil)
    @beats << StageBeat.new(frames, start, tick, finish, -1)
  end

  def run_beats
    b = @beats.first or return
    if b.age < 0
      b.age = 0
      b.start&.call
      return if @beats.first != b # it visited another page
    end
    b.age += 1
    b.tick&.call([b.age.fdiv(b.frames), 1.0].min)
    return unless b.age >= b.frames

    @beats.shift
    b.finish&.call
  end

  # The creatures breathe while nobody is fighting.
  def idle(frame)
    if @rabbit_slot
      hop = @rabbit.life.to_i > 0 ? (Math.sin(frame / 5.0).abs * 5) : 0
      @rabbit_slot.move((80 + @rabbit_off[0]).round, (rabbit_home_y - hop + @rabbit_off[1]).round)
      if @flash > 0
        @flash -= 1
        @flash.even? ? @rabbit_slot.show : @rabbit_slot.hide
      end
    end
    if @monster_slot && @shown_monster
      x, y = monster_home(@shown_monster)
      sway = Math.sin(frame / 11.0) * 3
      @monster_slot.move((x + @monster_off[0]).round, (y + sway + @monster_off[1]).round)
    end
    @monster_spokes&.each_with_index { |s, i| s.style(rotate: (-frame * 12 + i * 45) % 360) } if frame.even?
  end

  # ---------------------------------------------------------------- the show

  def rabbit_hand
    [80 + 120, rabbit_home_y + 80]
  end

  def monster_middle
    return [ARENA_W - 160, FLOOR - 100] unless @shown_monster

    x, y = monster_home(@shown_monster)
    size = (100 * STATURE.fetch(@shown_monster.class.to_s, 2.0)).round
    [x + size * 0.45, y + size * 0.5]
  end

  def hit_beats(op, damage, text)
    fly = nil
    beat(op == "^" ? 22 : 16,
      start: lambda {
        log_line(text, :plain)
        sound(op == "^" ? :boomerang : op == "/" ? :sword : op == "*" ? :bomb : :lettuce)
        fly = projectile(op)
      },
      tick: ->(t) { fly&.call(t) },
      finish: -> { @fx.clear })
    beat(12,
      start: lambda {
        @shown[:monster] -= damage
        refresh_cards
        float_number(:monster, damage.zero? ? "miss" : "-#{damage}", damage.zero? ? PAPER : "#ff5f56")
        burst(*monster_middle, op == "*" ? 1.6 : 0.8)
        sound(:thump) unless op == "*"
      },
      tick: ->(t) { @monster_off = [((1 - t) * 10 * Math.sin(t * 40)).round, 0] },
      finish: -> { @monster_off = [0, 0]; @fx.clear })
  end

  def retaliate_beats(damage, text)
    if @shown_monster.class.to_s == "Dragon"
      flames = []
      beat(18,
        start: -> { log_line(text, :hurt); flames = breathe_fire; sound(:bomb) },
        tick: ->(t) { flames.each_with_index { |puff, i| puff.each { |f| (t * 8).floor >= i ? f.show : f.hide } } },
        finish: -> { @monster_off = [0, 0] })
    else
      beat(10,
        start: -> { log_line(text, :hurt) },
        tick: ->(t) { @monster_off = [(-Math.sin(t * Math::PI) * 120).round, (-Math.sin(t * Math::PI) * 14).round] },
        finish: -> { @monster_off = [0, 0] })
    end
    beat(12,
      start: lambda {
        @shown[:rabbit] -= damage
        refresh_cards
        float_number(:rabbit, damage.zero? ? "miss" : "-#{damage}", damage.zero? ? PAPER : "#ff5f56")
        @flash = damage.zero? ? 0 : 8
        sound(:thump)
      },
      tick: ->(t) { @rabbit_off = [(-(1 - t) * 14 * Math.sin(t * 30)).round, 0] },
      finish: -> { @rabbit_off = [0, 0]; @fx.clear })
  end

  def monster_falls(text)
    beat(26,
      start: -> { log_line(text, :death); sound(:fall); poof(*monster_middle) },
      tick: ->(t) { @monster_off = [0, (t * t * 260).round] },
      finish: lambda {
        show_monster(nil)
        @monster_off = [0, 0]
        @fx.clear
      })
  end

  def emerge_beats(monster, life, text)
    beat(24,
      start: lambda {
        log_line(text, :news)
        sound(:emerge)
        @shown_monster = monster
        @shown[:monster] = life
        show_monster(monster, entering: true)
        x, = monster_home(monster)
        @monster_off = [ARENA_W + 20 - x, 0]
        refresh_cards
        draw_tokens
        show_wanted
        banner("#{NICKNAMES.fetch(monster.class.to_s, monster.class.to_s)} steps up")
      },
      tick: lambda { |t|
        x, = monster_home(monster)
        ease = 1 - (1 - t)**3
        @monster_off = [((ARENA_W + 20 - x) * (1 - ease)).round, 0]
      },
      finish: -> { @monster_off = [0, 0] })
    beat(14, finish: -> { @fx.clear })
  end

  def rabbit_falls(text)
    ghost = nil
    beat(34,
      start: lambda {
        log_line(text, :death)
        sound(:fall)
        @flash = 0
        @rabbit_slot.hide
        x = 80 + 30
        @fx.append do
          ghost = stack(left: x, top: rabbit_home_y, width: 100, height: 100) do
            @k = 1.0
            nostroke
            fill rgb(255, 255, 255, 0.55)
            ov 50, 50, 50, 56
            rc 25, 50, 50, 34
            [32, 50, 68].each { |gx| ov gx, 84, 18, 14 }
            fill INK
            ov 42, 44, 6
            ov 58, 44, 6
            nofill
            stroke rgb(247, 201, 72, 0.9)
            strokewidth 3
            ov 50, 14, 34, 8
          end
        end
      },
      tick: ->(t) { ghost&.move(110 + (Math.sin(t * 9) * 8).round, (rabbit_home_y - t * 120).round) })
  end

  def wobble(side, t)
    off = [((1 - t) * 6 * Math.sin(t * 50)).round, 0]
    side == :rabbit ? @rabbit_off = off : @monster_off = off
  end

  # Draws what the Rabbit throws, and answers a lambda that moves it along (t from 0 to 1).
  def projectile(op)
    x0, y0 = rabbit_hand
    x1, y1 = monster_middle
    parts = []
    @fx.append do
      transform :center
      case op
      when "^"
        stroke INK
        strokewidth 2
        fill "#d9a35b"
        parts << shape { move_to 0, 18; line_to 18, 0; line_to 36, 18; line_to 28, 18; line_to 18, 8; line_to 8, 18; line_to 0, 18 }
      when "/"
        nostroke
        fill rgb(255, 255, 255, 0.9)
        parts << shape { move_to 0, 120; curve_to 30, 70, 70, 30, 120, 0; curve_to 80, 40, 40, 80, 0, 120 }
        stroke "#cfe3ff"
        strokewidth 3
        parts << line(10, 110, 110, 10)
      when "%"
        stroke "#3f7f2a"
        strokewidth 1.5
        fill "#a6dc6a".."#6ab04c"
        parts << oval(0, 0, 34, 24)
        parts << line(4, 12, 30, 12)
      when "*"
        stroke INK
        strokewidth 2
        fill "#2f2a2a"
        parts << oval(0, 6, 26)
        fill white
        nostroke
        parts << oval(6, 10, 7)
        stroke "#7a4b2e"
        strokewidth 2
        parts << line(20, 8, 26, 0)
        fill GOLD
        nostroke
        parts << star(27, 0, 5, 6, 3)
      else
        stroke INK
        strokewidth 2
        fill "#e3d0f5"
        parts << star(18, 18, 7, 18, 8)
      end
    end
    homes = parts.map { |p| [p.left.to_f, p.top.to_f] }
    case op
    when "/"
      lambda do |t|
        parts.each_with_index { |p, i| p.move((x1 - 60 + homes[i][0]).round, (y1 - 60 + homes[i][1]).round) }
        parts.each { |p| t < 0.15 || t > 0.85 ? p.hide : p.show }
      end
    when "^"
      lambda do |t|
        # out along the bottom of an ellipse and back along the top
        a = t * 2 * Math::PI
        cx = (x0 + x1) / 2.0
        x = cx - Math.cos(a) * (x1 - x0) / 2.0
        y = y0 + (y1 - y0) * (t < 0.5 ? t * 2 : 2 - t * 2) - Math.sin(a) * 60
        parts.each_with_index do |p, i|
          p.move((x - 18 + homes[i][0]).round, (y - 9 + homes[i][1]).round)
          p.style(rotate: (t * 1080) % 360)
        end
      end
    else
      lambda do |t|
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t - Math.sin(t * Math::PI) * (op == "*" ? 110 : 50)
        parts.each_with_index do |p, i|
          p.move((x - 15 + homes[i][0]).round, (y - 15 + homes[i][1]).round)
          p.style(rotate: (t * (op == "*" ? 400 : 200)) % 360) if i.zero? && op != "*"
        end
      end
    end
  end

  # The Dragon does not lunge. It does not need to.
  def breathe_fire
    x, y = monster_home(@shown_monster)
    k = STATURE["Dragon"]
    mx, my = x + 4 * k, y + 36 * k
    tx, ty = 80 + 90, rabbit_home_y + 70
    flames = []
    @fx.append do
      nostroke
      6.times do |i|
        t = (i + 1) / 6.0
        fx = mx + (tx - mx) * t
        fy = my + (ty - my) * t
        size = 18 + 46 * t
        fill rgb(255, 87, 34, 0.75)
        a = oval(fx, fy, size, center: true)
        fill rgb(255, 225, 77, 0.9)
        b = oval(fx + size * 0.08, fy, size * 0.55, center: true)
        [a, b].each(&:hide)
        flames << [a, b]
      end
    end
    flames
  end

  def burst(x, y, size)
    @fx.append do
      nostroke
      fill rgb(255, 200, 80, 0.85)
      star x, y, 10, 46 * size, 18 * size
      fill rgb(255, 245, 200, 0.95)
      star x, y, 8, 24 * size, 10 * size
    end
  end

  def poof(x, y)
    @fx.append do
      nostroke
      fill rgb(240, 236, 230, 0.85)
      [[-40, 10, 60], [0, -20, 80], [40, 14, 64], [-10, 40, 56], [26, 44, 48]].each do |dx, dy, d|
        oval x + dx, y + dy, d, center: true
      end
    end
  end

  def sparkle(side)
    x, y = side == :rabbit ? [80 + 78, rabbit_home_y + 60] : monster_middle
    @fx.append do
      stroke INK
      strokewidth 1
      fill GOLD
      [[-50, -40, 14], [46, -50, 11], [-30, 40, 9], [54, 24, 13], [0, -72, 10]].each do |dx, dy, r|
        star x + dx, y + dy, 5, r, r / 2.4
      end
    end
  end

  def munch
    x, y = 80 + 110, rabbit_home_y + 70
    @fx.append do
      stroke "#3f7f2a"
      strokewidth 1.5
      fill "#a6dc6a"
      oval x, y, 22, 16
      oval x + 12, y - 12, 18, 13
      oval x - 6, y - 18, 14, 10
    end
  end

  def fizzle
    x, y = rabbit_hand
    @fx.append do
      stroke INK
      strokewidth 2
      fill "#2f2a2a"
      oval x - 30, y - 10, 26
      para "fzzt.", font: ROUND, size: 16, stroke: PAPER, left: x - 40, top: y - 40, margin: 0
    end
  end

  def float_number(side, text, color)
    x, y = side == :rabbit ? [80 + 40, rabbit_home_y - 10] : monster_middle.then { |mx, my| [mx - 40, [my - 110, 124].max] }
    @floaty.append do
      @floats << { note: para(text, font: ROUND, size: 26, stroke: color, left: x.round, top: y.round, margin: 0), x: x.round, y: y, age: 0 }
    end
  end

  def drift_floats
    @floats.each do |f|
      f[:age] += 1
      f[:note].move(f[:x], (f[:y] - f[:age] * 1.6).round)
    end
    gone, @floats = @floats.partition { |f| f[:age] > 26 }
    gone.each { |f| f[:note].remove }
  end

  def banner(text)
    @fx.append do
      stack(left: 60, top: 96, width: ARENA_W - 120) do
        background rgb(42, 31, 61, 0.85), curve: 12
        para text, font: ROUND, size: 20, stroke: PAPER, align: "center", margin: [10, 8, 10, 10]
      end
    end
  end

  # ---------------------------------------------------------------- when the Rabbit falls

  def show_overlay
    first = @rabbits_lost.to_i <= 1
    monster = @array.first
    foe = NICKNAMES.fetch(monster.class.to_s, "a monster").sub(/\Athe (\w)/) { "#{"aeiou".include?($1.downcase) ? "an" : "a"} #{$1}" }
    life = @rabbit.class.traits[:life].to_i
    hint = if first
      "#{life == 10 ? "Ten" : life} life #{life == 1 ? "point" : "points"} against #{foe}. " \
        "This was never a fair fight, and it was never meant to be. The Rabbit is made of numbers, " \
        "and the numbers are right there in rabbit.rb. Change one. Press Recompile."
    else
      HINTS[@rabbits_lost.to_i % HINTS.size]
    end
    @overlay.clear do
      background rgb(29, 25, 37, 0.82)
      stack(left: 70, top: 70, width: ARENA_W - 140) do
        background PAPER, curve: 14
        border INK, strokewidth: 2, curve: 14
        stack(margin: [22, 18, 22, 18]) do
          para "The Rabbit is too dead to fight!", font: ROUND, size: 24, stroke: BACON, margin: [0, 0, 0, 8]
          para hint, font: ROUND, size: 14, stroke: INK, margin: [0, 0, 0, 14]
          flow do
            chunky("Recompile the Rabbit", width: 210, size: 15) { recompile }
            chunky("Try again, unchanged", width: 200, color: PAPER_DEEP, text: INK, size: 14) { recompile(@source) }
          end
        end
      end
    end
    @overlay.show
    @overlay_up = true
  end

  HINTS = [
    "Every number in rabbit.rb is a suggestion. Life, strength, charisma... the Array only checks them, it doesn't judge them.",
    "The lettuce heals by rand( charisma ). How charming is your Rabbit, really?",
    "Look at def *( enemy ). Who decided you only get three bombs?",
    "You could write a whole new weapon. def +( enemy ) is free real estate. It shows up as a button.",
    "The sword cuts by the enemy's life % 10, squared. Or it could cut by whatever you like.",
    "The Dragon has 1340 life and breathes fire for up to 1389. Plan accordingly.",
  ]

  # ---------------------------------------------------------------- recompiling

  def recompile(source = @editor.text)
    if busy?
      @status.replace "let the dust settle first, then Recompile."
      return
    end

    error = compile(source)
    if error
      @status.replace span("error: ", stroke: BACON), error[0, 120]
      log_line("# #{error[0, 110]}", :error)
      sound(:oops)
      return
    end
    @editor.text = @source unless @editor.text == @source
    @overlay.hide
    @overlay_up = false
    @flash = 0
    @rabbit_off = [0, 0]
    @rabbit_slot&.show
    @shown[:rabbit] = @rabbit.life.to_i
    refresh_cards
    build_armory
    stats = @rabbit.class.traits.map { |t, v| "#{t} #{v}" }.join(", ")
    @status.replace span("compiled. ", stroke: "#3f7f2a"), "a new Rabbit, fresh from rabbit.rb."
    log_line("# a new Rabbit hops out of rabbit.rb: #{stats}", :good)
    sound(:reborn)
    sparkle(:rabbit)
    timer(0.6) { @fx.clear unless busy? }
  end

  def restore_rabbit
    return if busy?

    @editor.text = Dwemthy::RABBIT
    recompile(Dwemthy::RABBIT)
  end

  # ---------------------------------------------------------------- victory

  def victory
    @on_sound = nil
    background "#fff4dc".."#f7c9a0"
    @bacon = []
    @bacon_layer = stack(left: 0, top: 0, width: W, height: H) {}

    stack(left: 0, top: 24, width: W) do
      para "Whoa. You decimated Dwemthy's Array!", font: SCRIPT, size: 40, stroke: "#4a2a5a", align: "center", margin: 0
    end

    @foxes = [creature("Fox", 70, 300, 2.2), creature("Fox", W - 290, 300, 2.2, flip: true)]
    [[60, 196, "CHUNKY"], [W - 300, 196, "BACON!!"]].each do |x, y, word|
      stack(left: x, top: y, width: 240) do
        background white, curve: 30
        border INK, strokewidth: 3, curve: 30
        para word, font: ROUND, size: 40, stroke: BACON, align: "center", margin: [0, 12, 0, 14]
      end
    end
    nostroke
    fill white
    shape { move_to 160, 270; line_to 190, 270; line_to 176, 312; line_to 160, 270 }
    shape { move_to W - 190, 270; line_to W - 160, 270; line_to W - 176, 312; line_to W - 190, 270 }

    stack(left: 320, top: 104, width: 320) do
      background white, curve: 14
      border INK, strokewidth: 2, curve: 14
      stack(margin: [16, 12, 16, 12]) do
        para verdict, font: ROUND, size: 14, stroke: INK, margin: [0, 0, 0, 8]
        para "It took #{@turns} #{@turns == 1 ? "swing" : "swings"} and #{@deaths_this_run.to_i} fallen " \
          "#{@deaths_this_run.to_i == 1 ? "rabbit" : "rabbits"} this run.", font: ROUND, size: 12, stroke: "#6b5a48", margin: 0
      end
    end

    stack(left: 320, top: 270, width: 320, height: 266) do
      background TERM, curve: 12
      stack(margin: [12, 10, 12, 10]) do
        para "what you changed in rabbit.rb:", font: ROUND, size: 13, stroke: GOLD, margin: [0, 0, 0, 6]
        diff = rabbit_diff
        if diff.empty?
          para "nothing. not one character.", font: MONO, size: 11, stroke: TERM_TEXT, margin: 0
        end
        diff.first(13).each do |sign, line|
          para "#{sign} #{line.strip}"[0, 44], font: MONO, size: 11, stroke: sign == "+" ? "#b6f09c" : "#ff8a7a", margin: 0
        end
        para "...", font: MONO, size: 11, stroke: TERM_TEXT, margin: 0 if diff.size > 13
      end
    end

    stack(left: 320, top: 556, width: 320) do
      flow do
        chunky("Run the Array again", width: 190, size: 15) { @array = nil; start_run }
        chunky("Title", width: 120, color: PAPER, text: INK, size: 15) { visit "/" }
      end
    end

    rng = Random.new(1)
    @bacon_layer.append do
      28.times do
        x = rng.rand(W - 60)
        y = -rng.rand(H)
        angle = rng.rand(-0.6..0.6)
        slot = stack(left: x, top: y.round, width: 70, height: 70) { rasher(angle) }
        @bacon << Rasher.new(slot, x, y, rng.rand(-0.6..0.6), rng.rand(2.0..4.5), rng.rand(8..24), rng.rand(6.28))
      end
    end
    sound(:bacon)

    animate(FPS) do |frame|
      @bacon.each do |b|
        b.y += b.vy
        b.y = -70 if b.y > H
        b.slot.move((b.x + Math.sin(frame / 12.0 + b.phase) * b.sway).round, b.y.round)
      end
      @foxes.each_with_index do |f, i|
        jump = (Math.sin(frame / 4.0 + i * Math::PI)).abs * 26
        f.move(i.zero? ? 70 : W - 290, (300 - jump).round)
      end
    end
  end

  # One rasher of bacon, at an angle: a wavy strip of meat with a stripe of fat.
  def rasher(angle)
    wave = lambda do |offset|
      (0..8).map do |i|
        x = i * 7.0 - 28
        y = Math.sin(i * 1.1) * 3 + offset
        [35 + x * Math.cos(angle) - y * Math.sin(angle), 35 + x * Math.sin(angle) + y * Math.cos(angle)]
      end
    end
    strip = lambda do |top, bottom|
      upper = wave.call(top)
      lower = wave.call(bottom).reverse
      shape do
        move_to(*upper.first)
        (upper.drop(1) + lower).each { |x, y| line_to x, y }
        line_to(*upper.first)
      end
    end
    stroke INK
    strokewidth 1.5
    fill "#b5413a"
    strip.call(-8, 8)
    nostroke
    fill "#f7d2bf"
    strip.call(-2.5, 1)
  end

  def rabbit_diff
    ours = @source.to_s.lines.map(&:rstrip)
    theirs = Dwemthy::RABBIT.lines.map(&:rstrip)
    lcs = Array.new(theirs.size + 1) { Array.new(ours.size + 1, 0) }
    theirs.each_index.reverse_each do |i|
      ours.each_index.reverse_each do |j|
        lcs[i][j] = theirs[i] == ours[j] ? lcs[i + 1][j + 1] + 1 : [lcs[i + 1][j], lcs[i][j + 1]].max
      end
    end
    out = []
    i = j = 0
    while i < theirs.size || j < ours.size
      if i < theirs.size && j < ours.size && theirs[i] == ours[j]
        i += 1
        j += 1
      elsif j < ours.size && (i >= theirs.size || lcs[i][j + 1] >= lcs[i + 1][j])
        out << ["+", ours[j]] unless ours[j].strip.empty?
        j += 1
      else
        out << ["-", theirs[i]] unless theirs[i].strip.empty?
        i += 1
      end
    end
    out
  end

  def verdict
    traits = @rabbit.class.traits
    extra = Dwemthy.weapons(@rabbit) - %w[^ / % *]
    if rabbit_diff.empty?
      "You beat the Array with the Rabbit exactly as written. That should not be possible. The foxes are speechless. (They are not.)"
    elsif extra.any?
      "You invented the #{extra.first} and the Array never saw it coming. The foxes would like one too."
    elsif traits[:life].to_i >= 100_000
      "A rabbit with #{traits[:life]} life. The foxes are impressed, and also a little worried about you."
    elsif traits[:bombs].to_i > 3
      "#{traits[:bombs]} bombs. That is not three. The foxes noticed. The foxes do not care."
    else
      "You rewrote the Rabbit and the Rabbit rewrote the Array. That is the whole lesson, really."
    end
  end

end
