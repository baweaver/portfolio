# frozen_string_literal: true

require_relative "graph"

RSpec.describe "Beyond Enumerable: Graphs" do
  describe "#order_tasks" do
    it "produces a valid topological order" do
      result = order_tasks(TASKS)
      expect(result.index(:install)).to be < result.index(:build)
      expect(result.index(:install)).to be < result.index(:test)
      expect(result.index(:build)).to be < result.index(:deploy)
      expect(result.index(:test)).to be < result.index(:deploy)
    end

    it "raises on a cycle" do
      cyclic = { a: [:b], b: [:a] }
      expect { order_tasks(cyclic) }.to raise_error("stuck: tasks depend on each other")
    end
  end

  describe "#mutual_friends" do
    it "returns shared friends" do
      expect(mutual_friends(FRIENDS, "Ana", "Dee")).to contain_exactly("Ben", "Cy")
    end
  end

  describe "#people_you_might_know" do
    it "returns friends-of-friends not already known" do
      expect(people_you_might_know(FRIENDS, "Ana")).to eq(["Dee"])
    end
  end

  describe "#reachable_recursive" do
    it "finds all connected nodes" do
      expect(reachable_recursive(FRIENDS, "Ana")).to contain_exactly("Ana", "Ben", "Cy", "Dee", "Eli")
    end

    it "handles isolated nodes" do
      graph = { "X" => ["Y"], "Y" => ["X"], "Z" => [] }
      expect(reachable_recursive(graph, "X")).to contain_exactly("X", "Y")
    end
  end

  describe "#reachable_dfs" do
    it "finds all connected nodes" do
      expect(reachable_dfs(FRIENDS, "Ana")).to contain_exactly("Ana", "Ben", "Cy", "Dee", "Eli")
    end
  end

  describe "#reachable_bfs" do
    it "finds all connected nodes" do
      expect(reachable_bfs(FRIENDS, "Ana")).to contain_exactly("Ana", "Ben", "Cy", "Dee", "Eli")
    end
  end

  describe "#shortest_path" do
    it "finds the shortest hop path" do
      expect(shortest_path(FRIENDS, "Ana", "Eli")).to eq(["Ana", "Ben", "Dee", "Eli"])
    end

    it "returns the start for a self-path" do
      expect(shortest_path(FRIENDS, "Ana", "Ana")).to eq(["Ana"])
    end

    it "returns nil when unreachable" do
      graph = { "A" => ["B"], "B" => ["A"], "C" => [] }
      expect(shortest_path(graph, "A", "C")).to be_nil
    end
  end

  describe "#topological_sort" do
    it "produces a valid order" do
      result = topological_sort(TASKS)
      expect(result.index(:install)).to be < result.index(:build)
      expect(result.index(:install)).to be < result.index(:test)
      expect(result.index(:build)).to be < result.index(:deploy)
    end
  end

  describe "#topological_sort_safe" do
    it "produces a valid order for acyclic graphs" do
      result = topological_sort_safe(TASKS)
      expect(result.index(:install)).to be < result.index(:build)
      expect(result.index(:install)).to be < result.index(:test)
      expect(result.index(:build)).to be < result.index(:deploy)
    end

    it "raises on a cycle" do
      cyclic = { a: [:b], b: [:c], c: [:a] }
      expect { topological_sort_safe(cyclic) }.to raise_error(/cycle/)
    end

    it "handles self-referencing nodes" do
      self_ref = { a: [:a] }
      expect { topological_sort_safe(self_ref) }.to raise_error(/cycle/)
    end

    it "handles disconnected components" do
      graph = { a: [:b], b: [], c: [:d], d: [] }
      result = topological_sort_safe(graph)
      expect(result.index(:b)).to be < result.index(:a)
      expect(result.index(:d)).to be < result.index(:c)
    end

    it "handles nodes that only appear as children" do
      graph = { a: [:b] }
      result = topological_sort_safe(graph)
      expect(result).to include(:a)
      expect(result.index(:b)).to be < result.index(:a)
    end
  end

  describe "#tsort_tasks" do
    it "produces the same order as TSort" do
      result = tsort_tasks(TASKS)
      expect(result.index(:install)).to be < result.index(:build)
      expect(result.index(:install)).to be < result.index(:test)
      expect(result.index(:build)).to be < result.index(:deploy)
    end

    it "raises on a cycle" do
      cyclic = { a: [:b], b: [:a] }
      expect { tsort_tasks(cyclic) }.to raise_error(TSort::Cyclic)
    end
  end

  describe TaskGraph do
    it "produces a valid topological order" do
      result = TaskGraph.new(TASKS).tsort
      expect(result.index(:install)).to be < result.index(:build)
      expect(result.index(:deploy)).to be > result.index(:test)
    end
  end

  describe "#cheapest_path" do
    it "finds the lowest-cost route" do
      # Seattle → Spokane → Boise = 280 + 305 = 585
      # Seattle → Portland → Boise = 174 + 430 = 604
      expect(cheapest_path(ROADS, "Seattle", "Boise")).to eq(585)
    end

    it "returns 0 for start == goal" do
      expect(cheapest_path(ROADS, "Seattle", "Seattle")).to eq(0)
    end

    it "returns infinity for unreachable nodes" do
      expect(cheapest_path(ROADS, "Boise", "Seattle")).to eq(Float::INFINITY)
    end
  end
end
