require 'set'
require_relative './input_reader'

DEFAULT_HP = 200
DEFAULT_AP = 3
ADJACENTS = [[0, -1], [0, 1], [1, 0], [-1, 0]]
EMPTY_CELL = "."
GOBLIN_CELL = "G"
ELF_CELL = "E"
WALL_CELL = "#"

def loop_units(input)
  input.units.each do |unit|
    next if unit.hp <= 0
    return if input.combat_ended?

    if input.should_move?(unit)
      next_move = input.next_move(unit)
      next if next_move.nil?
      # puts "#{unit.class} at #{unit.coordinate} is moving to #{next_move}"
      input.move(unit, next_move)
    end

    if input.should_attack?(unit)
      target = input.enemies(unit).first
      input.attack(unit, target)
    end
    return if input.combat_ended?
  end
end

def compute_part_one(input, ap: 4, fast: false)
  round_num = 0
  input.set_elf_ap(ap: ap)
  elves_before = input.elves.to_a.length
  puts "Trying ap=#{ap}, elves_before=#{elves_before}"
  while !input.combat_ended?
    loop_units(input)
    break if input.combat_ended?

    round_num += 1
  end

  elves_after = input.elves.to_a.length
  puts "Finished ap=#{ap}, elves_before=#{elves_before}, elves_after=#{elves_after}"
  final_health = input.elves.sum(&:hp)
  outcome = final_health * round_num
  puts "Outcome: #{outcome}, final_health: #{final_health}, rounds: #{round_num}"
  no_elves_die = elves_before == elves_after
  [no_elves_die, outcome]
end

def compute_part_two
  min_ap = (4..200)
    .to_a
    .bsearch { compute_part_one(prod_input, ap: _1).first }
  _, outcome = compute_part_one(prod_input, ap: min_ap)
  puts "Min AP where no elves die: #{min_ap}, outcome: #{outcome}"
end

class Goblin
  attr_accessor :hp, :ap, :x, :y
  def initialize(x, y, hp: DEFAULT_HP, ap: DEFAULT_AP)
    @x = x
    @y = y
    @hp = hp
    @ap = ap
  end

  def to_s
    GOBLIN_CELL
  end

  def coordinate
    [x, y]
  end

  def set_coordinate(target)
    new_x, new_y = target
    @x = new_x
    @y = new_y
  end

  def <=>(other)
    coordinate.reverse <=> other.coordinate.reverse
  end
end

class Elf
  attr_accessor :hp, :ap, :x, :y
  def initialize(x, y, hp: DEFAULT_HP, ap: DEFAULT_AP)
    @x = x
    @y = y
    @hp = hp
    @ap = ap
  end

  def to_s
    ELF_CELL
  end

  def coordinate
    [x, y]
  end

  def set_coordinate(target)
    new_x, new_y = target
    @x = new_x
    @y = new_y
  end

  def <=>(other)
    coordinate.reverse <=> other.coordinate.reverse
  end
end

class Map
  def initialize(coordinates)
    @goblins = Set.new([])
    @elves = Set.new([])
    @map = []
    coordinates.each_with_index do |row, y|
      new_row = []
      row.each_with_index do |coordinate, x|
        if coordinate == GOBLIN_CELL
          goblin = Goblin.new(x, y)
          @goblins << goblin
          new_row << goblin
        elsif coordinate == ELF_CELL
          elf = Elf.new(x, y)
          @elves << elf
          new_row << elf
        else
          new_row << coordinate
        end
      end
      @map << new_row
    end
    @bests = {}
  end

  def set_elf_ap(ap: 4)
    @elves.each { _1.ap = ap }
  end

  def to_s
    res = ""
    @map.each do |row|
      row.each do |elem|
        res += elem.to_s
      end
      res += "\n"
    end
    res
  end

  def [](coord)
    x, y = coord
    @map[y][x]
  end

  def []=(coord, elem)
    x, y = coord
    @map[y][x] = elem
  end

  def combat_ended?
    @goblins.length == 0 || @elves.length == 0
  end

  def each_coordinate(&blk)
    @map.each_with_index do |row, y|
      row.each_with_index do |elem, x|
        next if elem == WALL_CELL
        yield [x, y]
      end
    end
  end

  def each_edge(&blk)
    each_coordinate do |coord|
      adjacents(coord).each do |target|
        yield [coord, target]
      end
    end
  end

  def units
    (@elves + @goblins).to_a
      .sort
      .to_enum
  end

  def elves
    @elves.to_enum
  end

  def goblins
    @goblins.to_enum
  end

  def move(unit, target)
    self[unit.coordinate] = EMPTY_CELL
    self[target] = unit
    unit.set_coordinate(target)
    unit
  end

  def should_attack?(unit)
    enemies(unit).any?
  end

  def remove_dead(unit)
    self[unit.coordinate] = EMPTY_CELL
    case unit
    when Goblin
      @goblins.delete(unit)
    when Elf
      @elves.delete(unit)
    else
      raise "Don't know how to handle #{unit.class}"
    end
  end

  def attack(source, target)
    target.hp -= source.ap
    # puts "#{source.class} at #{source.coordinate} attacked " \
    #   "#{target.class} at #{target.coordinate} which now has " \
    #   "#{target.hp} HP."
    if target.hp <= 0
      # puts "The #{target.class} at #{target.coordinate} is dead!"
      remove_dead(target)
    end
  end

  def should_move?(unit)
    return false if should_attack?(unit)
    return false if in_range(unit.class).empty?
    adjacent_cells = Set.new(adjacents(unit.coordinate))

    enemies = case unit
    when Goblin
      Set.new(@elves.map(&:coordinate))
    when Elf
      Set.new(@goblins.map(&:coordinate))
    end
    return false if !adjacent_cells.intersection(enemies).empty?
    true
  end

  def next_move(unit, fast: false)
    if !should_move?(unit)
      raise "Unit at coordinate #{unit.coordinate} should not move. "\
        " Enemy nearby."
    end

    targets = in_range(unit.class).map do |adjacent_to_enemy|
      if fast
        next_move_between_fast(unit.coordinate, adjacent_to_enemy)
      else
        next_move_between(unit.coordinate, adjacent_to_enemy)
      end
    end.compact
    targets.min_by { |target, dist| [dist, target.reverse] }&.first
  end

  def in_range(unit_klass)
    enemies = if unit_klass == Goblin
      elves
    elsif unit_klass == Elf
      goblins
    else
      raise "Don't know how to handle #{unit_klass}"
    end
    free_spaces = enemies.map { empty_adjacents(_1.coordinate) }
    free_spaces.flatten(1).uniq
  end

  def adjacents(coordinate)
    x, y = coordinate
    adjacents = ADJACENTS.map do |x1, y1|
      [x + x1, y + y1]
    end

    adjacents.reject do
      x < 0 || x > max_x ||
        y < 0 || y > max_y ||
        self[_1] == WALL_CELL
    end
  end

  def empty_adjacents(coordinate)
    adjacents(coordinate).reject do |x, y|
      @map[y][x] != EMPTY_CELL
    end
  end

  def enemies(unit)
    adjacent_cells = adjacents(unit.coordinate)
    enemy_class = case unit
    when Goblin
      Elf
    when Elf
      Goblin
    else
      raise
    end
    adjacent_cells.select do |coord|
      self[coord].is_a?(enemy_class)
    end.map { self[_1] }.sort_by do |enemy|
      [enemy.hp, enemy.coordinate.reverse]
    end
  end

  def max_x
    @map.first.length
  end

  def max_y
    @map.length
  end

  def next_move_between_fast(from, to)
    visited = Set.new([])
    to_visit = empty_adjacents(from).map do |neighbour|
      [neighbour, neighbour, 1]
    end
    min_distance = Float::INFINITY
    output = Set.new([])
    while !to_visit.empty?
      visiting, first_node, distance = to_visit.shift
      next if visited.include?([first_node, visiting])
      visited << [first_node, visiting]
      if distance > min_distance
        break
      elsif visiting == to
        output << [first_node, distance]
        min_distance = distance
      else
        neighbours = empty_adjacents(visiting)
        neighbours.each do |neighbour|
          next if visited.include?([first_node, neighbour])
          to_visit << [neighbour, first_node, distance + 1]
        end
      end
    end

    next_move = output
      .sort_by { |neighbour, _| neighbour.reverse }
      .first
    next_move
  end

  def next_move_between(from, to)
    visited = Set.new([])
    to_visit = empty_adjacents(from).map do |neighbour|
      [neighbour, neighbour, 1]
    end
    min_distance = Float::INFINITY
    output = Set.new([])
    while !to_visit.empty?
      visiting, first_node, distance = to_visit.shift
      next if visited.include?([first_node, visiting])
      visited << [first_node, visiting]
      if distance > min_distance
        break
      elsif visiting == to
        next if output.include?([first_node, distance])
        output << [first_node, distance]
        min_distance = distance
      else
        neighbours = empty_adjacents(visiting)
        neighbours.each do |neighbour|
          next if visited.include?([first_node, neighbour])
          to_visit << [neighbour, first_node, distance + 1]
        end
      end
    end

    next_move = output
      .uniq
      .sort_by { |neighbour, _| neighbour.reverse }
      .first
    next_move
  end
end

def parse_raw(lines)
  Map.new(lines.map { |line| line.split("") })
end

def test_input
  input = <<-INPUT.split("\n").map(&:chomp)
#######
#E..EG#
#.#G.E#
#E.##E#
#G..#.#
#..E#.#
#######
  INPUT

  out = parse_raw(input)
end

def prod_input
  raw = InputReader.new(15).as_lines
  parse_raw(raw)
end

# compute_part_one(test_input)
# compute_part_one(prod_input)
# compute_part_two(test_input)
compute_part_two

# require 'benchmark/ips'
#
# Benchmark.ips do |x|
#   x.report("part 1 - fast") { compute_part_one(test_input, fast: true) }
#   x.report("part 1 - slow") { compute_part_one(test_input, fast: false) }
#
#   x.compare!
# end
