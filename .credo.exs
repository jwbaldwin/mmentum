%{
  configs: [
    %{
      name: "default",
      strict: true,
      requires: ["lib/mmentum/checks/**/*.exs"],
      files: %{
        included: ["lib/", "test/", "config/", "priv/repo/migrations/", "mix.exs"]
      },
      checks: %{
        extra: [
          {Mmentum.Checks.EntityValue, []},
          {Mmentum.Checks.ModuleLocation, []},
          {Credo.Check.Readability.MaxLineLength, max_length: 120},
          {Credo.Check.Readability.ModuleNames,
           ignore: [~r/^Mmentum\.MCP\.Versions\.V\d{4}_\d{2}_\d{2}(\.(Request|Response|Server)|Test)$/]},
          {Credo.Check.Refactor.AppendSingleItem, []},
          {ExcellentMigrations.CredoCheck.MigrationsSafety, []},
          {ExSlop.Check.Warning.BlanketRescue, []},
          {ExSlop.Check.Warning.RescueWithoutReraise, []},
          {ExSlop.Check.Warning.RepoAllThenFilter, []},
          {ExSlop.Check.Warning.QueryInEnumMap, []},
          {ExSlop.Check.Warning.DualKeyAccess, []},
          {ExSlop.Check.Refactor.IdentityPassthrough, []},
          {ExSlop.Check.Refactor.IdentityMap, []},
          {ExSlop.Check.Refactor.TryRescueWithSafeAlternative, []},
          {ExSlop.Check.Readability.NarratorDoc, []},
          {ExSlop.Check.Readability.BoilerplateDocParams, []},
          {ExSlop.Check.Readability.NarratorComment, []},
          {Jump.CredoChecks.AssertElementSelectorCanNeverFail, []},
          {Jump.CredoChecks.AvoidFunctionLevelElse, []},
          {Jump.CredoChecks.AvoidLoggerConfigureInTest, []},
          {Jump.CredoChecks.LiveViewPubSubRequiresConnected, []},
          {Jump.CredoChecks.UndeclaredExternalResource, []},
          {Jump.CredoChecks.ForbiddenFunction,
           files: %{included: ["test/"]},
           functions: [
             {Process, :sleep, "Coordinate tests with messages, monitors, or :sys.get_state/1"}
           ]}
        ],
        disabled: [
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.LargeNumbers, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.WithSingleClause, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.MapJoin, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.NegatedConditionsWithElse, []},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.WithClauses, []}
        ]
      }
    }
  ]
}
