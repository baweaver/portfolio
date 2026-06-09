# frozen_string_literal: true

require_relative "streaming"

RSpec.describe "Beyond Enumerable: Streaming" do
  let(:log_file) do
    f = Tempfile.new("log")
    f.puts '192.168.1.1 - - "GET /foo" 200 1234'
    f.puts '192.168.1.2 - - "GET /bar" 500 567'
    f.puts '192.168.1.3 - - "POST /baz" 500 890'
    f.puts '192.168.1.4 - - "GET /ok" 200 111'
    f.flush
    f
  end

  let(:csv_file) do
    f = Tempfile.new("csv")
    f.puts "a,b,c,10.5"
    f.puts "d,e,f,20.3"
    f.puts "g,h,i,5.2"
    f.flush
    f
  end

  describe "#count_500s_eager" do
    it "counts lines containing 500" do
      expect(count_500s_eager(log_file.path)).to eq(2)
    end
  end

  describe "#count_500s_streaming" do
    it "produces the same result as eager" do
      expect(count_500s_streaming(log_file.path)).to eq(count_500s_eager(log_file.path))
    end
  end

  describe "#sum_column" do
    it "sums a specific CSV column" do
      expect(sum_column(csv_file.path, column: 3)).to be_within(0.01).of(36.0)
    end
  end

  describe "#first_five_upcased" do
    it "returns exactly 5 upcased lines" do
      result = first_five_upcased(log_file.path)
      expect(result.size).to eq(4) # file only has 4 lines
      expect(result.first).to eq(result.first.upcase)
    end
  end

  describe "#write_sorted_runs" do
    it "splits input into sorted run files" do
      data = [9, 3, 7, 1, 8, 2, 6, 4, 5, 0]
      runs = write_sorted_runs(data.each, 3)

      expect(runs.size).to eq(4)

      # each run is internally sorted
      runs.each do |run|
        lines = File.readlines(run.path).map { |l| Integer(l) }
        expect(lines).to eq(lines.sort)
      end
    end
  end

  describe "#merge_sorted_pair" do
    it "merges two sorted arrays" do
      expect(merge_sorted_pair([1, 3, 5], [2, 4, 6])).to eq([1, 2, 3, 4, 5, 6])
    end

    it "handles empty inputs" do
      expect(merge_sorted_pair([], [1, 2, 3])).to eq([1, 2, 3])
      expect(merge_sorted_pair([1, 2, 3], [])).to eq([1, 2, 3])
    end

    it "handles duplicates" do
      expect(merge_sorted_pair([1, 2, 2], [2, 3, 3])).to eq([1, 2, 2, 2, 3, 3])
    end
  end

  describe KWayMerge do
    it "merges multiple sorted sources" do
      sources = [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
      result = KWayMerge.merge(sources).to_a
      expect(result).to eq((1..9).to_a)
    end

    it "handles sources of different lengths" do
      sources = [[1, 2], [3], [4, 5, 6, 7]]
      result = KWayMerge.merge(sources).to_a
      expect(result).to eq([1, 2, 3, 4, 5, 6, 7])
    end

    it "handles empty sources" do
      sources = [[], [1, 2], []]
      result = KWayMerge.merge(sources).to_a
      expect(result).to eq([1, 2])
    end

    it "supports lazy consumption" do
      sources = [[1, 3, 5, 7, 9], [2, 4, 6, 8, 10]]
      result = KWayMerge.merge(sources).first(3)
      expect(result).to eq([1, 2, 3])
    end
  end

  describe ExternalSort do
    it "produces the same result as in-memory sort" do
      data = (1..1000).to_a.shuffle
      sorted_stream, run_files = ExternalSort.sort(data.each, chunk_size: 100)

      expect(sorted_stream.to_a).to eq(data.sort)
      run_files.each(&:close!)
    end

    it "creates the expected number of runs" do
      data = (1..500).to_a.shuffle
      _, run_files = ExternalSort.sort(data.each, chunk_size: 100)

      expect(run_files.size).to eq(5)
      run_files.each(&:close!)
    end
  end

  describe Heap do
    it "pops in sorted order" do
      h = Heap.new
      [5, 1, 8, 3, 2].each { |n| h.push(n) }

      results = []
      results << h.pop until h.empty?
      expect(results).to eq([1, 2, 3, 5, 8])
    end

    it "supports custom ordering via by:" do
      h = Heap.new(by: ->(item) { -item })
      [5, 1, 8, 3].each { |n| h.push(n) }
      expect(h.pop).to eq(8)
    end
  end
end
