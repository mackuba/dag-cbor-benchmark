#!/usr/bin/env ruby

require 'benchmark'

require 'cbor'  # https://github.com/cabo/cbor-ruby

DECODERS = {
  "cbor-ruby": CBOR
}

ENCODERS = {
  "cbor-ruby": CBOR
}

DATA_DIR = File.expand_path("../data", __dir__)

TESTCASES = Hash[Dir["#{DATA_DIR}/*.dagcbor"].sort.map { |f|
  [File.basename(f, '.dagcbor'), File.read(f, encoding: 'BINARY')]
}]

def test(title, coders, cases)
  puts
  puts "#{title}:"
  puts "=" * (title.length + 1)

  if cases.is_a?(String)
    cases = [cases]
  elsif !cases.is_a?(Array)
    raise "cases parameter should be an array"
  end

  cases.each do |test_name|
    data = TESTCASES[test_name]
    raise "Test not found: #{test_name.inspect}" unless data

    coders.each do |lib_name, coder|
      GC.start # give each impl a "clean slate", for maximum fairness
      yield test_name, lib_name, coder, data
    end
  end
end

HELLO_ITERS = 100_000

test("Hello World Decode", DECODERS, 'trivial_helloworld') do |file, name, coder, data|
  time = Benchmark.realtime {
    HELLO_ITERS.times { coder.decode(data) }
  }

  ns_per_it = ((time / HELLO_ITERS) * 1_000_000_000).round.to_i
  puts "#{name}: #{ns_per_it} ns"
end

test("Hello World Encode", ENCODERS, 'trivial_helloworld') do |file, name, coder, data|
  decoded = DECODERS[name].decode(data)

  time = Benchmark.realtime {
    HELLO_ITERS.times { coder.encode(data) }
  }

  ns_per_it = ((time / HELLO_ITERS) * 1_000_000_000).round.to_i
  puts "#{name}: #{ns_per_it} ns"
end

REALISTIC_ITERS = 25

realistic_tests = TESTCASES.keys.reject { |k| k.start_with?("torture_") || k.start_with?("trivial_") }

test("Realistic Decode Tests", DECODERS, realistic_tests) do |file, name, coder, data|
  time = Benchmark.realtime {
    REALISTIC_ITERS.times { coder.decode(data) }
  }

  time /= REALISTIC_ITERS
  ms_per_it = time * 1000
  mbps = data.length * 1.0 / (1024 * 1024) / time
  puts "#{file} #{name}: #{sprintf('%.2f', ms_per_it)} ms (#{sprintf('%.2f', mbps)} MB/s)"
end

test("Realistic Encode Tests", ENCODERS, realistic_tests) do |file, name, coder, data|
  decoded = DECODERS[name].decode(data)

  time = Benchmark.realtime {
    REALISTIC_ITERS.times { coder.encode(decoded) }
  }

  time /= REALISTIC_ITERS
  ms_per_it = time * 1000
  mbps = data.length * 1.0 / (1024 * 1024) / time
  puts "#{file} #{name}: #{sprintf('%.2f', ms_per_it)} ms (#{sprintf('%.2f', mbps)} MB/s)"
end

torture_tests = TESTCASES.keys.select { |k| k.start_with?("torture_") }

test("Decode Torture Tests", DECODERS, torture_tests) do |file, name, coder, data|
  begin
    time = Benchmark.realtime {
      coder.decode(data)
    }

    ms_per_it = time * 1000
    mbps = data.length * 1.0 / (1024 * 1024) / time
    puts "#{file} #{name}: #{sprintf('%.2f', ms_per_it)} ms (#{sprintf('%.2f', mbps)} MB/s)"
  rescue Exception => e
    puts "#{file} #{name}: #{e.inspect}"
  end
end
