def include_patterns
  ["**/*.rb"]
end

def ignore_paths
  super + ["callbacks_spec.rb"]
end
