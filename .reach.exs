[
  checks: [source_paths: ["lib"]],
  effects: [
    allowed: [
      {"Mmentum.Habits.Momentum", [:pure, :unknown, :exception]},
      {"Mmentum.*.Values.*", [:pure, :unknown, :exception]}
    ]
  ]
]
