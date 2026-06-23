%{
  configs: [
    %{
      name: "default",
      checks: %{
        disabled: [
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Design.TagTODO, []}
        ]
      }
    }
  ]
}
