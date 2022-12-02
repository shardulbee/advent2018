require_relative './input_reader'
require 'set'

Instruction = Struct.new(:opcode, :i1, :i2, :output)
InstructionExecution = Struct.new(:before, :after, :instruction)

addr = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] + regs[instruction.i2]
  regs
end

addi = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] + instruction.i2
  regs
end

mulr = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] * regs[instruction.i2]
  regs
end

muli = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] * instruction.i2
  regs
end

banr = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] & regs[instruction.i2]
  regs
end

bani = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] & instruction.i2
  regs
end

borr = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] | regs[instruction.i2]
  regs
end

bori = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1] | instruction.i2
  regs
end

setr = Proc.new do |regs, instruction|
  regs[instruction.output] = regs[instruction.i1]
  regs
end

seti = Proc.new do |regs, instruction|
  regs[instruction.output] = instruction.i1
  regs
end

gtir = Proc.new do |regs, instruction|
  regs[instruction.output] = if instruction.i1 > regs[instruction.i2]
    1
  else
    0
  end
  regs
end

gtri = Proc.new do |regs, instruction|
  regs[instruction.output] = if regs[instruction.i1] > instruction.i2
    1
  else
    0
  end
  regs
end

gtrr = Proc.new do |regs, instruction|
  regs[instruction.output] = if regs[instruction.i1] > regs[instruction.i2]
    1
  else
    0
  end
  regs
end

eqir = Proc.new do |regs, instruction|
  regs[instruction.output] = if instruction.i1 == regs[instruction.i2]
    1
  else
    0
  end
  regs
end

eqri = Proc.new do |regs, instruction|
  regs[instruction.output] = if regs[instruction.i1] == instruction.i2
    1
  else
    0
  end
  regs
end

eqrr = Proc.new do |regs, instruction|
  regs[instruction.output] = if regs[instruction.i1] == regs[instruction.i2]
    1
  else
    0
  end
  regs
end

INSTRUCTIONS = {
  addr: addr,
  addi: addi,
  mulr: mulr,
  muli: muli,
  banr: banr,
  bani: bani,
  borr: borr,
  bori: bori,
  setr: setr,
  seti: seti,
  gtir: gtir,
  gtri: gtri,
  gtrr: gtrr,
  eqir: eqir,
  eqri: eqri,
  eqrr: eqrr
}

def compute_part_one(input)
  num_behaving_like_three = input.each.with_index.count do |execution, i|
    candidates = INSTRUCTIONS.values.select do |instruction|
      execution.after == instruction.call(
        execution.before.clone,
        execution.instruction
      )
    end

    candidates.length >= 3
  end

  num_behaving_like_three
end

def compute_part_two(input)
  samples, program = input
  to_candidates = samples.map do |execution|
    candidates = INSTRUCTIONS.select do |name, instruction|
      execution.after == instruction.call(
        execution.before.clone,
        execution.instruction
      )
    end.map { _1.first }
    [execution.instruction.opcode, Set.new(candidates)]
  end

  grouped = to_candidates
    .group_by { _1.first }
    .map do |opcode, group|
      sets = group.map { _1[1] }
      unioned = sets.inject(Set.new, &:+)
      [opcode, unioned]
    end

  known = {}
  i = 0
  while !grouped.all? { |opcode, _| known.include?(opcode) } && i < 1000
    grouped = grouped.map do |opcode, candidates|
      if candidates.length == 1
        known[opcode] = candidates.first
        [opcode, candidates]
      else
        difference = candidates.difference(
          known.values.to_set
        )
        [opcode, difference]
      end
    end
    # puts "known at the end of iteration #{i}: #{known}"
    i += 1
  end

  registers = [0, 0, 0, 0]
  program.each do |instruction|
    op = INSTRUCTIONS[known[instruction.opcode]]
    registers = op.call(registers, instruction)
  end

  registers[0]
end

def parse_instruction_execution(execution_spec)
  before = parse_registers(execution_spec[0])
  after = parse_registers(execution_spec[2])
  instruction = parse_instruction(execution_spec[1])

  InstructionExecution.new(before, after, instruction)
end

def parse_registers(register)
  register.scan(/\d/).map(&:to_i)
end

def parse_instruction(instruction)
  instruction_data = instruction.scan(/\d+/).map(&:to_i)
  Instruction.new(*instruction_data)
end

def test_input
  input = <<-INPUT
Before: [3, 2, 1, 1]
9 2 1 2
After:  [3, 2, 2, 1]
  INPUT
  [parse_instruction_execution(input.split("\n"))]
end

def prod_input
  reader = InputReader.new(16)
  samples = reader.as_lines.each_slice(4).map do |slice|
    next nil if !slice[0].include?("Before:")
    execution = slice[...-1]
    parse_instruction_execution(execution)
  end.compact

  program = reader
    .as_line
    .split("\n\n\n\n")[1]
    .scan(/\d+/)
    .each_slice(4)
    .map { Instruction.new(*_1.map(&:to_i)) }
  [samples, program]
end

# puts "part 1 - test: #{compute_part_one(test_input)}"
# puts "part 1 - test: #{compute_part_one(prod_input)}"
puts "part 2 - test: #{compute_part_two(prod_input)}"
