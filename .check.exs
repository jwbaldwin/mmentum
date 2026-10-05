[
  retry: false,
  fix: false,
  tools: [
    {:compiler, env: %{"MIX_ENV" => "test"}},
    {:formatter, env: %{"MIX_ENV" => "test"}},
    {:credo, "mix credo --strict", env: %{"MIX_ENV" => "test"}},
    {:sobelow, "mix sobelow --exit --strict --private --skip --ignore Vuln", env: %{"MIX_ENV" => "test"}},
    {:ex_dna, "mix ex_dna lib --min-occurrences 3 --max-clones 0", env: %{"MIX_ENV" => "test"}},
    {:reach, "mix reach.check --arch --dead-code", env: %{"MIX_ENV" => "test"}},
    {:xref, "mix xref graph --format cycles --label compile-connected --fail-above 0 --no-compile",
     env: %{"MIX_ENV" => "test"}},
    {:unused, "mix compile --severity error", env: %{"MIX_ENV" => "test"}},
    {:doctor, false},
    {:dialyzer, false},
    {:ex_doc, false},
    {:gettext, false},
    {:npm_test, false}
  ]
]
