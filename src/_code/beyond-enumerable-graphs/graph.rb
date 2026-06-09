# frozen_string_literal: true

require "set"

# segment: tasks_hash
TASKS = {
  deploy:  [:build, :test],
  build:   [:install],
  test:    [:install],
  install: []
}.freeze
# end: tasks_hash

# segment: order_tasks
def order_tasks(tasks)
  done = []
  remaining = tasks.dup

  until remaining.empty?
    ready = remaining.select { |_task, needs|
      needs.all? { |dep| done.include?(dep) }
    }.keys
    raise "stuck: tasks depend on each other" if ready.empty?

    done.concat(ready)
    ready.each { |task| remaining.delete(task) }
  end

  done
end
# end: order_tasks

# segment: friends_hash
FRIENDS = {
  "Ana" => ["Ben", "Cy"],
  "Ben" => ["Ana", "Cy", "Dee"],
  "Cy"  => ["Ana", "Ben", "Dee"],
  "Dee" => ["Ben", "Cy", "Eli"],
  "Eli" => ["Dee"]
}.freeze
# end: friends_hash

# segment: mutual_friends
def mutual_friends(graph, person, other)
  graph[person] & graph[other]
  # mutual_friends(FRIENDS, "Ana", "Dee") => ["Ben", "Cy"]
end
# end: mutual_friends

# segment: people_you_might_know
def people_you_might_know(graph, me)
  graph[me].flat_map { |friend| graph[friend] }.uniq - graph[me] - [me]
  # people_you_might_know(FRIENDS, "Ana") => ["Dee"]
end
# end: people_you_might_know

# segment: reachable_recursive
def reachable_recursive(graph, start)
  visited = Set.new

  walk = ->(node) do
    return if visited.include?(node)
    visited << node
    graph.fetch(node, []).each { |neighbor| walk.call(neighbor) }
  end

  walk.call(start)
  visited
end
# end: reachable_recursive

# segment: reachable_dfs
def reachable_dfs(graph, start)
  visited = Set.new
  stack = [start]

  until stack.empty?
    node = stack.pop
    next if visited.include?(node)

    visited << node
    graph.fetch(node, []).each { |neighbor| stack.push(neighbor) }
  end

  visited
end
# end: reachable_dfs

# segment: reachable_bfs
def reachable_bfs(graph, start)
  visited = Set.new([start])
  queue = [start]

  until queue.empty?
    node = queue.shift
    graph.fetch(node, []).each do |neighbor|
      next if visited.include?(neighbor)
      visited << neighbor
      queue.push(neighbor)
    end
  end

  visited
end
# end: reachable_bfs

# segment: shortest_path
def shortest_path(graph, start, goal)
  return [start] if start == goal

  came_from = { start => nil }
  queue = [start]

  until queue.empty?
    node = queue.shift
    graph.fetch(node, []).each do |neighbor|
      next if came_from.key?(neighbor)

      came_from[neighbor] = node
      return build_path(came_from, goal) if neighbor == goal
      queue.push(neighbor)
    end
  end

  nil
end

def build_path(came_from, goal)
  path = []
  step = goal
  while step
    path.unshift(step)
    step = came_from[step]
  end
  path
end
# end: shortest_path

# segment: topological_sort
def topological_sort(graph)
  visited = Set.new
  order = []

  visit = ->(node) do
    return if visited.include?(node)
    visited << node
    graph.fetch(node, []).each { |dep| visit.call(dep) }
    order << node
  end

  graph.each_key { |node| visit.call(node) }
  order
end
# end: topological_sort

# segment: topological_sort_with_cycle_detection
def topological_sort_safe(graph)
  visited = Set.new
  in_progress = Set.new
  order = []
  stack = graph.keys

  until stack.empty?
    node = stack.last

    # already seen, pop and maybe finalize
    if in_progress.include?(node) || visited.include?(node)
      stack.pop
      next unless in_progress.delete?(node)
      visited << node
      order << node
      next
    end

    # first visit: mark and push children
    in_progress << node
    graph.fetch(node, []).each do |child|
      if in_progress.include?(child)
        raise "cycle: #{child}"
      end
      stack.push(child) unless visited.include?(child)
    end
  end

  order
end
# end: topological_sort_with_cycle_detection

# segment: tsort_lambda
require "tsort"

def tsort_tasks(tasks)
  each_node  = ->(&block) { tasks.each_key(&block) }
  each_child = ->(task, &block) { tasks.fetch(task, []).each(&block) }
  TSort.tsort(each_node, each_child)
end
# end: tsort_lambda

# segment: tsort_class
class TaskGraph
  include TSort

  def initialize(dependencies) = @dependencies = dependencies
  def tsort_each_node(&block) = @dependencies.each_key(&block)
  def tsort_each_child(task, &block) = @dependencies.fetch(task, []).each(&block)
end
# end: tsort_class

# segment: roads_hash
Route = Data.define(:to, :miles)

ROADS = {
  "Seattle"  => [Route["Portland", 174], Route["Spokane", 280]],
  "Portland" => [Route["Boise", 430]],
  "Spokane"  => [Route["Portland", 350], Route["Boise", 305]],
  "Boise"    => []
}.freeze
# end: roads_hash

# segment: cheapest_path
def cheapest_path(graph, start, goal)
  best = Hash.new(Float::INFINITY)
  best[start] = 0
  frontier = [[0, start]]

  until frontier.empty?
    frontier.sort_by!(&:first)
    cost, node = frontier.shift
    next if cost > best[node]
    return cost if node == goal

    graph.fetch(node, []).each do |route|
      new_cost = cost + route.miles
      if new_cost < best[route.to]
        best[route.to] = new_cost
        frontier.push([new_cost, route.to])
      end
    end
  end

  best[goal]
end
# end: cheapest_path
