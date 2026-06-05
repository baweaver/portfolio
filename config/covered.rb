# frozen_string_literal: true

def ignore_paths
  super + ["spec/", "tmp/", "coverage/"]
end

def include_patterns
  ["src/_code/**/*.rb"]
end
