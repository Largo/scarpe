# The icon for Dwemthy's Array: the Rabbit, standing inside the Array's brackets.
#
#   ./scarpe.sh peek icon.rb --shot icon/square.png
#
# A 1024 px window with the tile on macOS's icon grid (824 px, 100 in from each edge).

INK = "#2b1d17"

Shoes.app(title: "Dwemthy's Array icon", width: 1024, height: 1024, resizable: false) do
  # The rabbit is drawn in a 100 x 100 box, as in the game, scaled up and placed.
  def kk(v) = (v * @k).round(2)
  def ov(x, y, w, h = w) = oval(@x + kk(x), @y + kk(y), kk(w), kk(h), center: true)

  def trace(*steps)
    shape do
      steps.each do |cmd, *xy|
        xy = xy.each_slice(2).flat_map { |x, y| [@x + kk(x), @y + kk(y)] }
        { m: :move_to, l: :line_to, c: :curve_to }.fetch(cmd).then { |m| send(m, *xy) }
      end
    end
  end

  def ink(width = 1.1, color = INK)
    stroke color
    strokewidth width * @k
  end

  background white
  nostroke
  fill "#33265a".."#e9926b"
  rect 100, 100, 824, 824, 185

  # hills and a moon
  fill "#59406e"
  shape do
    move_to 100, 640
    curve_to 300, 520, 520, 640, 700, 560
    curve_to 820, 520, 900, 580, 924, 560
    line_to 924, 730
    line_to 100, 730
  end
  # the ground follows the tile's rounded bottom corners
  fill "#2d2140"
  shape do
    move_to 100, 720
    line_to 924, 720
    line_to 924, 739
    curve_to 924, 841, 841, 924, 739, 924
    line_to 285, 924
    curve_to 183, 924, 100, 841, 100, 739
    line_to 100, 720
  end
  fill "#fff4d6"
  oval 560, 150, 96
  fill "#3a2b5e"
  oval 584, 138, 90
  fill rgb(255, 255, 255, 0.85)
  [[260, 200, 6], [370, 160, 4], [720, 220, 5], [470, 300, 3], [640, 330, 4], [800, 160, 3]].each { |x, y, d| oval x, y, d }

  # the brackets
  fill "#fbf3e4"
  rect 170, 250, 46, 560, 8
  rect 170, 250, 120, 40, 8
  rect 170, 770, 120, 40, 8
  rect 808, 250, 46, 560, 8
  rect 734, 250, 120, 40, 8
  rect 734, 770, 120, 40, 8

  # the Rabbit
  @k = 5.6
  @x = 512 - 50 * @k + 10
  @y = 770 - 98 * @k
  cap :curve
  nofill
  ink(5.3)
  trace [:m, 26, 92], [:c, 22, 86, 24, 80, 30, 78]
  ink(3, "#fffaf2")
  trace [:m, 26, 92], [:c, 22, 86, 24, 80, 30, 78]
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
  fill white
  ov 69.2, 46.4, 2.2
  fill rgb(246, 140, 160, 0.5)
  ov 66, 58, 9, 5
  fill "#f08a9c"
  ov 79, 52, 5, 4
  ink(0.7)
  nofill
  trace [:m, 75, 56], [:c, 76, 58.5, 78.5, 58.5, 79, 55]
end
